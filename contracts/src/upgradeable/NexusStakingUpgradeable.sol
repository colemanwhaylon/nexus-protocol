// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NexusStakingUpgradeable
 * @notice UUPS upgradeable version of NexusStaking
 * @dev Staking contract with delegation, slashing, and unbonding
 */
contract NexusStakingUpgradeable is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardTime;
        address delegatedTo;
        uint256 slashedAmount;
        bool isActive;
    }

    struct UnbondingRequest {
        uint256 amount;
        uint256 requestTime;
        uint256 completionTime;
        uint256 epoch;
        bool processed;
        bool slashed;
    }

    IERC20 public stakingToken;
    address public treasury;

    uint256 public totalStaked;
    uint256 public totalUnbonding;
    uint256 public currentEpoch;

    uint256 public minStakeDuration;
    uint256 public unbondingPeriod;
    uint256 public dailyWithdrawalLimitBps;
    uint256 public slashingCooldown;

    mapping(address => StakeInfo) public stakes;
    mapping(address => UnbondingRequest[]) public unbondingRequests;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) public lastUnbondingTime;
    mapping(address => uint256) public dailyWithdrawn;
    mapping(address => uint256) public lastWithdrawalDay;
    mapping(address => uint256) public slashingCooldownEnd;

    event Staked(address indexed user, uint256 amount);
    event UnbondingInitiated(address indexed user, uint256 amount, uint256 completionTime);
    event UnbondingCompleted(address indexed user, uint256 amount);
    event Slashed(address indexed user, uint256 amount, string reason);
    event DelegationChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event EpochAdvanced(uint256 newEpoch);

    error InsufficientStake();
    error UnbondingPeriodNotComplete();
    error DailyWithdrawalLimitExceeded();
    error InSlashingCooldown();
    error MinStakeDurationNotMet();
    error RateLimitExceeded();
    error InvalidAmount();
    error RequestAlreadyProcessed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     */
    function initialize(address _stakingToken, address _treasury, address _admin) public initializer {
        __AccessControl_init();
        __Pausable_init();

        stakingToken = IERC20(_stakingToken);
        treasury = _treasury;
        currentEpoch = 1;

        minStakeDuration = 24 hours;
        unbondingPeriod = 7 days;
        dailyWithdrawalLimitBps = 1000; // 10%
        slashingCooldown = 7 days;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SLASHER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }

    /**
     * @notice Stake tokens
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (slashingCooldownEnd[msg.sender] > block.timestamp) {
            revert InSlashingCooldown();
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (!stakeInfo.isActive) {
            stakeInfo.startTime = block.timestamp;
            stakeInfo.isActive = true;
        }

        stakeInfo.amount += amount;
        stakeInfo.lastRewardTime = block.timestamp;
        totalStaked += amount;

        // Update voting power
        address delegate = stakeInfo.delegatedTo == address(0) ? msg.sender : stakeInfo.delegatedTo;
        votingPower[delegate] += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Initiate unbonding
     */
    function initiateUnbonding(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (amount == 0 || amount > stakeInfo.amount) revert InsufficientStake();
        if (block.timestamp < stakeInfo.startTime + minStakeDuration) {
            revert MinStakeDurationNotMet();
        }

        // Rate limiting
        if (block.timestamp < lastUnbondingTime[msg.sender] + 1 hours) {
            revert RateLimitExceeded();
        }

        // Daily withdrawal limit
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay != lastWithdrawalDay[msg.sender]) {
            dailyWithdrawn[msg.sender] = 0;
            lastWithdrawalDay[msg.sender] = currentDay;
        }

        uint256 dailyLimit = (totalStaked * dailyWithdrawalLimitBps) / 10_000;
        if (dailyWithdrawn[msg.sender] + amount > dailyLimit) {
            revert DailyWithdrawalLimitExceeded();
        }

        stakeInfo.amount -= amount;
        totalStaked -= amount;
        totalUnbonding += amount;
        dailyWithdrawn[msg.sender] += amount;
        lastUnbondingTime[msg.sender] = block.timestamp;

        // Update voting power
        address delegate = stakeInfo.delegatedTo == address(0) ? msg.sender : stakeInfo.delegatedTo;
        if (votingPower[delegate] >= amount) {
            votingPower[delegate] -= amount;
        }

        uint256 completionTime = block.timestamp + unbondingPeriod;
        unbondingRequests[msg.sender].push(
            UnbondingRequest({
                amount: amount,
                requestTime: block.timestamp,
                completionTime: completionTime,
                epoch: currentEpoch,
                processed: false,
                slashed: false
            })
        );

        emit UnbondingInitiated(msg.sender, amount, completionTime);
    }

    /**
     * @notice Complete unbonding
     */
    function completeUnbonding(uint256 requestIndex) external nonReentrant {
        UnbondingRequest[] storage requests = unbondingRequests[msg.sender];
        require(requestIndex < requests.length, "Invalid index");

        UnbondingRequest storage request = requests[requestIndex];
        if (request.processed) revert RequestAlreadyProcessed();
        if (block.timestamp < request.completionTime) revert UnbondingPeriodNotComplete();

        request.processed = true;
        totalUnbonding -= request.amount;

        uint256 amount = request.slashed ? 0 : request.amount;
        if (amount > 0) {
            stakingToken.safeTransfer(msg.sender, amount);
        }

        emit UnbondingCompleted(msg.sender, amount);
    }

    /**
     * @notice Slash a staker
     */
    function slash(address staker, uint256 bps, string calldata reason) external onlyRole(SLASHER_ROLE) {
        require(bps <= 5000, "Max 50% slash");

        StakeInfo storage stakeInfo = stakes[staker];
        uint256 slashAmount = (stakeInfo.amount * bps) / 10_000;

        if (slashAmount > 0) {
            stakeInfo.amount -= slashAmount;
            stakeInfo.slashedAmount += slashAmount;
            totalStaked -= slashAmount;

            // Update voting power
            address delegate = stakeInfo.delegatedTo == address(0) ? staker : stakeInfo.delegatedTo;
            if (votingPower[delegate] >= slashAmount) {
                votingPower[delegate] -= slashAmount;
            }

            stakingToken.safeTransfer(treasury, slashAmount);
            slashingCooldownEnd[staker] = block.timestamp + slashingCooldown;

            emit Slashed(staker, slashAmount, reason);
        }
    }

    /**
     * @notice Delegate voting power
     */
    function delegate(address delegatee) external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        address currentDelegate = stakeInfo.delegatedTo == address(0) ? msg.sender : stakeInfo.delegatedTo;
        address newDelegate = delegatee == address(0) ? msg.sender : delegatee;

        if (currentDelegate != newDelegate) {
            if (votingPower[currentDelegate] >= stakeInfo.amount) {
                votingPower[currentDelegate] -= stakeInfo.amount;
            }
            votingPower[newDelegate] += stakeInfo.amount;
            stakeInfo.delegatedTo = delegatee;

            emit DelegationChanged(msg.sender, currentDelegate, newDelegate);
        }
    }

    /**
     * @notice Advance epoch
     */
    function advanceEpoch() external onlyRole(DEFAULT_ADMIN_ROLE) {
        currentEpoch++;
        emit EpochAdvanced(currentEpoch);
    }

    // View functions

    function getStakeInfo(address staker)
        external
        view
        returns (
            uint256 amount,
            uint256 startTime,
            uint256 lastRewardTime,
            address delegatedTo,
            uint256 slashedAmount,
            bool isActive
        )
    {
        StakeInfo storage info = stakes[staker];
        return (info.amount, info.startTime, info.lastRewardTime, info.delegatedTo, info.slashedAmount, info.isActive);
    }

    function getUnbondingRequestCount(address staker) external view returns (uint256) {
        return unbondingRequests[staker].length;
    }

    function getUnbondingRequest(
        address staker,
        uint256 index
    )
        external
        view
        returns (
            uint256 amount,
            uint256 requestTime,
            uint256 completionTime,
            uint256 epoch,
            bool processed,
            bool slashed
        )
    {
        UnbondingRequest storage req = unbondingRequests[staker][index];
        return (req.amount, req.requestTime, req.completionTime, req.epoch, req.processed, req.slashed);
    }

    function isInSlashingCooldown(address staker) external view returns (bool inCooldown, uint256 endsAt) {
        endsAt = slashingCooldownEnd[staker];
        inCooldown = block.timestamp < endsAt;
    }

    function canInitiateUnbonding(address staker) external view returns (bool canUnstake, string memory reason) {
        if (block.timestamp < lastUnbondingTime[staker] + 1 hours) {
            return (false, "Rate limited");
        }
        return (true, "");
    }

    // Admin functions

    function setDailyWithdrawalLimit(uint256 _bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_bps <= 10_000, "Invalid bps");
        dailyWithdrawalLimitBps = _bps;
    }

    function setUnbondingPeriod(uint256 _period) external onlyRole(DEFAULT_ADMIN_ROLE) {
        unbondingPeriod = _period;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
