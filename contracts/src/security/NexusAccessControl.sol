// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title NexusAccessControl
 * @author Nexus Protocol Team
 * @notice Central access control contract for the Nexus Protocol ecosystem
 * @dev Implements role-based access control (RBAC) with enumerable roles and pause functionality.
 *
 * Security Considerations (from SECURITY_REVIEW_BEFORE.md):
 * - SEC-006: Two-step role transfers for critical roles
 * - SEC-010: Guardian time limits implemented
 * - SEC-013: Events emitted for all state changes
 *
 * Role Hierarchy:
 * - DEFAULT_ADMIN_ROLE: Can grant/revoke all roles (should be Timelock)
 * - ADMIN_ROLE: Protocol administration
 * - OPERATOR_ROLE: Day-to-day operations
 * - COMPLIANCE_ROLE: KYC/AML operations
 * - PAUSER_ROLE: Emergency pause capability
 * - GUARDIAN_ROLE: Time-limited emergency powers
 * - UPGRADER_ROLE: Contract upgrade authorization
 * - SLASHER_ROLE: Stake slashing authorization
 */
contract NexusAccessControl is AccessControlEnumerable, Pausable {
    // ============ Role Definitions ============

    /// @notice Administrative role for protocol management
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Operator role for routine operations
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Compliance role for KYC/AML management
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    /// @notice Pauser role for emergency stops
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Guardian role with time-limited emergency powers
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Upgrader role for UUPS upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Slasher role for stake slashing
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    // ============ Guardian Time Limits (SEC-010) ============

    /// @notice Duration for which guardian powers are active after activation
    uint256 public constant GUARDIAN_ACTIVATION_DURATION = 7 days;

    /// @notice Cooldown period between guardian activations
    uint256 public constant GUARDIAN_COOLDOWN = 30 days;

    /// @notice Timestamp when current guardian activation expires
    uint256 public guardianActiveUntil;

    /// @notice Timestamp when guardian can be activated again
    uint256 public guardianCooldownUntil;

    /// @notice Sunset timestamp after which guardian role is permanently disabled
    uint256 public guardianSunset;

    // ============ Two-Step Role Transfer (SEC-006) ============

    /// @notice Pending admin for two-step transfer
    address public pendingAdmin;

    /// @notice Timestamp when pending admin was proposed
    uint256 public pendingAdminProposedAt;

    /// @notice Delay required before accepting admin role
    uint256 public constant ADMIN_TRANSFER_DELAY = 48 hours;

    // ============ Events ============

    /// @notice Emitted when guardian powers are activated
    event GuardianActivated(address indexed activator, uint256 activeUntil);

    /// @notice Emitted when guardian powers expire or are deactivated
    event GuardianDeactivated(address indexed deactivator);

    /// @notice Emitted when guardian sunset is set
    event GuardianSunsetSet(uint256 sunsetTimestamp);

    /// @notice Emitted when admin transfer is proposed
    event AdminTransferProposed(address indexed currentAdmin, address indexed pendingAdmin, uint256 proposedAt);

    /// @notice Emitted when admin transfer is accepted
    event AdminTransferAccepted(address indexed oldAdmin, address indexed newAdmin);

    /// @notice Emitted when admin transfer is cancelled
    event AdminTransferCancelled(address indexed canceller, address indexed pendingAdmin);

    /// @notice Emitted when a contract is registered with this access control
    event ContractRegistered(address indexed contractAddress, string name);

    /// @notice Emitted when protocol is paused
    event ProtocolPaused(address indexed pauser, string reason);

    /// @notice Emitted when protocol is unpaused
    event ProtocolUnpaused(address indexed unpauser);

    // ============ Errors ============

    /// @notice Thrown when guardian is not currently active
    error GuardianNotActive();

    /// @notice Thrown when guardian is still in cooldown
    error GuardianInCooldown();

    /// @notice Thrown when guardian has been sunset
    error GuardianSunsetReached();

    /// @notice Thrown when guardian is already active
    error GuardianAlreadyActive();

    /// @notice Thrown when admin transfer delay has not passed
    error AdminTransferDelayNotPassed();

    /// @notice Thrown when caller is not the pending admin
    error NotPendingAdmin();

    /// @notice Thrown when no pending admin exists
    error NoPendingAdmin();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when sunset is in the past
    error InvalidSunset();

    // ============ Constructor ============

    /**
     * @notice Initializes the access control system
     * @param initialAdmin Address to receive initial admin role
     * @param initialGuardianSunset Timestamp after which guardian role is disabled (0 = never)
     */
    constructor(address initialAdmin, uint256 initialGuardianSunset) {
        if (initialAdmin == address(0)) revert ZeroAddress();

        // Grant all initial roles to the admin
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);

        // Set role admins
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(COMPLIANCE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(SLASHER_ROLE, ADMIN_ROLE);

        // Set guardian sunset if provided
        if (initialGuardianSunset > 0) {
            if (initialGuardianSunset <= block.timestamp) revert InvalidSunset();
            guardianSunset = initialGuardianSunset;
            emit GuardianSunsetSet(initialGuardianSunset);
        }
    }

    // ============ Guardian Functions (SEC-010) ============

    /**
     * @notice Activates guardian emergency powers
     * @dev Can only be called by guardian role holder, subject to cooldown and sunset
     */
    function activateGuardian() external onlyRole(GUARDIAN_ROLE) {
        if (guardianSunset != 0 && block.timestamp >= guardianSunset) {
            revert GuardianSunsetReached();
        }
        if (block.timestamp < guardianCooldownUntil) {
            revert GuardianInCooldown();
        }
        if (block.timestamp < guardianActiveUntil) {
            revert GuardianAlreadyActive();
        }

        guardianActiveUntil = block.timestamp + GUARDIAN_ACTIVATION_DURATION;
        guardianCooldownUntil = block.timestamp + GUARDIAN_COOLDOWN;

        emit GuardianActivated(msg.sender, guardianActiveUntil);
    }

    /**
     * @notice Deactivates guardian powers early
     * @dev Can be called by guardian or admin to voluntarily end activation period
     */
    function deactivateGuardian() external {
        if (!hasRole(GUARDIAN_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GUARDIAN_ROLE);
        }

        guardianActiveUntil = 0;
        emit GuardianDeactivated(msg.sender);
    }

    /**
     * @notice Sets the guardian sunset timestamp
     * @param sunset Timestamp after which guardian role is permanently disabled
     * @dev Can only be called by DEFAULT_ADMIN_ROLE. Cannot be set to past or removed once set.
     */
    function setGuardianSunset(uint256 sunset) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (sunset <= block.timestamp) revert InvalidSunset();
        if (guardianSunset != 0 && sunset > guardianSunset) {
            // Cannot extend sunset once set
            revert InvalidSunset();
        }

        guardianSunset = sunset;
        emit GuardianSunsetSet(sunset);
    }

    /**
     * @notice Checks if guardian powers are currently active
     * @return bool True if guardian is active and not sunset
     */
    function isGuardianActive() public view returns (bool) {
        if (guardianSunset != 0 && block.timestamp >= guardianSunset) {
            return false;
        }
        return block.timestamp < guardianActiveUntil;
    }

    // ============ Two-Step Admin Transfer (SEC-006) ============

    /**
     * @notice Proposes a new admin address
     * @param newAdmin Address to become the new admin
     * @dev Starts a 48-hour delay before the new admin can accept
     */
    function proposeAdminTransfer(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAdmin == address(0)) revert ZeroAddress();

        pendingAdmin = newAdmin;
        pendingAdminProposedAt = block.timestamp;

        emit AdminTransferProposed(msg.sender, newAdmin, block.timestamp);
    }

    /**
     * @notice Accepts the admin role transfer
     * @dev Can only be called by pending admin after delay period
     */
    function acceptAdminTransfer() external {
        if (msg.sender != pendingAdmin) revert NotPendingAdmin();
        if (pendingAdmin == address(0)) revert NoPendingAdmin();
        if (block.timestamp < pendingAdminProposedAt + ADMIN_TRANSFER_DELAY) {
            revert AdminTransferDelayNotPassed();
        }

        address oldAdmin = getRoleMember(DEFAULT_ADMIN_ROLE, 0);

        // Grant new admin all critical roles
        _grantRole(DEFAULT_ADMIN_ROLE, pendingAdmin);
        _grantRole(ADMIN_ROLE, pendingAdmin);

        // Revoke from old admin
        _revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);
        _revokeRole(ADMIN_ROLE, oldAdmin);

        emit AdminTransferAccepted(oldAdmin, pendingAdmin);

        // Clear pending
        pendingAdmin = address(0);
        pendingAdminProposedAt = 0;
    }

    /**
     * @notice Cancels a pending admin transfer
     * @dev Can be called by current admin or pending admin
     */
    function cancelAdminTransfer() external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && msg.sender != pendingAdmin) {
            revert AccessControlUnauthorizedAccount(msg.sender, DEFAULT_ADMIN_ROLE);
        }
        if (pendingAdmin == address(0)) revert NoPendingAdmin();

        address cancelled = pendingAdmin;
        pendingAdmin = address(0);
        pendingAdminProposedAt = 0;

        emit AdminTransferCancelled(msg.sender, cancelled);
    }

    // ============ Pause Functions ============

    /**
     * @notice Pauses the protocol
     * @param reason Human-readable reason for the pause
     * @dev Can be called by PAUSER_ROLE or active GUARDIAN_ROLE
     */
    function pause(string calldata reason) external {
        if (!hasRole(PAUSER_ROLE, msg.sender)) {
            if (!hasRole(GUARDIAN_ROLE, msg.sender) || !isGuardianActive()) {
                revert AccessControlUnauthorizedAccount(msg.sender, PAUSER_ROLE);
            }
        }

        _pause();
        emit ProtocolPaused(msg.sender, reason);
    }

    /**
     * @notice Unpauses the protocol
     * @dev Can only be called by ADMIN_ROLE (not pauser to prevent immediate toggle)
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit ProtocolUnpaused(msg.sender);
    }

    // ============ View Functions ============
    // Note: getRoleMembers() is inherited from AccessControlEnumerable

    /**
     * @notice Checks if an address has any privileged role
     * @param account Address to check
     * @return bool True if address has any admin/operator role
     */
    function hasPrivilegedRole(address account) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account) ||
               hasRole(ADMIN_ROLE, account) ||
               hasRole(OPERATOR_ROLE, account);
    }

    /**
     * @notice Gets the time remaining until guardian powers expire
     * @return uint256 Seconds remaining, 0 if not active
     */
    function guardianTimeRemaining() external view returns (uint256) {
        if (!isGuardianActive()) return 0;
        return guardianActiveUntil - block.timestamp;
    }

    /**
     * @notice Gets the time remaining until guardian can be activated again
     * @return uint256 Seconds remaining in cooldown, 0 if can activate
     */
    function guardianCooldownRemaining() external view returns (uint256) {
        if (block.timestamp >= guardianCooldownUntil) return 0;
        return guardianCooldownUntil - block.timestamp;
    }
}
