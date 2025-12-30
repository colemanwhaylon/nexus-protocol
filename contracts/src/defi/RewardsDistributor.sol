// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RewardsDistributor
 * @author Nexus Protocol Team
 * @notice Production-grade rewards distribution with streaming and Merkle claims
 * @dev Implements comprehensive rewards distribution with security features
 *
 * Security Features (per SECURITY_REVIEW_BEFORE.md):
 * - SEC-007: Reward calculation rounding (round DOWN for user claims, UP for debts)
 * - SEC-011: On-chain rate limiting for claim operations
 * - SEC-012: Merkle proof replay prevention with unique campaign IDs
 * - SEC-013: Comprehensive event emissions for all state changes
 *
 * Features:
 * - Streaming rewards (linear distribution over time)
 * - Merkle claim system for airdrops with campaign isolation
 * - Multi-token support for diverse reward pools
 * - Campaign management (create, pause, expire campaigns)
 * - Claim tracking per campaign to prevent replay attacks
 */
contract RewardsDistributor is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ============ Constants ============

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role identifier for campaign managers
    bytes32 public constant CAMPAIGN_MANAGER_ROLE = keccak256("CAMPAIGN_MANAGER_ROLE");

    /// @notice Role identifier for reward depositors
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    /// @notice Rate limit window for claim operations - SEC-011
    uint256 public constant RATE_LIMIT_WINDOW = 1 hours;

    /// @notice Maximum claims per rate limit window - SEC-011
    uint256 public constant MAX_CLAIMS_PER_WINDOW = 10;

    /// @notice Minimum streaming duration (1 hour)
    uint256 public constant MIN_STREAMING_DURATION = 1 hours;

    /// @notice Maximum streaming duration (365 days)
    uint256 public constant MAX_STREAMING_DURATION = 365 days;

    /// @notice Basis points denominator
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Precision multiplier for reward calculations
    uint256 public constant PRECISION = 1e18;

    // ============ Enums ============

    /// @notice Campaign status enum
    enum CampaignStatus {
        Active, // Campaign is active and rewards can be claimed
        Paused, // Campaign is temporarily paused
        Expired, // Campaign has expired
        Cancelled // Campaign was cancelled and funds returned
    }

    /// @notice Campaign type enum
    enum CampaignType {
        Streaming, // Linear distribution over time
        Merkle // One-time claim with Merkle proof
    }

    // ============ Structs ============

    /**
     * @notice Streaming campaign configuration
     * @param rewardToken Token being distributed
     * @param totalRewards Total amount of rewards in campaign
     * @param claimedRewards Amount already claimed
     * @param startTime When streaming begins
     * @param endTime When streaming ends
     * @param rewardRate Rewards per second (calculated once)
     * @param status Current campaign status
     * @param campaignType Type of campaign
     */
    struct StreamingCampaign {
        IERC20 rewardToken;
        uint256 totalRewards;
        uint256 claimedRewards;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardRate;
        CampaignStatus status;
        CampaignType campaignType;
        string name;
        string description;
    }

    /**
     * @notice Merkle campaign configuration - SEC-012
     * @param rewardToken Token being distributed
     * @param totalRewards Total amount allocated
     * @param claimedRewards Amount already claimed
     * @param merkleRoot Root of the Merkle tree
     * @param startTime When claims can begin
     * @param expirationTime When claims expire
     * @param status Current campaign status
     * @param campaignType Type of campaign
     */
    struct MerkleCampaign {
        IERC20 rewardToken;
        uint256 totalRewards;
        uint256 claimedRewards;
        bytes32 merkleRoot;
        uint256 startTime;
        uint256 expirationTime;
        CampaignStatus status;
        CampaignType campaignType;
        string name;
        string description;
    }

    /**
     * @notice User's streaming position for a campaign
     * @param lastClaimTime Last time user claimed
     * @param totalClaimed Total amount user has claimed
     * @param allocation User's total allocation (if applicable)
     */
    struct UserStreamingPosition {
        uint256 lastClaimTime;
        uint256 totalClaimed;
        uint256 allocation;
    }

    /**
     * @notice Rate limiting info for claim operations - SEC-011
     * @param windowStart Start of current rate limit window
     * @param claimCount Number of claims in current window
     */
    struct RateLimitInfo {
        uint256 windowStart;
        uint256 claimCount;
    }

    /**
     * @notice Dust accumulator for rounding remainders - SEC-007
     * @param campaignId Campaign ID
     * @param dustAmount Accumulated dust
     */
    struct DustAccumulator {
        uint256 campaignId;
        uint256 dustAmount;
    }

    // ============ State Variables ============

    /// @notice Counter for campaign IDs
    uint256 public nextCampaignId;

    /// @notice Treasury address for reclaimed funds
    address public treasury;

    /// @notice Mapping of campaign ID to streaming campaign
    mapping(uint256 => StreamingCampaign) public streamingCampaigns;

    /// @notice Mapping of campaign ID to Merkle campaign
    mapping(uint256 => MerkleCampaign) public merkleCampaigns;

    /// @notice Mapping of campaign ID => user => streaming position
    mapping(uint256 => mapping(address => UserStreamingPosition)) public userStreamingPositions;

    /// @notice Mapping of campaign ID => user => claimed status (for Merkle) - SEC-012
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    /// @notice Mapping of campaign ID => user => claimed amount (for Merkle)
    mapping(uint256 => mapping(address => uint256)) public claimedAmount;

    /// @notice Mapping of user => rate limit info - SEC-011
    mapping(address => RateLimitInfo) public rateLimits;

    /// @notice Mapping of campaign ID => accumulated dust - SEC-007
    mapping(uint256 => uint256) public campaignDust;

    /// @notice Set of active streaming campaign IDs
    uint256[] public activeStreamingCampaigns;

    /// @notice Set of active Merkle campaign IDs
    uint256[] public activeMerkleCampaigns;

    // ============ Events - SEC-013 ============

    /// @notice Emitted when a streaming campaign is created
    event StreamingCampaignCreated(
        uint256 indexed campaignId,
        address indexed rewardToken,
        uint256 totalRewards,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardRate,
        string name
    );

    /// @notice Emitted when a Merkle campaign is created
    event MerkleCampaignCreated(
        uint256 indexed campaignId,
        address indexed rewardToken,
        uint256 totalRewards,
        bytes32 merkleRoot,
        uint256 startTime,
        uint256 expirationTime,
        string name
    );

    /// @notice Emitted when rewards are claimed from streaming campaign
    event StreamingRewardsClaimed(
        uint256 indexed campaignId, address indexed user, uint256 amount, uint256 totalClaimed
    );

    /// @notice Emitted when rewards are claimed from Merkle campaign - SEC-012
    event MerkleRewardsClaimed(uint256 indexed campaignId, address indexed user, uint256 amount, uint256 leafIndex);

    /// @notice Emitted when campaign status changes
    event CampaignStatusChanged(uint256 indexed campaignId, CampaignStatus oldStatus, CampaignStatus newStatus);

    /// @notice Emitted when campaign is funded
    event CampaignFunded(uint256 indexed campaignId, address indexed funder, uint256 amount, uint256 newTotal);

    /// @notice Emitted when funds are reclaimed from expired/cancelled campaign
    event FundsReclaimed(uint256 indexed campaignId, address indexed recipient, uint256 amount);

    /// @notice Emitted when user allocation is set
    event AllocationSet(uint256 indexed campaignId, address indexed user, uint256 allocation);

    /// @notice Emitted when treasury is updated
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when dust is collected - SEC-007
    event DustCollected(uint256 indexed campaignId, uint256 amount);

    /// @notice Emitted when rate limit is exceeded - SEC-011
    event RateLimitExceeded(address indexed user, uint256 windowStart, uint256 claimCount);

    /// @notice Emitted when Merkle root is updated
    event MerkleRootUpdated(uint256 indexed campaignId, bytes32 oldRoot, bytes32 newRoot);

    // ============ Errors ============

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when campaign does not exist
    error CampaignNotFound();

    /// @notice Thrown when campaign is not active
    error CampaignNotActive();

    /// @notice Thrown when campaign has not started
    error CampaignNotStarted();

    /// @notice Thrown when campaign has expired
    error CampaignExpired();

    /// @notice Thrown when user has already claimed (Merkle)
    error AlreadyClaimed();

    /// @notice Thrown when Merkle proof is invalid - SEC-012
    error InvalidMerkleProof();

    /// @notice Thrown when rate limit exceeded - SEC-011
    error RateLimitExceeded_Error();

    /// @notice Thrown when nothing to claim
    error NothingToClaim();

    /// @notice Thrown when duration is invalid
    error InvalidDuration();

    /// @notice Thrown when start time is in the past
    error InvalidStartTime();

    /// @notice Thrown when insufficient rewards in campaign
    error InsufficientRewards();

    /// @notice Thrown when campaign type mismatch
    error InvalidCampaignType();

    /// @notice Thrown when allocation exceeds remaining
    error AllocationExceedsRemaining();

    /// @notice Thrown when caller has no allocation
    error NoAllocation();

    /// @notice Thrown when Merkle root is zero
    error InvalidMerkleRoot();

    // ============ Constructor ============

    /**
     * @notice Initializes the RewardsDistributor contract
     * @param _treasury Address to receive reclaimed funds
     * @param _admin Address to receive admin role
     */
    constructor(address _treasury, address _admin) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();

        treasury = _treasury;
        nextCampaignId = 1;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(CAMPAIGN_MANAGER_ROLE, _admin);
    }

    // ============ Streaming Campaign Functions ============

    /**
     * @notice Create a new streaming rewards campaign
     * @param rewardToken Token to distribute
     * @param totalRewards Total amount to distribute
     * @param startTime When distribution starts
     * @param duration How long distribution lasts
     * @param name Campaign name
     * @param description Campaign description
     * @return campaignId The ID of the created campaign
     */
    function createStreamingCampaign(
        address rewardToken,
        uint256 totalRewards,
        uint256 startTime,
        uint256 duration,
        string calldata name,
        string calldata description
    )
        external
        nonReentrant
        onlyRole(CAMPAIGN_MANAGER_ROLE)
        returns (uint256 campaignId)
    {
        if (rewardToken == address(0)) revert ZeroAddress();
        if (totalRewards == 0) revert ZeroAmount();
        if (startTime < block.timestamp) revert InvalidStartTime();
        if (duration < MIN_STREAMING_DURATION || duration > MAX_STREAMING_DURATION) {
            revert InvalidDuration();
        }

        campaignId = nextCampaignId++;
        uint256 endTime = startTime + duration;

        // Calculate reward rate - SEC-007: Round down for rate calculation
        uint256 rewardRate = totalRewards.mulDiv(PRECISION, duration, Math.Rounding.Floor);

        streamingCampaigns[campaignId] = StreamingCampaign({
            rewardToken: IERC20(rewardToken),
            totalRewards: totalRewards,
            claimedRewards: 0,
            startTime: startTime,
            endTime: endTime,
            rewardRate: rewardRate,
            status: CampaignStatus.Active,
            campaignType: CampaignType.Streaming,
            name: name,
            description: description
        });

        activeStreamingCampaigns.push(campaignId);

        // Transfer tokens to this contract
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewards);

        emit StreamingCampaignCreated(campaignId, rewardToken, totalRewards, startTime, endTime, rewardRate, name);
    }

    /**
     * @notice Set user allocation for streaming campaign
     * @param campaignId Campaign ID
     * @param user User address
     * @param allocation User's total allocation
     */
    function setAllocation(
        uint256 campaignId,
        address user,
        uint256 allocation
    )
        external
        onlyRole(CAMPAIGN_MANAGER_ROLE)
    {
        StreamingCampaign storage campaign = streamingCampaigns[campaignId];
        if (campaign.totalRewards == 0) revert CampaignNotFound();
        if (campaign.campaignType != CampaignType.Streaming) revert InvalidCampaignType();

        UserStreamingPosition storage position = userStreamingPositions[campaignId][user];

        // Check if new allocation would exceed remaining
        uint256 remainingRewards = campaign.totalRewards - campaign.claimedRewards;
        uint256 existingAllocation = position.allocation;
        uint256 netIncrease = allocation > existingAllocation ? allocation - existingAllocation : 0;

        if (netIncrease > remainingRewards) revert AllocationExceedsRemaining();

        position.allocation = allocation;
        if (position.lastClaimTime == 0) {
            position.lastClaimTime = campaign.startTime;
        }

        emit AllocationSet(campaignId, user, allocation);
    }

    /**
     * @notice Set allocations for multiple users in batch
     * @param campaignId Campaign ID
     * @param users Array of user addresses
     * @param allocations Array of allocations
     */
    function setAllocationsBatch(
        uint256 campaignId,
        address[] calldata users,
        uint256[] calldata allocations
    )
        external
        onlyRole(CAMPAIGN_MANAGER_ROLE)
    {
        if (users.length != allocations.length) revert ZeroAmount();

        StreamingCampaign storage campaign = streamingCampaigns[campaignId];
        if (campaign.totalRewards == 0) revert CampaignNotFound();
        if (campaign.campaignType != CampaignType.Streaming) revert InvalidCampaignType();

        for (uint256 i = 0; i < users.length; i++) {
            UserStreamingPosition storage position = userStreamingPositions[campaignId][users[i]];
            position.allocation = allocations[i];
            if (position.lastClaimTime == 0) {
                position.lastClaimTime = campaign.startTime;
            }
            emit AllocationSet(campaignId, users[i], allocations[i]);
        }
    }

    /**
     * @notice Claim streaming rewards
     * @param campaignId Campaign ID to claim from
     * @return claimed Amount of rewards claimed
     */
    function claimStreamingRewards(uint256 campaignId) external nonReentrant whenNotPaused returns (uint256 claimed) {
        // Check rate limit - SEC-011
        _checkAndUpdateRateLimit(msg.sender);

        StreamingCampaign storage campaign = streamingCampaigns[campaignId];
        if (campaign.totalRewards == 0) revert CampaignNotFound();
        if (campaign.status != CampaignStatus.Active) revert CampaignNotActive();
        if (block.timestamp < campaign.startTime) revert CampaignNotStarted();

        UserStreamingPosition storage position = userStreamingPositions[campaignId][msg.sender];
        if (position.allocation == 0) revert NoAllocation();

        // Calculate claimable amount
        claimed = _calculateStreamingClaimable(campaignId, msg.sender);
        if (claimed == 0) revert NothingToClaim();

        // Update state
        position.lastClaimTime = block.timestamp;
        position.totalClaimed += claimed;
        campaign.claimedRewards += claimed;

        // SEC-007: Track dust from rounding
        uint256 expectedTotal = _calculateExpectedTotal(campaignId, msg.sender);
        if (position.totalClaimed < expectedTotal) {
            uint256 dust = expectedTotal - position.totalClaimed;
            // Only accumulate significant dust
            if (dust > 0 && dust < PRECISION) {
                campaignDust[campaignId] += dust;
            }
        }

        // Transfer rewards
        campaign.rewardToken.safeTransfer(msg.sender, claimed);

        emit StreamingRewardsClaimed(campaignId, msg.sender, claimed, position.totalClaimed);
    }

    // ============ Merkle Campaign Functions ============

    /**
     * @notice Create a new Merkle rewards campaign - SEC-012
     * @param rewardToken Token to distribute
     * @param totalRewards Total amount to distribute
     * @param merkleRoot Root of the Merkle tree
     * @param startTime When claims can begin
     * @param expirationTime When claims expire
     * @param name Campaign name
     * @param description Campaign description
     * @return campaignId The ID of the created campaign
     */
    function createMerkleCampaign(
        address rewardToken,
        uint256 totalRewards,
        bytes32 merkleRoot,
        uint256 startTime,
        uint256 expirationTime,
        string calldata name,
        string calldata description
    )
        external
        nonReentrant
        onlyRole(CAMPAIGN_MANAGER_ROLE)
        returns (uint256 campaignId)
    {
        if (rewardToken == address(0)) revert ZeroAddress();
        if (totalRewards == 0) revert ZeroAmount();
        if (merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (startTime < block.timestamp) revert InvalidStartTime();
        if (expirationTime <= startTime) revert InvalidDuration();

        campaignId = nextCampaignId++;

        merkleCampaigns[campaignId] = MerkleCampaign({
            rewardToken: IERC20(rewardToken),
            totalRewards: totalRewards,
            claimedRewards: 0,
            merkleRoot: merkleRoot,
            startTime: startTime,
            expirationTime: expirationTime,
            status: CampaignStatus.Active,
            campaignType: CampaignType.Merkle,
            name: name,
            description: description
        });

        activeMerkleCampaigns.push(campaignId);

        // Transfer tokens to this contract
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewards);

        emit MerkleCampaignCreated(campaignId, rewardToken, totalRewards, merkleRoot, startTime, expirationTime, name);
    }

    /**
     * @notice Claim rewards from Merkle campaign - SEC-012
     * @param campaignId Campaign ID (included in leaf for replay prevention)
     * @param amount Amount to claim (must match Merkle leaf)
     * @param leafIndex Index of the leaf (for tracking)
     * @param merkleProof Merkle proof for verification
     * @dev Leaf structure: keccak256(abi.encodePacked(campaignId, account, amount, leafIndex))
     */
    function claimMerkleRewards(
        uint256 campaignId,
        uint256 amount,
        uint256 leafIndex,
        bytes32[] calldata merkleProof
    )
        external
        nonReentrant
        whenNotPaused
    {
        // Check rate limit - SEC-011
        _checkAndUpdateRateLimit(msg.sender);

        MerkleCampaign storage campaign = merkleCampaigns[campaignId];
        if (campaign.totalRewards == 0) revert CampaignNotFound();
        if (campaign.status != CampaignStatus.Active) revert CampaignNotActive();
        if (block.timestamp < campaign.startTime) revert CampaignNotStarted();
        if (block.timestamp > campaign.expirationTime) revert CampaignExpired();

        // Check if already claimed - SEC-012
        if (hasClaimed[campaignId][msg.sender]) revert AlreadyClaimed();

        // SEC-012: Include campaignId in leaf to prevent cross-campaign replay
        bytes32 leaf = keccak256(abi.encodePacked(campaignId, msg.sender, amount, leafIndex));

        // Verify Merkle proof
        if (!MerkleProof.verify(merkleProof, campaign.merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // Check sufficient rewards remain
        if (campaign.claimedRewards + amount > campaign.totalRewards) {
            revert InsufficientRewards();
        }

        // Update state - SEC-012: Mark as claimed for this campaign
        hasClaimed[campaignId][msg.sender] = true;
        claimedAmount[campaignId][msg.sender] = amount;
        campaign.claimedRewards += amount;

        // Transfer rewards
        campaign.rewardToken.safeTransfer(msg.sender, amount);

        emit MerkleRewardsClaimed(campaignId, msg.sender, amount, leafIndex);
    }

    /**
     * @notice Update Merkle root for a campaign (for corrections)
     * @param campaignId Campaign ID
     * @param newMerkleRoot New Merkle root
     * @dev Can only be done before any claims
     */
    function updateMerkleRoot(uint256 campaignId, bytes32 newMerkleRoot) external onlyRole(CAMPAIGN_MANAGER_ROLE) {
        MerkleCampaign storage campaign = merkleCampaigns[campaignId];
        if (campaign.totalRewards == 0) revert CampaignNotFound();
        if (newMerkleRoot == bytes32(0)) revert InvalidMerkleRoot();

        // Only allow update if no claims have been made
        if (campaign.claimedRewards > 0) revert AlreadyClaimed();

        bytes32 oldRoot = campaign.merkleRoot;
        campaign.merkleRoot = newMerkleRoot;

        emit MerkleRootUpdated(campaignId, oldRoot, newMerkleRoot);
    }

    // ============ Campaign Management Functions ============

    /**
     * @notice Pause a campaign
     * @param campaignId Campaign ID
     * @param isMerkle True for Merkle campaign, false for streaming
     */
    function pauseCampaign(uint256 campaignId, bool isMerkle) external onlyRole(CAMPAIGN_MANAGER_ROLE) {
        CampaignStatus oldStatus;

        if (isMerkle) {
            MerkleCampaign storage campaign = merkleCampaigns[campaignId];
            if (campaign.totalRewards == 0) revert CampaignNotFound();
            oldStatus = campaign.status;
            campaign.status = CampaignStatus.Paused;
        } else {
            StreamingCampaign storage campaign = streamingCampaigns[campaignId];
            if (campaign.totalRewards == 0) revert CampaignNotFound();
            oldStatus = campaign.status;
            campaign.status = CampaignStatus.Paused;
        }

        emit CampaignStatusChanged(campaignId, oldStatus, CampaignStatus.Paused);
    }

    /**
     * @notice Resume a paused campaign
     * @param campaignId Campaign ID
     * @param isMerkle True for Merkle campaign, false for streaming
     */
    function resumeCampaign(uint256 campaignId, bool isMerkle) external onlyRole(CAMPAIGN_MANAGER_ROLE) {
        CampaignStatus oldStatus;

        if (isMerkle) {
            MerkleCampaign storage campaign = merkleCampaigns[campaignId];
            if (campaign.totalRewards == 0) revert CampaignNotFound();
            oldStatus = campaign.status;
            campaign.status = CampaignStatus.Active;
        } else {
            StreamingCampaign storage campaign = streamingCampaigns[campaignId];
            if (campaign.totalRewards == 0) revert CampaignNotFound();
            oldStatus = campaign.status;
            campaign.status = CampaignStatus.Active;
        }

        emit CampaignStatusChanged(campaignId, oldStatus, CampaignStatus.Active);
    }

    /**
     * @notice Cancel campaign and reclaim remaining funds
     * @param campaignId Campaign ID
     * @param isMerkle True for Merkle campaign, false for streaming
     */
    function cancelCampaign(uint256 campaignId, bool isMerkle) external nonReentrant onlyRole(ADMIN_ROLE) {
        CampaignStatus oldStatus;
        uint256 remaining;
        IERC20 token;

        if (isMerkle) {
            MerkleCampaign storage campaign = merkleCampaigns[campaignId];
            if (campaign.totalRewards == 0) revert CampaignNotFound();
            oldStatus = campaign.status;
            campaign.status = CampaignStatus.Cancelled;
            remaining = campaign.totalRewards - campaign.claimedRewards;
            token = campaign.rewardToken;
        } else {
            StreamingCampaign storage campaign = streamingCampaigns[campaignId];
            if (campaign.totalRewards == 0) revert CampaignNotFound();
            oldStatus = campaign.status;
            campaign.status = CampaignStatus.Cancelled;
            remaining = campaign.totalRewards - campaign.claimedRewards;
            token = campaign.rewardToken;
        }

        emit CampaignStatusChanged(campaignId, oldStatus, CampaignStatus.Cancelled);

        if (remaining > 0) {
            token.safeTransfer(treasury, remaining);
            emit FundsReclaimed(campaignId, treasury, remaining);
        }
    }

    /**
     * @notice Reclaim funds from expired Merkle campaign
     * @param campaignId Campaign ID
     */
    function reclaimExpiredFunds(uint256 campaignId) external nonReentrant onlyRole(ADMIN_ROLE) {
        MerkleCampaign storage campaign = merkleCampaigns[campaignId];
        if (campaign.totalRewards == 0) revert CampaignNotFound();
        if (block.timestamp <= campaign.expirationTime) revert CampaignNotActive();

        campaign.status = CampaignStatus.Expired;
        uint256 remaining = campaign.totalRewards - campaign.claimedRewards;

        emit CampaignStatusChanged(campaignId, CampaignStatus.Active, CampaignStatus.Expired);

        if (remaining > 0) {
            campaign.rewardToken.safeTransfer(treasury, remaining);
            emit FundsReclaimed(campaignId, treasury, remaining);
        }
    }

    /**
     * @notice Collect accumulated dust from campaign - SEC-007
     * @param campaignId Campaign ID
     */
    function collectDust(uint256 campaignId) external nonReentrant onlyRole(ADMIN_ROLE) {
        uint256 dust = campaignDust[campaignId];
        if (dust == 0) revert NothingToClaim();

        campaignDust[campaignId] = 0;

        StreamingCampaign storage campaign = streamingCampaigns[campaignId];
        if (campaign.totalRewards > 0) {
            campaign.rewardToken.safeTransfer(treasury, dust);
        }

        emit DustCollected(campaignId, dust);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();

        address oldTreasury = treasury;
        treasury = newTreasury;

        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get claimable streaming rewards for a user
     * @param campaignId Campaign ID
     * @param user User address
     * @return claimable Amount of rewards claimable
     */
    function getClaimableStreaming(uint256 campaignId, address user) external view returns (uint256 claimable) {
        return _calculateStreamingClaimable(campaignId, user);
    }

    /**
     * @notice Get streaming campaign info
     * @param campaignId Campaign ID
     * @return rewardToken Token address
     * @return totalRewards Total rewards
     * @return claimedRewards Claimed rewards
     * @return startTime Start time
     * @return endTime End time
     * @return status Campaign status
     */
    function getStreamingCampaign(uint256 campaignId)
        external
        view
        returns (
            address rewardToken,
            uint256 totalRewards,
            uint256 claimedRewards,
            uint256 startTime,
            uint256 endTime,
            CampaignStatus status
        )
    {
        StreamingCampaign storage c = streamingCampaigns[campaignId];
        return (address(c.rewardToken), c.totalRewards, c.claimedRewards, c.startTime, c.endTime, c.status);
    }

    /**
     * @notice Get Merkle campaign info
     * @param campaignId Campaign ID
     * @return rewardToken Token address
     * @return totalRewards Total rewards
     * @return claimedRewards Claimed rewards
     * @return merkleRoot Merkle root
     * @return startTime Start time
     * @return expirationTime Expiration time
     * @return status Campaign status
     */
    function getMerkleCampaign(uint256 campaignId)
        external
        view
        returns (
            address rewardToken,
            uint256 totalRewards,
            uint256 claimedRewards,
            bytes32 merkleRoot,
            uint256 startTime,
            uint256 expirationTime,
            CampaignStatus status
        )
    {
        MerkleCampaign storage c = merkleCampaigns[campaignId];
        return (
            address(c.rewardToken),
            c.totalRewards,
            c.claimedRewards,
            c.merkleRoot,
            c.startTime,
            c.expirationTime,
            c.status
        );
    }

    /**
     * @notice Get user's streaming position
     * @param campaignId Campaign ID
     * @param user User address
     * @return lastClaimTime Last claim timestamp
     * @return totalClaimed Total claimed amount
     * @return allocation User's allocation
     */
    function getUserStreamingPosition(
        uint256 campaignId,
        address user
    )
        external
        view
        returns (uint256 lastClaimTime, uint256 totalClaimed, uint256 allocation)
    {
        UserStreamingPosition storage p = userStreamingPositions[campaignId][user];
        return (p.lastClaimTime, p.totalClaimed, p.allocation);
    }

    /**
     * @notice Check if user can claim (rate limit check) - SEC-011
     * @param user User address
     * @return canClaim Whether user can claim
     * @return remainingClaims Remaining claims in window
     */
    function canUserClaim(address user) external view returns (bool canClaim, uint256 remainingClaims) {
        RateLimitInfo storage info = rateLimits[user];

        if (block.timestamp >= info.windowStart + RATE_LIMIT_WINDOW) {
            return (true, MAX_CLAIMS_PER_WINDOW);
        }

        if (info.claimCount >= MAX_CLAIMS_PER_WINDOW) {
            return (false, 0);
        }

        return (true, MAX_CLAIMS_PER_WINDOW - info.claimCount);
    }

    /**
     * @notice Verify Merkle proof for a claim - SEC-012
     * @param campaignId Campaign ID
     * @param account User address
     * @param amount Claim amount
     * @param leafIndex Leaf index
     * @param merkleProof Merkle proof
     * @return valid Whether proof is valid
     */
    function verifyMerkleProof(
        uint256 campaignId,
        address account,
        uint256 amount,
        uint256 leafIndex,
        bytes32[] calldata merkleProof
    )
        external
        view
        returns (bool valid)
    {
        MerkleCampaign storage campaign = merkleCampaigns[campaignId];
        if (campaign.totalRewards == 0) return false;

        // SEC-012: Include campaignId in leaf
        bytes32 leaf = keccak256(abi.encodePacked(campaignId, account, amount, leafIndex));
        return MerkleProof.verify(merkleProof, campaign.merkleRoot, leaf);
    }

    /**
     * @notice Get number of active streaming campaigns
     * @return count Number of active campaigns
     */
    function getActiveStreamingCampaignCount() external view returns (uint256 count) {
        return activeStreamingCampaigns.length;
    }

    /**
     * @notice Get number of active Merkle campaigns
     * @return count Number of active campaigns
     */
    function getActiveMerkleCampaignCount() external view returns (uint256 count) {
        return activeMerkleCampaigns.length;
    }

    // ============ Internal Functions ============

    /**
     * @notice Calculate claimable streaming rewards - SEC-007
     * @param campaignId Campaign ID
     * @param user User address
     * @return claimable Amount claimable
     */
    function _calculateStreamingClaimable(uint256 campaignId, address user) internal view returns (uint256 claimable) {
        StreamingCampaign storage campaign = streamingCampaigns[campaignId];
        UserStreamingPosition storage position = userStreamingPositions[campaignId][user];

        if (position.allocation == 0) return 0;
        if (block.timestamp < campaign.startTime) return 0;

        uint256 lastClaim = position.lastClaimTime;
        if (lastClaim < campaign.startTime) {
            lastClaim = campaign.startTime;
        }

        uint256 currentTime = block.timestamp > campaign.endTime ? campaign.endTime : block.timestamp;

        if (currentTime <= lastClaim) return 0;

        uint256 elapsed = currentTime - lastClaim;
        uint256 totalDuration = campaign.endTime - campaign.startTime;

        // SEC-007: Round DOWN for user claims (favor protocol)
        claimable = position.allocation.mulDiv(elapsed, totalDuration, Math.Rounding.Floor);

        // Ensure we don't exceed remaining allocation
        uint256 remaining = position.allocation - position.totalClaimed;
        if (claimable > remaining) {
            claimable = remaining;
        }

        return claimable;
    }

    /**
     * @notice Calculate expected total rewards for a user
     * @param campaignId Campaign ID
     * @param user User address
     * @return expected Expected total
     */
    function _calculateExpectedTotal(uint256 campaignId, address user) internal view returns (uint256 expected) {
        StreamingCampaign storage campaign = streamingCampaigns[campaignId];
        UserStreamingPosition storage position = userStreamingPositions[campaignId][user];

        if (block.timestamp >= campaign.endTime) {
            return position.allocation;
        }

        uint256 elapsed = block.timestamp - campaign.startTime;
        uint256 totalDuration = campaign.endTime - campaign.startTime;

        return position.allocation.mulDiv(elapsed, totalDuration, Math.Rounding.Floor);
    }

    /**
     * @notice Check and update rate limit - SEC-011
     * @param user User address
     */
    function _checkAndUpdateRateLimit(address user) internal {
        RateLimitInfo storage info = rateLimits[user];

        // Reset window if expired
        if (block.timestamp >= info.windowStart + RATE_LIMIT_WINDOW) {
            info.windowStart = block.timestamp;
            info.claimCount = 1;
            return;
        }

        // Check if limit exceeded
        if (info.claimCount >= MAX_CLAIMS_PER_WINDOW) {
            emit RateLimitExceeded(user, info.windowStart, info.claimCount);
            revert RateLimitExceeded_Error();
        }

        // Increment count
        info.claimCount++;
    }
}
