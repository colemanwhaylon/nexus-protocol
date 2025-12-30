// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NexusAirdrop
 * @author Nexus Protocol Team
 * @notice Merkle-based airdrop distribution contract with multiple campaigns
 * @dev Supports multiple airdrop campaigns with different tokens and merkle roots
 *
 * Features:
 * - Multiple concurrent airdrop campaigns
 * - Merkle proof verification for gas-efficient claims
 * - Configurable claim windows (start/end times)
 * - Vesting support for gradual token release
 * - Campaign expiration and fund recovery
 * - Delegation of unclaimed tokens
 */
contract NexusAirdrop is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role identifier for campaign managers
    bytes32 public constant CAMPAIGN_MANAGER_ROLE = keccak256("CAMPAIGN_MANAGER_ROLE");

    /// @notice Minimum campaign duration (1 day)
    uint256 public constant MIN_CAMPAIGN_DURATION = 1 days;

    /// @notice Maximum campaign duration (365 days)
    uint256 public constant MAX_CAMPAIGN_DURATION = 365 days;

    /// @notice Maximum vesting duration (4 years)
    uint256 public constant MAX_VESTING_DURATION = 4 * 365 days;

    // ============ Structs ============

    /// @notice Campaign configuration
    struct Campaign {
        IERC20 token; // Token being distributed
        bytes32 merkleRoot; // Merkle root for claim verification
        uint256 totalAmount; // Total tokens allocated to campaign
        uint256 claimedAmount; // Total tokens claimed so far
        uint256 startTime; // When claims can begin
        uint256 endTime; // When claims end
        uint256 vestingDuration; // Vesting period (0 for immediate)
        uint256 cliffDuration; // Cliff period before vesting starts
        bool active; // Whether campaign is active
        string name; // Campaign name/description
    }

    /// @notice User claim information per campaign
    struct ClaimInfo {
        uint256 totalAllocation; // Total tokens allocated to user
        uint256 claimedAmount; // Amount already claimed
        uint256 vestingStart; // When vesting started (first claim)
        bool initialized; // Whether user has made first claim
    }

    // ============ State Variables ============

    /// @notice Counter for campaign IDs
    uint256 public campaignCount;

    /// @notice Treasury address for recovered funds
    address public treasury;

    /// @notice Mapping of campaign ID to campaign info
    mapping(uint256 => Campaign) public campaigns;

    /// @notice Mapping of campaign ID => user address => claim info
    mapping(uint256 => mapping(address => ClaimInfo)) public claims;

    // ============ Events ============

    /// @notice Emitted when a new campaign is created
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed token,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime,
        string name
    );

    /// @notice Emitted when a campaign is updated
    event CampaignUpdated(uint256 indexed campaignId, bytes32 newMerkleRoot, uint256 newEndTime);

    /// @notice Emitted when a campaign is deactivated
    event CampaignDeactivated(uint256 indexed campaignId);

    /// @notice Emitted when tokens are claimed
    event TokensClaimed(uint256 indexed campaignId, address indexed user, uint256 amount, uint256 totalClaimed);

    /// @notice Emitted when unclaimed tokens are recovered
    event TokensRecovered(uint256 indexed campaignId, address indexed to, uint256 amount);

    /// @notice Emitted when treasury is updated
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // ============ Errors ============

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when campaign doesn't exist
    error CampaignNotFound();

    /// @notice Thrown when campaign is not active
    error CampaignNotActive();

    /// @notice Thrown when campaign hasn't started yet
    error CampaignNotStarted();

    /// @notice Thrown when campaign has ended
    error CampaignEnded();

    /// @notice Thrown when campaign is still active (for recovery)
    error CampaignStillActive();

    /// @notice Thrown when merkle proof is invalid
    error InvalidProof();

    /// @notice Thrown when nothing to claim
    error NothingToClaim();

    /// @notice Thrown when allocation already claimed
    error AlreadyFullyClaimed();

    /// @notice Thrown when campaign duration is invalid
    error InvalidCampaignDuration();

    /// @notice Thrown when vesting duration is invalid
    error InvalidVestingDuration();

    /// @notice Thrown when cliff exceeds vesting duration
    error CliffExceedsVesting();

    /// @notice Thrown when start time is in the past
    error StartTimeInPast();

    // ============ Constructor ============

    /**
     * @notice Initializes the airdrop contract
     * @param _treasury Address to receive recovered funds
     * @param _admin Address to receive admin role
     */
    constructor(address _treasury, address _admin) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();

        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(CAMPAIGN_MANAGER_ROLE, _admin);
    }

    // ============ External Functions ============

    /**
     * @notice Create a new airdrop campaign
     * @param token Token to distribute
     * @param merkleRoot Merkle root for claim verification
     * @param totalAmount Total tokens to distribute
     * @param startTime When claims can begin
     * @param endTime When claims end
     * @param vestingDuration Vesting period (0 for immediate distribution)
     * @param cliffDuration Cliff period before vesting starts
     * @param name Campaign name/description
     * @return campaignId The ID of the created campaign
     */
    function createCampaign(
        address token,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime,
        uint256 vestingDuration,
        uint256 cliffDuration,
        string calldata name
    )
        external
        onlyRole(CAMPAIGN_MANAGER_ROLE)
        returns (uint256 campaignId)
    {
        if (token == address(0)) revert ZeroAddress();
        if (totalAmount == 0) revert ZeroAmount();
        if (startTime < block.timestamp) revert StartTimeInPast();

        uint256 duration = endTime - startTime;
        if (duration < MIN_CAMPAIGN_DURATION || duration > MAX_CAMPAIGN_DURATION) {
            revert InvalidCampaignDuration();
        }

        if (vestingDuration > MAX_VESTING_DURATION) {
            revert InvalidVestingDuration();
        }

        if (cliffDuration > vestingDuration) {
            revert CliffExceedsVesting();
        }

        campaignId = campaignCount++;

        campaigns[campaignId] = Campaign({
            token: IERC20(token),
            merkleRoot: merkleRoot,
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: startTime,
            endTime: endTime,
            vestingDuration: vestingDuration,
            cliffDuration: cliffDuration,
            active: true,
            name: name
        });

        // Transfer tokens to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);

        emit CampaignCreated(campaignId, token, merkleRoot, totalAmount, startTime, endTime, name);
    }

    /**
     * @notice Claim tokens from an airdrop campaign
     * @param campaignId ID of the campaign
     * @param totalAllocation Total allocation for the user (from merkle tree)
     * @param merkleProof Proof of inclusion in merkle tree
     */
    function claim(
        uint256 campaignId,
        uint256 totalAllocation,
        bytes32[] calldata merkleProof
    )
        external
        nonReentrant
        whenNotPaused
    {
        Campaign storage campaign = campaigns[campaignId];

        if (!campaign.active) revert CampaignNotActive();
        if (block.timestamp < campaign.startTime) revert CampaignNotStarted();
        if (block.timestamp > campaign.endTime) revert CampaignEnded();

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalAllocation));
        if (!MerkleProof.verify(merkleProof, campaign.merkleRoot, leaf)) {
            revert InvalidProof();
        }

        ClaimInfo storage claimInfo = claims[campaignId][msg.sender];

        // Initialize claim info on first claim
        if (!claimInfo.initialized) {
            claimInfo.totalAllocation = totalAllocation;
            claimInfo.vestingStart = block.timestamp;
            claimInfo.initialized = true;
        }

        // Calculate claimable amount
        uint256 claimable = _calculateClaimable(campaign, claimInfo);

        if (claimable == 0) revert NothingToClaim();

        // Update state
        claimInfo.claimedAmount += claimable;
        campaign.claimedAmount += claimable;

        // Transfer tokens
        campaign.token.safeTransfer(msg.sender, claimable);

        emit TokensClaimed(campaignId, msg.sender, claimable, claimInfo.claimedAmount);
    }

    /**
     * @notice Update a campaign's merkle root (for corrections)
     * @param campaignId ID of the campaign
     * @param newMerkleRoot New merkle root
     */
    function updateCampaignMerkleRoot(
        uint256 campaignId,
        bytes32 newMerkleRoot
    )
        external
        onlyRole(CAMPAIGN_MANAGER_ROLE)
    {
        Campaign storage campaign = campaigns[campaignId];
        if (!campaign.active) revert CampaignNotActive();

        campaign.merkleRoot = newMerkleRoot;

        emit CampaignUpdated(campaignId, newMerkleRoot, campaign.endTime);
    }

    /**
     * @notice Extend a campaign's end time
     * @param campaignId ID of the campaign
     * @param newEndTime New end time
     */
    function extendCampaign(uint256 campaignId, uint256 newEndTime) external onlyRole(CAMPAIGN_MANAGER_ROLE) {
        Campaign storage campaign = campaigns[campaignId];
        if (!campaign.active) revert CampaignNotActive();

        if (newEndTime <= campaign.endTime) revert InvalidCampaignDuration();

        uint256 newDuration = newEndTime - campaign.startTime;
        if (newDuration > MAX_CAMPAIGN_DURATION) revert InvalidCampaignDuration();

        campaign.endTime = newEndTime;

        emit CampaignUpdated(campaignId, campaign.merkleRoot, newEndTime);
    }

    /**
     * @notice Deactivate a campaign
     * @param campaignId ID of the campaign
     */
    function deactivateCampaign(uint256 campaignId) external onlyRole(ADMIN_ROLE) {
        Campaign storage campaign = campaigns[campaignId];
        if (!campaign.active) revert CampaignNotActive();

        campaign.active = false;

        emit CampaignDeactivated(campaignId);
    }

    /**
     * @notice Recover unclaimed tokens after campaign ends
     * @param campaignId ID of the campaign
     */
    function recoverTokens(uint256 campaignId) external onlyRole(ADMIN_ROLE) {
        Campaign storage campaign = campaigns[campaignId];

        // Can only recover after campaign ends or is deactivated
        if (campaign.active && block.timestamp <= campaign.endTime) {
            revert CampaignStillActive();
        }

        uint256 unclaimed = campaign.totalAmount - campaign.claimedAmount;
        if (unclaimed == 0) revert ZeroAmount();

        // Update state to prevent double recovery
        campaign.claimedAmount = campaign.totalAmount;

        // Transfer to treasury
        campaign.token.safeTransfer(treasury, unclaimed);

        emit TokensRecovered(campaignId, treasury, unclaimed);
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
     * @notice Get campaign information
     * @param campaignId ID of the campaign
     * @return token Token address
     * @return merkleRoot Merkle root
     * @return totalAmount Total allocation
     * @return claimedAmount Amount claimed
     * @return startTime Start time
     * @return endTime End time
     * @return active Whether active
     * @return name Campaign name
     */
    function getCampaign(uint256 campaignId)
        external
        view
        returns (
            address token,
            bytes32 merkleRoot,
            uint256 totalAmount,
            uint256 claimedAmount,
            uint256 startTime,
            uint256 endTime,
            bool active,
            string memory name
        )
    {
        Campaign storage campaign = campaigns[campaignId];
        return (
            address(campaign.token),
            campaign.merkleRoot,
            campaign.totalAmount,
            campaign.claimedAmount,
            campaign.startTime,
            campaign.endTime,
            campaign.active,
            campaign.name
        );
    }

    /**
     * @notice Get user claim information for a campaign
     * @param campaignId ID of the campaign
     * @param user User address
     * @return totalAllocation Total allocation
     * @return claimedAmount Amount claimed
     * @return claimable Currently claimable amount
     * @return vestingStart When vesting started
     * @return initialized Whether initialized
     */
    function getUserClaim(
        uint256 campaignId,
        address user
    )
        external
        view
        returns (
            uint256 totalAllocation,
            uint256 claimedAmount,
            uint256 claimable,
            uint256 vestingStart,
            bool initialized
        )
    {
        Campaign storage campaign = campaigns[campaignId];
        ClaimInfo storage claimInfo = claims[campaignId][user];

        uint256 claimableAmount = 0;
        if (claimInfo.initialized) {
            claimableAmount = _calculateClaimable(campaign, claimInfo);
        }

        return (
            claimInfo.totalAllocation,
            claimInfo.claimedAmount,
            claimableAmount,
            claimInfo.vestingStart,
            claimInfo.initialized
        );
    }

    /**
     * @notice Check if a user can claim from a campaign
     * @param campaignId ID of the campaign
     * @param user User address
     * @param totalAllocation Claimed total allocation
     * @param merkleProof Merkle proof
     * @return canClaim Whether user can claim
     * @return claimableAmount Amount that can be claimed
     */
    function canClaim(
        uint256 campaignId,
        address user,
        uint256 totalAllocation,
        bytes32[] calldata merkleProof
    )
        external
        view
        returns (bool canClaim, uint256 claimableAmount)
    {
        Campaign storage campaign = campaigns[campaignId];

        // Check basic conditions
        if (!campaign.active) return (false, 0);
        if (block.timestamp < campaign.startTime) return (false, 0);
        if (block.timestamp > campaign.endTime) return (false, 0);

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(user, totalAllocation));
        if (!MerkleProof.verify(merkleProof, campaign.merkleRoot, leaf)) {
            return (false, 0);
        }

        ClaimInfo storage claimInfo = claims[campaignId][user];

        // If not initialized, calculate based on provided allocation
        if (!claimInfo.initialized) {
            // For non-vesting, full amount is claimable
            if (campaign.vestingDuration == 0) {
                return (true, totalAllocation);
            }
            // For vesting, only portion after cliff
            if (campaign.cliffDuration > 0) {
                return (false, 0); // Cliff not passed yet
            }
            return (true, totalAllocation);
        }

        // Calculate claimable for existing claim
        claimableAmount = _calculateClaimable(campaign, claimInfo);
        return (claimableAmount > 0, claimableAmount);
    }

    /**
     * @notice Get remaining unclaimed tokens in a campaign
     * @param campaignId ID of the campaign
     * @return Remaining tokens
     */
    function getRemainingTokens(uint256 campaignId) external view returns (uint256) {
        Campaign storage campaign = campaigns[campaignId];
        return campaign.totalAmount - campaign.claimedAmount;
    }

    // ============ Internal Functions ============

    /**
     * @notice Calculate claimable amount based on vesting
     * @param campaign Campaign info
     * @param claimInfo User claim info
     * @return Claimable amount
     */
    function _calculateClaimable(
        Campaign storage campaign,
        ClaimInfo storage claimInfo
    )
        internal
        view
        returns (uint256)
    {
        // If no vesting, all allocation is immediately available
        if (campaign.vestingDuration == 0) {
            return claimInfo.totalAllocation - claimInfo.claimedAmount;
        }

        // Check if still in cliff period
        uint256 cliffEnd = claimInfo.vestingStart + campaign.cliffDuration;
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        // Calculate vested amount
        uint256 vestingEnd = claimInfo.vestingStart + campaign.vestingDuration;
        uint256 vestedAmount;

        if (block.timestamp >= vestingEnd) {
            // Fully vested
            vestedAmount = claimInfo.totalAllocation;
        } else {
            // Partially vested (linear)
            uint256 elapsed = block.timestamp - claimInfo.vestingStart;
            vestedAmount = (claimInfo.totalAllocation * elapsed) / campaign.vestingDuration;
        }

        // Return claimable (vested - already claimed)
        if (vestedAmount <= claimInfo.claimedAmount) {
            return 0;
        }
        return vestedAmount - claimInfo.claimedAmount;
    }
}
