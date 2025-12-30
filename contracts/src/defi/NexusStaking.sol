// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NexusStaking
 * @author Nexus Protocol Team
 * @notice Production-grade staking contract with comprehensive security features
 * @dev Implements staking, delegation, slashing, and unbonding mechanisms
 *
 * Security Features (per SECURITY_REVIEW_BEFORE.md):
 * - SEC-002: Unbonding queue with 7-day default unbonding period
 * - SEC-002: Withdrawal queue limiting daily exits to 10% of total stake
 * - SEC-002: Epoch-based exit processing
 * - SEC-002: Minimum stake duration of 24 hours
 * - SEC-002: Early exit penalty mechanism
 * - SEC-008: Minimum stake threshold (1000 tokens) for slashing eligibility
 * - SEC-008: Proportional slashing based on stake size
 * - SEC-008: Slashing cooldown to prevent rapid re-stake after slash
 * - SEC-011: On-chain rate limiting for unstaking operations
 * - SEC-013: Events for unbonding initiation/completion
 */
contract NexusStaking is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role identifier for authorized slashers
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    /// @notice Default unbonding period (7 days) - SEC-002
    uint256 public constant DEFAULT_UNBONDING_PERIOD = 7 days;

    /// @notice Minimum stake duration before unstaking (24 hours) - SEC-002
    uint256 public constant MIN_STAKE_DURATION = 24 hours;

    /// @notice Default daily withdrawal percentage (10% of total stake) - SEC-002
    uint256 public constant DEFAULT_DAILY_WITHDRAWAL_BPS = 1000; // 10% in basis points

    /// @notice Minimum daily withdrawal percentage (1% of total stake)
    uint256 public constant MIN_DAILY_WITHDRAWAL_BPS = 100; // 1% in basis points

    /// @notice Maximum daily withdrawal percentage (50% of total stake)
    uint256 public constant MAX_CONFIGURABLE_DAILY_BPS = 5000; // 50% in basis points

    /// @notice Minimum stake threshold for slashing eligibility (1000 tokens) - SEC-008
    uint256 public constant MIN_STAKE_FOR_SLASHING = 1000 * 1e18;

    /// @notice Slashing cooldown period to prevent rapid re-stake - SEC-008
    uint256 public constant SLASHING_COOLDOWN = 30 days;

    /// @notice Maximum slashing percentage in basis points (50%)
    uint256 public constant MAX_SLASH_BPS = 5000;

    /// @notice Early exit penalty in basis points (5%) - SEC-002
    uint256 public constant EARLY_EXIT_PENALTY_BPS = 500;

    /// @notice Epoch duration for exit processing (1 day) - SEC-002
    uint256 public constant EPOCH_DURATION = 1 days;

    /// @notice Rate limit window for unstaking operations - SEC-011
    uint256 public constant RATE_LIMIT_WINDOW = 1 hours;

    /// @notice Maximum unstaking operations per rate limit window - SEC-011
    uint256 public constant MAX_UNSTAKE_OPS_PER_WINDOW = 3;

    /// @notice Basis points denominator
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // ============ State Variables ============

    /// @notice The staking token (NexusToken)
    IERC20 public immutable stakingToken;

    /// @notice Total amount of tokens staked
    uint256 public totalStaked;

    /// @notice Total amount in unbonding queue
    uint256 public totalUnbonding;

    /// @notice Current unbonding period (can be adjusted by admin)
    uint256 public unbondingPeriod;

    /// @notice Current daily withdrawal limit in basis points (can be adjusted by admin) - SEC-002
    uint256 public dailyWithdrawalLimitBps;

    /// @notice Treasury address for slashed funds and penalties
    address public treasury;

    /// @notice Current epoch number
    uint256 public currentEpoch;

    /// @notice Timestamp of current epoch start
    uint256 public epochStartTime;

    /// @notice Stake information for each staker
    struct StakeInfo {
        uint256 amount; // Amount currently staked
        uint256 stakedAt; // Timestamp of initial stake
        uint256 lastStakeTime; // Timestamp of last stake action
        address delegatee; // Address delegated to (address(0) if self)
        uint256 delegatedToMe; // Total amount delegated to this address
        uint256 lastSlashedAt; // Timestamp of last slash (for cooldown)
        uint256 totalSlashed; // Cumulative amount slashed from this staker
    }

    /// @notice Unbonding request information - SEC-002
    struct UnbondingRequest {
        uint256 amount; // Amount being unbonded
        uint256 initiatedAt; // When unbonding was initiated
        uint256 completionTime; // When unbonding completes
        uint256 epoch; // Epoch when request was made
        bool processed; // Whether request has been processed
        bool penaltyApplied; // Whether early exit penalty was applied
    }

    /// @notice Rate limiting info for unstaking operations - SEC-011
    struct RateLimitInfo {
        uint256 windowStart; // Start of current rate limit window
        uint256 operationsCount; // Number of operations in current window
    }

    /// @notice Daily withdrawal tracking - SEC-002
    struct DailyWithdrawal {
        uint256 date; // Day identifier (timestamp / 1 day)
        uint256 amount; // Amount withdrawn on this day
    }

    /// @notice Mapping of staker address to stake info
    mapping(address => StakeInfo) public stakes;

    /// @notice Mapping of staker address to their unbonding requests
    mapping(address => UnbondingRequest[]) public unbondingRequests;

    /// @notice Mapping of staker address to rate limit info - SEC-011
    mapping(address => RateLimitInfo) public rateLimits;

    /// @notice Daily withdrawal amounts per epoch - SEC-002
    mapping(uint256 => uint256) public dailyWithdrawals;

    // ============ Events ============

    /// @notice Emitted when tokens are staked
    /// @param staker Address of the staker
    /// @param amount Amount staked
    /// @param totalStake New total stake for the staker
    event Staked(address indexed staker, uint256 amount, uint256 totalStake);

    /// @notice Emitted when unbonding is initiated - SEC-013
    /// @param staker Address of the staker
    /// @param amount Amount being unbonded
    /// @param completionTime When unbonding will complete
    /// @param requestIndex Index of the unbonding request
    /// @param epoch Epoch when request was made
    event UnbondingInitiated(
        address indexed staker, uint256 amount, uint256 completionTime, uint256 requestIndex, uint256 epoch
    );

    /// @notice Emitted when unbonding completes and tokens are withdrawn - SEC-013
    /// @param staker Address of the staker
    /// @param amount Amount withdrawn
    /// @param requestIndex Index of the completed request
    /// @param penaltyAmount Any penalty amount deducted
    event UnbondingCompleted(address indexed staker, uint256 amount, uint256 requestIndex, uint256 penaltyAmount);

    /// @notice Emitted when delegation is set or changed
    /// @param delegator Address delegating their stake
    /// @param oldDelegatee Previous delegatee address
    /// @param newDelegatee New delegatee address
    /// @param amount Amount being delegated
    event DelegationChanged(
        address indexed delegator, address indexed oldDelegatee, address indexed newDelegatee, uint256 amount
    );

    /// @notice Emitted when a staker is slashed - SEC-008
    /// @param staker Address of the slashed staker
    /// @param amount Amount slashed
    /// @param reason Reason for slashing
    /// @param slasher Address of the slasher
    event Slashed(address indexed staker, uint256 amount, string reason, address indexed slasher);

    /// @notice Emitted when unbonding period is updated
    /// @param oldPeriod Previous unbonding period
    /// @param newPeriod New unbonding period
    event UnbondingPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    /// @notice Emitted when daily withdrawal limit is updated
    /// @param oldLimit Previous daily withdrawal limit in basis points
    /// @param newLimit New daily withdrawal limit in basis points
    event DailyWithdrawalLimitUpdated(uint256 oldLimit, uint256 newLimit);

    /// @notice Emitted when treasury address is updated
    /// @param oldTreasury Previous treasury address
    /// @param newTreasury New treasury address
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when a new epoch starts - SEC-002
    /// @param epochNumber The new epoch number
    /// @param startTime Timestamp of epoch start
    event NewEpoch(uint256 indexed epochNumber, uint256 startTime);

    /// @notice Emitted when early exit penalty is applied - SEC-002
    /// @param staker Address of the staker
    /// @param penaltyAmount Amount of penalty
    /// @param requestIndex Index of the request
    event EarlyExitPenaltyApplied(address indexed staker, uint256 penaltyAmount, uint256 requestIndex);

    /// @notice Emitted when rate limit is hit - SEC-011
    /// @param staker Address that hit the rate limit
    /// @param windowStart Start of the rate limit window
    /// @param operationsCount Number of operations in window
    event RateLimitExceeded(address indexed staker, uint256 windowStart, uint256 operationsCount);

    // ============ Errors ============

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when stake amount is insufficient
    error InsufficientStake();

    /// @notice Thrown when unbonding period has not completed
    error UnbondingNotComplete();

    /// @notice Thrown when request index is invalid
    error InvalidRequestIndex();

    /// @notice Thrown when request is already processed
    error RequestAlreadyProcessed();

    /// @notice Thrown when minimum stake duration not met - SEC-002
    error MinStakeDurationNotMet();

    /// @notice Thrown when daily withdrawal limit exceeded - SEC-002
    error DailyWithdrawalLimitExceeded();

    /// @notice Thrown when slash amount exceeds maximum
    error SlashAmountExceedsMax();

    /// @notice Thrown when stake is below minimum for slashing - SEC-008
    error StakeBelowSlashingThreshold();

    /// @notice Thrown when in slashing cooldown period - SEC-008
    error InSlashingCooldown();

    /// @notice Thrown when rate limit is exceeded - SEC-011
    error RateLimitExceeded_Error();

    /// @notice Thrown when cannot delegate to self explicitly
    error CannotDelegateToSelf();

    /// @notice Thrown when unbonding period is invalid
    error InvalidUnbondingPeriod();

    /// @notice Thrown when daily withdrawal limit is invalid
    error InvalidDailyWithdrawalLimit();

    // ============ Constructor ============

    /**
     * @notice Initializes the staking contract
     * @param _stakingToken Address of the token to stake (NexusToken)
     * @param _treasury Address to receive slashed funds and penalties
     * @param _admin Address to receive admin role
     */
    constructor(address _stakingToken, address _treasury, address _admin) {
        if (_stakingToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();

        stakingToken = IERC20(_stakingToken);
        treasury = _treasury;
        unbondingPeriod = DEFAULT_UNBONDING_PERIOD;
        dailyWithdrawalLimitBps = DEFAULT_DAILY_WITHDRAWAL_BPS;

        // Initialize epoch
        currentEpoch = 1;
        epochStartTime = block.timestamp;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    // ============ External Functions ============

    /**
     * @notice Stake tokens into the contract
     * @param amount Amount of tokens to stake
     * @dev Tokens must be approved before calling
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        // Check slashing cooldown - SEC-008
        StakeInfo storage stakeInfo = stakes[msg.sender];
        if (stakeInfo.lastSlashedAt != 0) {
            if (block.timestamp < stakeInfo.lastSlashedAt + SLASHING_COOLDOWN) {
                revert InSlashingCooldown();
            }
        }

        // Update epoch if needed
        _updateEpoch();

        // Transfer tokens from staker
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update stake info
        if (stakeInfo.amount == 0) {
            stakeInfo.stakedAt = block.timestamp;
        }
        stakeInfo.amount += amount;
        stakeInfo.lastStakeTime = block.timestamp;

        // Update total staked
        totalStaked += amount;

        // Update delegation if delegated
        if (stakeInfo.delegatee != address(0)) {
            stakes[stakeInfo.delegatee].delegatedToMe += amount;
        }

        emit Staked(msg.sender, amount, stakeInfo.amount);
    }

    /**
     * @notice Initiate unbonding of staked tokens - SEC-002
     * @param amount Amount of tokens to unbond
     * @dev Subject to rate limiting and minimum stake duration
     */
    function initiateUnbonding(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        StakeInfo storage stakeInfo = stakes[msg.sender];
        if (stakeInfo.amount < amount) revert InsufficientStake();

        // Check minimum stake duration - SEC-002
        if (block.timestamp < stakeInfo.lastStakeTime + MIN_STAKE_DURATION) {
            revert MinStakeDurationNotMet();
        }

        // Check rate limit - SEC-011
        _checkAndUpdateRateLimit(msg.sender);

        // Update epoch if needed
        _updateEpoch();

        // Check daily withdrawal limit - SEC-002
        uint256 today = block.timestamp / 1 days;
        uint256 projectedDailyTotal = dailyWithdrawals[today] + amount;
        uint256 maxDailyWithdrawal = (totalStaked * dailyWithdrawalLimitBps) / BPS_DENOMINATOR;

        if (projectedDailyTotal > maxDailyWithdrawal) {
            revert DailyWithdrawalLimitExceeded();
        }

        // Update daily withdrawal tracking
        dailyWithdrawals[today] = projectedDailyTotal;

        // Reduce staked amount
        stakeInfo.amount -= amount;
        totalStaked -= amount;
        totalUnbonding += amount;

        // Update delegation if delegated
        if (stakeInfo.delegatee != address(0)) {
            stakes[stakeInfo.delegatee].delegatedToMe -= amount;
        }

        // Determine if early exit penalty applies - SEC-002
        bool earlyExit = block.timestamp < stakeInfo.stakedAt + unbondingPeriod;

        // Create unbonding request
        uint256 completionTime = block.timestamp + unbondingPeriod;
        uint256 requestIndex = unbondingRequests[msg.sender].length;

        unbondingRequests[msg.sender].push(
            UnbondingRequest({
                amount: amount,
                initiatedAt: block.timestamp,
                completionTime: completionTime,
                epoch: currentEpoch,
                processed: false,
                penaltyApplied: earlyExit
            })
        );

        emit UnbondingInitiated(msg.sender, amount, completionTime, requestIndex, currentEpoch);

        if (earlyExit) {
            uint256 penalty = (amount * EARLY_EXIT_PENALTY_BPS) / BPS_DENOMINATOR;
            emit EarlyExitPenaltyApplied(msg.sender, penalty, requestIndex);
        }
    }

    /**
     * @notice Complete unbonding and withdraw tokens - SEC-002, SEC-013
     * @param requestIndex Index of the unbonding request to complete
     */
    function completeUnbonding(uint256 requestIndex) external nonReentrant whenNotPaused {
        if (requestIndex >= unbondingRequests[msg.sender].length) {
            revert InvalidRequestIndex();
        }

        UnbondingRequest storage request = unbondingRequests[msg.sender][requestIndex];

        if (request.processed) revert RequestAlreadyProcessed();
        if (block.timestamp < request.completionTime) revert UnbondingNotComplete();

        // Update epoch if needed
        _updateEpoch();

        // Mark as processed
        request.processed = true;

        uint256 withdrawAmount = request.amount;
        uint256 penaltyAmount = 0;

        // Apply early exit penalty if applicable - SEC-002
        if (request.penaltyApplied) {
            penaltyAmount = (withdrawAmount * EARLY_EXIT_PENALTY_BPS) / BPS_DENOMINATOR;
            withdrawAmount -= penaltyAmount;

            // Send penalty to treasury
            stakingToken.safeTransfer(treasury, penaltyAmount);
        }

        // Update totals
        totalUnbonding -= request.amount;

        // Transfer tokens to staker
        stakingToken.safeTransfer(msg.sender, withdrawAmount);

        emit UnbondingCompleted(msg.sender, withdrawAmount, requestIndex, penaltyAmount);
    }

    /**
     * @notice Cancel a pending unbonding request and restake
     * @param requestIndex Index of the unbonding request to cancel
     */
    function cancelUnbonding(uint256 requestIndex) external nonReentrant whenNotPaused {
        if (requestIndex >= unbondingRequests[msg.sender].length) {
            revert InvalidRequestIndex();
        }

        UnbondingRequest storage request = unbondingRequests[msg.sender][requestIndex];

        if (request.processed) revert RequestAlreadyProcessed();

        // Check slashing cooldown - SEC-008
        StakeInfo storage stakeInfo = stakes[msg.sender];
        if (stakeInfo.lastSlashedAt != 0) {
            if (block.timestamp < stakeInfo.lastSlashedAt + SLASHING_COOLDOWN) {
                revert InSlashingCooldown();
            }
        }

        // Mark as processed (cancelled)
        request.processed = true;

        // Restore stake
        uint256 amount = request.amount;
        stakeInfo.amount += amount;
        totalStaked += amount;
        totalUnbonding -= amount;

        // Update delegation if delegated
        if (stakeInfo.delegatee != address(0)) {
            stakes[stakeInfo.delegatee].delegatedToMe += amount;
        }

        emit Staked(msg.sender, amount, stakeInfo.amount);
    }

    /**
     * @notice Delegate stake to another address
     * @param delegatee Address to delegate to (address(0) to remove delegation)
     */
    function delegate(address delegatee) external nonReentrant whenNotPaused {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (delegatee == msg.sender) revert CannotDelegateToSelf();

        address oldDelegatee = stakeInfo.delegatee;

        // Remove from old delegatee
        if (oldDelegatee != address(0)) {
            stakes[oldDelegatee].delegatedToMe -= stakeInfo.amount;
        }

        // Add to new delegatee
        if (delegatee != address(0)) {
            stakes[delegatee].delegatedToMe += stakeInfo.amount;
        }

        stakeInfo.delegatee = delegatee;

        emit DelegationChanged(msg.sender, oldDelegatee, delegatee, stakeInfo.amount);
    }

    /**
     * @notice Slash a staker\'s tokens - SEC-008
     * @param staker Address to slash
     * @param bps Basis points to slash (max 5000 = 50%)
     * @param reason Reason for slashing
     * @dev Only callable by SLASHER_ROLE
     */
    function slash(address staker, uint256 bps, string calldata reason) external nonReentrant onlyRole(SLASHER_ROLE) {
        if (staker == address(0)) revert ZeroAddress();
        if (bps == 0) revert ZeroAmount();
        if (bps > MAX_SLASH_BPS) revert SlashAmountExceedsMax();

        StakeInfo storage stakeInfo = stakes[staker];

        // Check minimum stake threshold - SEC-008
        if (stakeInfo.amount < MIN_STAKE_FOR_SLASHING) {
            revert StakeBelowSlashingThreshold();
        }

        // Calculate proportional slash amount - SEC-008
        uint256 slashAmount = (stakeInfo.amount * bps) / BPS_DENOMINATOR;

        // Update stake info
        stakeInfo.amount -= slashAmount;
        stakeInfo.lastSlashedAt = block.timestamp;
        stakeInfo.totalSlashed += slashAmount;

        // Update totals
        totalStaked -= slashAmount;

        // Update delegation if delegated
        if (stakeInfo.delegatee != address(0)) {
            stakes[stakeInfo.delegatee].delegatedToMe -= slashAmount;
        }

        // Transfer slashed tokens to treasury
        stakingToken.safeTransfer(treasury, slashAmount);

        emit Slashed(staker, slashAmount, reason, msg.sender);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the unbonding period
     * @param newPeriod New unbonding period in seconds
     * @dev Only callable by ADMIN_ROLE
     */
    function setUnbondingPeriod(uint256 newPeriod) external onlyRole(ADMIN_ROLE) {
        if (newPeriod < 1 days || newPeriod > 30 days) {
            revert InvalidUnbondingPeriod();
        }

        uint256 oldPeriod = unbondingPeriod;
        unbondingPeriod = newPeriod;

        emit UnbondingPeriodUpdated(oldPeriod, newPeriod);
    }

    /**
     * @notice Update the daily withdrawal limit - SEC-002
     * @param newLimitBps New daily withdrawal limit in basis points (100 = 1%, 1000 = 10%, etc.)
     * @dev Only callable by ADMIN_ROLE. Must be between MIN_DAILY_WITHDRAWAL_BPS and MAX_CONFIGURABLE_DAILY_BPS
     */
    function setDailyWithdrawalLimit(uint256 newLimitBps) external onlyRole(ADMIN_ROLE) {
        if (newLimitBps < MIN_DAILY_WITHDRAWAL_BPS || newLimitBps > MAX_CONFIGURABLE_DAILY_BPS) {
            revert InvalidDailyWithdrawalLimit();
        }

        uint256 oldLimit = dailyWithdrawalLimitBps;
        dailyWithdrawalLimitBps = newLimitBps;

        emit DailyWithdrawalLimitUpdated(oldLimit, newLimitBps);
    }

    /**
     * @notice Update the treasury address
     * @param newTreasury New treasury address
     * @dev Only callable by ADMIN_ROLE
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();

        address oldTreasury = treasury;
        treasury = newTreasury;

        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Pause the contract
     * @dev Only callable by ADMIN_ROLE
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Only callable by ADMIN_ROLE
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Force advance to new epoch (for emergency use)
     * @dev Only callable by ADMIN_ROLE
     */
    function forceNewEpoch() external onlyRole(ADMIN_ROLE) {
        _advanceEpoch();
    }

    // ============ View Functions ============

    /**
     * @notice Get stake info for an address
     * @param staker Address to query
     * @return amount Current staked amount
     * @return stakedAt Initial stake timestamp
     * @return delegatee Current delegatee
     * @return delegatedToMe Amount delegated to this address
     * @return lastSlashedAt Last slash timestamp
     * @return totalSlashed Total amount ever slashed
     */
    function getStakeInfo(address staker)
        external
        view
        returns (
            uint256 amount,
            uint256 stakedAt,
            address delegatee,
            uint256 delegatedToMe,
            uint256 lastSlashedAt,
            uint256 totalSlashed
        )
    {
        StakeInfo storage info = stakes[staker];
        return (info.amount, info.stakedAt, info.delegatee, info.delegatedToMe, info.lastSlashedAt, info.totalSlashed);
    }

    /**
     * @notice Get effective voting power for an address
     * @param account Address to query
     * @return Total voting power (own stake + delegated)
     */
    function getVotingPower(address account) external view returns (uint256) {
        StakeInfo storage info = stakes[account];

        // If this account has delegated to someone else, they have no voting power
        if (info.delegatee != address(0)) {
            return info.delegatedToMe; // Only delegated-to-me power
        }

        // Own stake + delegated to this account
        return info.amount + info.delegatedToMe;
    }

    /**
     * @notice Get number of unbonding requests for a staker
     * @param staker Address to query
     * @return Number of unbonding requests
     */
    function getUnbondingRequestCount(address staker) external view returns (uint256) {
        return unbondingRequests[staker].length;
    }

    /**
     * @notice Get unbonding request details
     * @param staker Address of the staker
     * @param requestIndex Index of the request
     * @return amount Amount being unbonded
     * @return initiatedAt When unbonding started
     * @return completionTime When unbonding completes
     * @return epoch Epoch when request was made
     * @return processed Whether request is processed
     * @return penaltyApplied Whether early exit penalty applies
     */
    function getUnbondingRequest(
        address staker,
        uint256 requestIndex
    )
        external
        view
        returns (
            uint256 amount,
            uint256 initiatedAt,
            uint256 completionTime,
            uint256 epoch,
            bool processed,
            bool penaltyApplied
        )
    {
        if (requestIndex >= unbondingRequests[staker].length) {
            revert InvalidRequestIndex();
        }

        UnbondingRequest storage request = unbondingRequests[staker][requestIndex];
        return (
            request.amount,
            request.initiatedAt,
            request.completionTime,
            request.epoch,
            request.processed,
            request.penaltyApplied
        );
    }

    /**
     * @notice Get pending unbonding amount for a staker
     * @param staker Address to query
     * @return Total amount in pending unbonding requests
     */
    function getPendingUnbonding(address staker) external view returns (uint256) {
        uint256 pending = 0;
        UnbondingRequest[] storage requests = unbondingRequests[staker];

        for (uint256 i = 0; i < requests.length; i++) {
            if (!requests[i].processed) {
                pending += requests[i].amount;
            }
        }

        return pending;
    }

    /**
     * @notice Get withdrawable unbonding amount for a staker
     * @param staker Address to query
     * @return Total amount ready to withdraw
     */
    function getWithdrawableUnbonding(address staker) external view returns (uint256) {
        uint256 withdrawable = 0;
        UnbondingRequest[] storage requests = unbondingRequests[staker];

        for (uint256 i = 0; i < requests.length; i++) {
            if (!requests[i].processed && block.timestamp >= requests[i].completionTime) {
                withdrawable += requests[i].amount;
            }
        }

        return withdrawable;
    }

    /**
     * @notice Check remaining daily withdrawal capacity - SEC-002
     * @return Remaining amount that can be withdrawn today
     */
    function getRemainingDailyWithdrawal() external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        uint256 maxDaily = (totalStaked * dailyWithdrawalLimitBps) / BPS_DENOMINATOR;
        uint256 usedToday = dailyWithdrawals[today];

        if (usedToday >= maxDaily) {
            return 0;
        }

        return maxDaily - usedToday;
    }

    /**
     * @notice Check if address can unstake (rate limit) - SEC-011
     * @param staker Address to check
     * @return canUnstake Whether staker can initiate unbonding
     * @return remainingOps Remaining operations in current window
     */
    function canInitiateUnbonding(address staker) external view returns (bool canUnstake, uint256 remainingOps) {
        RateLimitInfo storage rateLimit = rateLimits[staker];

        // Check if we\'re in a new window
        if (block.timestamp >= rateLimit.windowStart + RATE_LIMIT_WINDOW) {
            return (true, MAX_UNSTAKE_OPS_PER_WINDOW);
        }

        if (rateLimit.operationsCount >= MAX_UNSTAKE_OPS_PER_WINDOW) {
            return (false, 0);
        }

        return (true, MAX_UNSTAKE_OPS_PER_WINDOW - rateLimit.operationsCount);
    }

    /**
     * @notice Check if staker is in slashing cooldown - SEC-008
     * @param staker Address to check
     * @return inCooldown Whether staker is in cooldown
     * @return cooldownEnds When cooldown ends (0 if not in cooldown)
     */
    function isInSlashingCooldown(address staker) external view returns (bool inCooldown, uint256 cooldownEnds) {
        StakeInfo storage info = stakes[staker];

        if (info.lastSlashedAt == 0) {
            return (false, 0);
        }

        uint256 cooldownEnd = info.lastSlashedAt + SLASHING_COOLDOWN;

        if (block.timestamp < cooldownEnd) {
            return (true, cooldownEnd);
        }

        return (false, 0);
    }

    /**
     * @notice Get current epoch info - SEC-002
     * @return epochNumber Current epoch number
     * @return startTime When current epoch started
     * @return timeUntilNextEpoch Seconds until next epoch
     */
    function getEpochInfo() external view returns (uint256 epochNumber, uint256 startTime, uint256 timeUntilNextEpoch) {
        uint256 nextEpochStart = epochStartTime + EPOCH_DURATION;
        uint256 timeRemaining = 0;

        if (block.timestamp < nextEpochStart) {
            timeRemaining = nextEpochStart - block.timestamp;
        }

        return (currentEpoch, epochStartTime, timeRemaining);
    }

    // ============ Internal Functions ============

    /**
     * @notice Update epoch if duration has passed - SEC-002
     */
    function _updateEpoch() internal {
        if (block.timestamp >= epochStartTime + EPOCH_DURATION) {
            _advanceEpoch();
        }
    }

    /**
     * @notice Advance to next epoch - SEC-002
     */
    function _advanceEpoch() internal {
        currentEpoch += 1;
        epochStartTime = block.timestamp;

        emit NewEpoch(currentEpoch, epochStartTime);
    }

    /**
     * @notice Check and update rate limit for unstaking - SEC-011
     * @param staker Address to check
     */
    function _checkAndUpdateRateLimit(address staker) internal {
        RateLimitInfo storage rateLimit = rateLimits[staker];

        // Check if we\'re in a new window
        if (block.timestamp >= rateLimit.windowStart + RATE_LIMIT_WINDOW) {
            // Reset window
            rateLimit.windowStart = block.timestamp;
            rateLimit.operationsCount = 1;
        } else {
            // Check limit
            if (rateLimit.operationsCount >= MAX_UNSTAKE_OPS_PER_WINDOW) {
                emit RateLimitExceeded(staker, rateLimit.windowStart, rateLimit.operationsCount);
                revert RateLimitExceeded_Error();
            }
            rateLimit.operationsCount += 1;
        }
    }
}
