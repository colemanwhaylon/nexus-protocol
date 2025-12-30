// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title VestingContract
 * @author Nexus Protocol Team
 * @notice Production-grade token vesting with linear and cliff schedules
 * @dev Implements comprehensive vesting with security features
 *
 * Security Features (per SECURITY_REVIEW_BEFORE.md):
 * - SEC-007: Vesting calculation rounding (round DOWN for beneficiary claims)
 * - SEC-013: Comprehensive event emissions for all state changes
 * - Revocable grants with proper fund handling
 * - Multi-beneficiary support with isolated schedules
 *
 * Features:
 * - Linear vesting with optional cliff period
 * - Revocable and non-revocable grants
 * - Multi-token support
 * - Beneficiary-controlled claiming
 * - Admin grant management
 */
contract VestingContract is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ============ Constants ============

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role identifier for grant managers
    bytes32 public constant GRANT_MANAGER_ROLE = keccak256("GRANT_MANAGER_ROLE");

    /// @notice Minimum vesting duration (30 days)
    uint256 public constant MIN_VESTING_DURATION = 30 days;

    /// @notice Maximum vesting duration (10 years)
    uint256 public constant MAX_VESTING_DURATION = 3650 days;

    /// @notice Maximum cliff duration (2 years)
    uint256 public constant MAX_CLIFF_DURATION = 730 days;

    /// @notice Precision multiplier for calculations
    uint256 public constant PRECISION = 1e18;

    // ============ Enums ============

    /// @notice Grant status enum
    enum GrantStatus {
        Active, // Grant is active and vesting
        Revoked, // Grant was revoked
        Completed // Grant fully vested and claimed
    }

    // ============ Structs ============

    /**
     * @notice Vesting grant configuration
     * @param beneficiary Address receiving the tokens
     * @param token Token being vested
     * @param totalAmount Total amount to be vested
     * @param claimedAmount Amount already claimed
     * @param startTime When vesting begins
     * @param cliffDuration Cliff period before any tokens vest
     * @param vestingDuration Total vesting duration (including cliff)
     * @param revocable Whether the grant can be revoked
     * @param status Current grant status
     */
    struct VestingGrant {
        address beneficiary;
        IERC20 token;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        GrantStatus status;
    }

    /**
     * @notice Vesting schedule template
     * @param cliffDuration Cliff period
     * @param vestingDuration Total duration
     * @param revocable Whether grants using this schedule are revocable
     * @param name Schedule name
     */
    struct VestingSchedule {
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        string name;
    }

    // ============ State Variables ============

    /// @notice Counter for grant IDs
    uint256 public nextGrantId;

    /// @notice Counter for schedule IDs
    uint256 public nextScheduleId;

    /// @notice Treasury address for revoked funds
    address public treasury;

    /// @notice Mapping of grant ID to grant
    mapping(uint256 => VestingGrant) public grants;

    /// @notice Mapping of schedule ID to schedule
    mapping(uint256 => VestingSchedule) public schedules;

    /// @notice Mapping of beneficiary => array of grant IDs
    mapping(address => uint256[]) public beneficiaryGrants;

    /// @notice Mapping of token => total amount locked in active grants
    mapping(address => uint256) public totalLockedByToken;

    /// @notice Set of active grant IDs
    uint256[] public activeGrants;

    // ============ Events - SEC-013 ============

    /// @notice Emitted when a vesting grant is created
    event GrantCreated(
        uint256 indexed grantId,
        address indexed beneficiary,
        address indexed token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    /// @notice Emitted when tokens are claimed
    event TokensClaimed(uint256 indexed grantId, address indexed beneficiary, uint256 amount, uint256 totalClaimed);

    /// @notice Emitted when a grant is revoked
    event GrantRevoked(
        uint256 indexed grantId,
        address indexed beneficiary,
        uint256 vestedAmount,
        uint256 unvestedAmount,
        address revokedBy
    );

    /// @notice Emitted when a grant is completed
    event GrantCompleted(uint256 indexed grantId, address indexed beneficiary, uint256 totalAmount);

    /// @notice Emitted when a vesting schedule is created
    event ScheduleCreated(
        uint256 indexed scheduleId, string name, uint256 cliffDuration, uint256 vestingDuration, bool revocable
    );

    /// @notice Emitted when treasury is updated
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when beneficiary is changed
    event BeneficiaryChanged(uint256 indexed grantId, address indexed oldBeneficiary, address indexed newBeneficiary);

    // ============ Errors ============

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when grant does not exist
    error GrantNotFound();

    /// @notice Thrown when grant is not active
    error GrantNotActive();

    /// @notice Thrown when grant is not revocable
    error GrantNotRevocable();

    /// @notice Thrown when nothing to claim
    error NothingToClaim();

    /// @notice Thrown when cliff has not passed
    error CliffNotReached();

    /// @notice Thrown when duration is invalid
    error InvalidDuration();

    /// @notice Thrown when caller is not beneficiary
    error NotBeneficiary();

    /// @notice Thrown when start time is in the past
    error InvalidStartTime();

    /// @notice Thrown when schedule does not exist
    error ScheduleNotFound();

    /// @notice Thrown when insufficient token balance
    error InsufficientBalance();

    // ============ Constructor ============

    /**
     * @notice Initializes the VestingContract
     * @param _treasury Address to receive revoked funds
     * @param _admin Address to receive admin role
     */
    constructor(address _treasury, address _admin) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();

        treasury = _treasury;
        nextGrantId = 1;
        nextScheduleId = 1;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(GRANT_MANAGER_ROLE, _admin);

        // Create default schedules
        _createSchedule(0, 365 days, true, "1 Year Linear");
        _createSchedule(180 days, 730 days, true, "2 Year with 6 Month Cliff");
        _createSchedule(365 days, 1460 days, true, "4 Year with 1 Year Cliff");
        _createSchedule(0, 180 days, false, "6 Month Non-Revocable");
    }

    // ============ Grant Creation Functions ============

    /**
     * @notice Create a new vesting grant
     * @param beneficiary Address to receive vested tokens
     * @param token Token to vest
     * @param totalAmount Total amount to vest
     * @param startTime When vesting starts
     * @param cliffDuration Cliff period before tokens vest
     * @param vestingDuration Total vesting duration
     * @param revocable Whether grant can be revoked
     * @return grantId The ID of the created grant
     */
    function createGrant(
        address beneficiary,
        address token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    )
        external
        nonReentrant
        onlyRole(GRANT_MANAGER_ROLE)
        returns (uint256 grantId)
    {
        // Validate inputs
        if (beneficiary == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (totalAmount == 0) revert ZeroAmount();
        if (startTime < block.timestamp) revert InvalidStartTime();
        if (vestingDuration < MIN_VESTING_DURATION || vestingDuration > MAX_VESTING_DURATION) {
            revert InvalidDuration();
        }
        if (cliffDuration > MAX_CLIFF_DURATION) revert InvalidDuration();
        if (cliffDuration >= vestingDuration) revert InvalidDuration();

        grantId = nextGrantId++;

        grants[grantId] = VestingGrant({
            beneficiary: beneficiary,
            token: IERC20(token),
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            status: GrantStatus.Active
        });

        beneficiaryGrants[beneficiary].push(grantId);
        activeGrants.push(grantId);
        totalLockedByToken[token] += totalAmount;

        // Transfer tokens to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);

        emit GrantCreated(
            grantId, beneficiary, token, totalAmount, startTime, cliffDuration, vestingDuration, revocable
        );
    }

    /**
     * @notice Create a grant using a predefined schedule
     * @param beneficiary Address to receive vested tokens
     * @param token Token to vest
     * @param totalAmount Total amount to vest
     * @param startTime When vesting starts
     * @param scheduleId ID of the schedule to use
     * @return grantId The ID of the created grant
     */
    function createGrantFromSchedule(
        address beneficiary,
        address token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 scheduleId
    )
        external
        nonReentrant
        onlyRole(GRANT_MANAGER_ROLE)
        returns (uint256 grantId)
    {
        VestingSchedule storage schedule = schedules[scheduleId];
        if (schedule.vestingDuration == 0) revert ScheduleNotFound();

        // Validate inputs
        if (beneficiary == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (totalAmount == 0) revert ZeroAmount();
        if (startTime < block.timestamp) revert InvalidStartTime();

        grantId = nextGrantId++;

        grants[grantId] = VestingGrant({
            beneficiary: beneficiary,
            token: IERC20(token),
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: startTime,
            cliffDuration: schedule.cliffDuration,
            vestingDuration: schedule.vestingDuration,
            revocable: schedule.revocable,
            status: GrantStatus.Active
        });

        beneficiaryGrants[beneficiary].push(grantId);
        activeGrants.push(grantId);
        totalLockedByToken[token] += totalAmount;

        // Transfer tokens to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);

        emit GrantCreated(
            grantId,
            beneficiary,
            token,
            totalAmount,
            startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.revocable
        );
    }

    /**
     * @notice Create multiple grants in a batch
     * @param beneficiaries Array of beneficiary addresses
     * @param token Token to vest
     * @param amounts Array of amounts
     * @param startTime When vesting starts
     * @param scheduleId ID of the schedule to use
     * @return grantIds Array of created grant IDs
     */
    function createGrantsBatch(
        address[] calldata beneficiaries,
        address token,
        uint256[] calldata amounts,
        uint256 startTime,
        uint256 scheduleId
    )
        external
        nonReentrant
        onlyRole(GRANT_MANAGER_ROLE)
        returns (uint256[] memory grantIds)
    {
        if (beneficiaries.length != amounts.length) revert ZeroAmount();

        VestingSchedule storage schedule = schedules[scheduleId];
        if (schedule.vestingDuration == 0) revert ScheduleNotFound();
        if (token == address(0)) revert ZeroAddress();
        if (startTime < block.timestamp) revert InvalidStartTime();

        grantIds = new uint256[](beneficiaries.length);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();

            uint256 grantId = nextGrantId++;
            grantIds[i] = grantId;

            grants[grantId] = VestingGrant({
                beneficiary: beneficiaries[i],
                token: IERC20(token),
                totalAmount: amounts[i],
                claimedAmount: 0,
                startTime: startTime,
                cliffDuration: schedule.cliffDuration,
                vestingDuration: schedule.vestingDuration,
                revocable: schedule.revocable,
                status: GrantStatus.Active
            });

            beneficiaryGrants[beneficiaries[i]].push(grantId);
            activeGrants.push(grantId);
            totalAmount += amounts[i];

            emit GrantCreated(
                grantId,
                beneficiaries[i],
                token,
                amounts[i],
                startTime,
                schedule.cliffDuration,
                schedule.vestingDuration,
                schedule.revocable
            );
        }

        totalLockedByToken[token] += totalAmount;

        // Transfer all tokens at once
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);
    }

    // ============ Claiming Functions ============

    /**
     * @notice Claim vested tokens from a grant
     * @param grantId Grant ID to claim from
     * @return claimed Amount of tokens claimed
     */
    function claim(uint256 grantId) external nonReentrant whenNotPaused returns (uint256 claimed) {
        VestingGrant storage grant = grants[grantId];
        if (grant.totalAmount == 0) revert GrantNotFound();
        if (grant.status != GrantStatus.Active) revert GrantNotActive();
        if (grant.beneficiary != msg.sender) revert NotBeneficiary();

        // Check cliff
        uint256 cliffEnd = grant.startTime + grant.cliffDuration;
        if (block.timestamp < cliffEnd) revert CliffNotReached();

        // Calculate claimable amount
        claimed = _calculateVested(grantId) - grant.claimedAmount;
        if (claimed == 0) revert NothingToClaim();

        // Update state
        grant.claimedAmount += claimed;
        totalLockedByToken[address(grant.token)] -= claimed;

        // Check if grant is complete
        if (grant.claimedAmount >= grant.totalAmount) {
            grant.status = GrantStatus.Completed;
            emit GrantCompleted(grantId, grant.beneficiary, grant.totalAmount);
        }

        // Transfer tokens
        grant.token.safeTransfer(msg.sender, claimed);

        emit TokensClaimed(grantId, msg.sender, claimed, grant.claimedAmount);
    }

    /**
     * @notice Claim from all active grants for the caller
     * @return totalClaimed Total amount claimed across all grants
     */
    function claimAll() external nonReentrant whenNotPaused returns (uint256 totalClaimed) {
        uint256[] storage grantIds = beneficiaryGrants[msg.sender];

        for (uint256 i = 0; i < grantIds.length; i++) {
            VestingGrant storage grant = grants[grantIds[i]];

            if (grant.status != GrantStatus.Active) continue;

            uint256 cliffEnd = grant.startTime + grant.cliffDuration;
            if (block.timestamp < cliffEnd) continue;

            uint256 vested = _calculateVested(grantIds[i]);
            uint256 claimable = vested - grant.claimedAmount;

            if (claimable > 0) {
                grant.claimedAmount += claimable;
                totalLockedByToken[address(grant.token)] -= claimable;
                totalClaimed += claimable;

                if (grant.claimedAmount >= grant.totalAmount) {
                    grant.status = GrantStatus.Completed;
                    emit GrantCompleted(grantIds[i], grant.beneficiary, grant.totalAmount);
                }

                grant.token.safeTransfer(msg.sender, claimable);

                emit TokensClaimed(grantIds[i], msg.sender, claimable, grant.claimedAmount);
            }
        }

        if (totalClaimed == 0) revert NothingToClaim();
    }

    // ============ Grant Management Functions ============

    /**
     * @notice Revoke a grant
     * @param grantId Grant ID to revoke
     */
    function revokeGrant(uint256 grantId) external nonReentrant onlyRole(ADMIN_ROLE) {
        VestingGrant storage grant = grants[grantId];
        if (grant.totalAmount == 0) revert GrantNotFound();
        if (grant.status != GrantStatus.Active) revert GrantNotActive();
        if (!grant.revocable) revert GrantNotRevocable();

        // Calculate vested amount at revocation
        uint256 vestedAmount = _calculateVested(grantId);
        uint256 claimableAmount = vestedAmount - grant.claimedAmount;
        uint256 unvestedAmount = grant.totalAmount - vestedAmount;

        // Update state
        grant.status = GrantStatus.Revoked;
        totalLockedByToken[address(grant.token)] -= (claimableAmount + unvestedAmount);

        // Transfer claimable to beneficiary
        if (claimableAmount > 0) {
            grant.claimedAmount += claimableAmount;
            grant.token.safeTransfer(grant.beneficiary, claimableAmount);
        }

        // Transfer unvested to treasury
        if (unvestedAmount > 0) {
            grant.token.safeTransfer(treasury, unvestedAmount);
        }

        emit GrantRevoked(grantId, grant.beneficiary, vestedAmount, unvestedAmount, msg.sender);
    }

    /**
     * @notice Change the beneficiary of a grant
     * @param grantId Grant ID
     * @param newBeneficiary New beneficiary address
     */
    function changeBeneficiary(uint256 grantId, address newBeneficiary) external nonReentrant {
        VestingGrant storage grant = grants[grantId];
        if (grant.totalAmount == 0) revert GrantNotFound();
        if (grant.status != GrantStatus.Active) revert GrantNotActive();
        if (grant.beneficiary != msg.sender) revert NotBeneficiary();
        if (newBeneficiary == address(0)) revert ZeroAddress();

        address oldBeneficiary = grant.beneficiary;
        grant.beneficiary = newBeneficiary;

        // Update beneficiary grants mapping
        beneficiaryGrants[newBeneficiary].push(grantId);

        emit BeneficiaryChanged(grantId, oldBeneficiary, newBeneficiary);
    }

    // ============ Schedule Management Functions ============

    /**
     * @notice Create a new vesting schedule
     * @param cliffDuration Cliff period
     * @param vestingDuration Total duration
     * @param revocable Whether grants are revocable
     * @param name Schedule name
     * @return scheduleId The ID of the created schedule
     */
    function createSchedule(
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        string calldata name
    )
        external
        onlyRole(ADMIN_ROLE)
        returns (uint256 scheduleId)
    {
        return _createSchedule(cliffDuration, vestingDuration, revocable, name);
    }

    /**
     * @notice Internal schedule creation
     */
    function _createSchedule(
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        string memory name
    )
        internal
        returns (uint256 scheduleId)
    {
        if (vestingDuration < MIN_VESTING_DURATION || vestingDuration > MAX_VESTING_DURATION) {
            revert InvalidDuration();
        }
        if (cliffDuration > MAX_CLIFF_DURATION) revert InvalidDuration();
        if (cliffDuration >= vestingDuration) revert InvalidDuration();

        scheduleId = nextScheduleId++;

        schedules[scheduleId] = VestingSchedule({
            cliffDuration: cliffDuration, vestingDuration: vestingDuration, revocable: revocable, name: name
        });

        emit ScheduleCreated(scheduleId, name, cliffDuration, vestingDuration, revocable);
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
     * @notice Get vested amount for a grant
     * @param grantId Grant ID
     * @return vested Amount vested so far
     */
    function getVestedAmount(uint256 grantId) external view returns (uint256 vested) {
        return _calculateVested(grantId);
    }

    /**
     * @notice Get claimable amount for a grant
     * @param grantId Grant ID
     * @return claimable Amount currently claimable
     */
    function getClaimableAmount(uint256 grantId) external view returns (uint256 claimable) {
        VestingGrant storage grant = grants[grantId];
        if (grant.status != GrantStatus.Active) return 0;

        uint256 cliffEnd = grant.startTime + grant.cliffDuration;
        if (block.timestamp < cliffEnd) return 0;

        return _calculateVested(grantId) - grant.claimedAmount;
    }

    /**
     * @notice Get unvested amount for a grant
     * @param grantId Grant ID
     * @return unvested Amount not yet vested
     */
    function getUnvestedAmount(uint256 grantId) external view returns (uint256 unvested) {
        VestingGrant storage grant = grants[grantId];
        if (grant.status != GrantStatus.Active) return 0;

        return grant.totalAmount - _calculateVested(grantId);
    }

    /**
     * @notice Get grant details
     * @param grantId Grant ID
     * @return beneficiary Address receiving tokens
     * @return token Token address
     * @return totalAmount Total grant amount
     * @return claimedAmount Amount claimed
     * @return startTime Start timestamp
     * @return cliffEnd Cliff end timestamp
     * @return vestingEnd Vesting end timestamp
     * @return status Grant status
     */
    function getGrant(uint256 grantId)
        external
        view
        returns (
            address beneficiary,
            address token,
            uint256 totalAmount,
            uint256 claimedAmount,
            uint256 startTime,
            uint256 cliffEnd,
            uint256 vestingEnd,
            GrantStatus status
        )
    {
        VestingGrant storage g = grants[grantId];
        return (
            g.beneficiary,
            address(g.token),
            g.totalAmount,
            g.claimedAmount,
            g.startTime,
            g.startTime + g.cliffDuration,
            g.startTime + g.vestingDuration,
            g.status
        );
    }

    /**
     * @notice Get all grant IDs for a beneficiary
     * @param beneficiary Beneficiary address
     * @return grantIds Array of grant IDs
     */
    function getBeneficiaryGrants(address beneficiary) external view returns (uint256[] memory grantIds) {
        return beneficiaryGrants[beneficiary];
    }

    /**
     * @notice Get total claimable across all grants for a beneficiary
     * @param beneficiary Beneficiary address
     * @return totalClaimable Total claimable amount
     */
    function getTotalClaimable(address beneficiary) external view returns (uint256 totalClaimable) {
        uint256[] storage grantIds = beneficiaryGrants[beneficiary];

        for (uint256 i = 0; i < grantIds.length; i++) {
            VestingGrant storage grant = grants[grantIds[i]];

            if (grant.status != GrantStatus.Active) continue;

            uint256 cliffEnd = grant.startTime + grant.cliffDuration;
            if (block.timestamp < cliffEnd) continue;

            uint256 vested = _calculateVested(grantIds[i]);
            totalClaimable += vested - grant.claimedAmount;
        }
    }

    /**
     * @notice Get schedule details
     * @param scheduleId Schedule ID
     * @return cliffDuration Cliff period
     * @return vestingDuration Total duration
     * @return revocable Whether revocable
     * @return name Schedule name
     */
    function getSchedule(uint256 scheduleId)
        external
        view
        returns (uint256 cliffDuration, uint256 vestingDuration, bool revocable, string memory name)
    {
        VestingSchedule storage s = schedules[scheduleId];
        return (s.cliffDuration, s.vestingDuration, s.revocable, s.name);
    }

    /**
     * @notice Get number of active grants
     * @return count Number of active grants
     */
    function getActiveGrantCount() external view returns (uint256 count) {
        return activeGrants.length;
    }

    // ============ Internal Functions ============

    /**
     * @notice Calculate vested amount for a grant - SEC-007
     * @param grantId Grant ID
     * @return vested Amount vested
     */
    function _calculateVested(uint256 grantId) internal view returns (uint256 vested) {
        VestingGrant storage grant = grants[grantId];

        // Not started yet
        if (block.timestamp < grant.startTime) return 0;

        uint256 elapsed = block.timestamp - grant.startTime;
        uint256 vestingEnd = grant.vestingDuration;

        // Fully vested
        if (elapsed >= vestingEnd) {
            return grant.totalAmount;
        }

        // Before cliff - nothing vested
        if (elapsed < grant.cliffDuration) {
            return 0;
        }

        // Linear vesting after cliff - SEC-007: Round DOWN
        vested = grant.totalAmount.mulDiv(elapsed, vestingEnd, Math.Rounding.Floor);

        return vested;
    }
}
