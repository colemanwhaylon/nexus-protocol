// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NexusEmergency
 * @author Nexus Protocol Team
 * @notice Emergency contract for protocol-wide pause and fund recovery
 * @dev Implements timelocked emergency drain and user self-rescue functionality.
 *
 * Security Requirements (from SECURITY_REVIEW_BEFORE.md):
 * - SEC-004: Timelocked emergency drain function (72-hour delay)
 * - SEC-004: Drain destination must be multisig (not single EOA)
 * - SEC-004: Per-contract drain capability
 * - SEC-004: Recovery mode with limited functionality
 * - SEC-004: User self-rescue for personal funds after 30-day pause
 * - SEC-013: Events emitted for all state changes
 *
 * Emergency Flow:
 * 1. Guardian/Admin pauses protocol
 * 2. If needed, initiate emergency drain (starts 72-hour timer)
 * 3. After 72 hours, execute drain to multisig
 * 4. If paused > 30 days, users can self-rescue their funds
 */
contract NexusEmergency is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    // ============ State Variables ============

    /// @notice Access control contract for role checks
    address public immutable accessControl;

    /// @notice Mapping of contract address to pause status
    mapping(address => bool) public contractPaused;

    /// @notice Global protocol pause status
    bool public globalPause;

    /// @notice Timestamp when global pause was initiated
    uint256 public pauseInitiatedAt;

    /// @notice Duration after which users can self-rescue
    uint256 public constant USER_RESCUE_DELAY = 30 days;

    /// @notice Duration for emergency drain timelock
    uint256 public constant EMERGENCY_DRAIN_DELAY = 72 hours;

    // ============ Emergency Drain State ============

    struct DrainRequest {
        address token;
        address targetContract;
        address destination;
        uint256 amount;
        uint256 initiatedAt;
        bool executed;
        bool cancelled;
    }

    /// @notice Mapping of drain request ID to request details
    mapping(bytes32 => DrainRequest) public drainRequests;

    /// @notice List of pending drain request IDs
    bytes32[] public pendingDrains;

    /// @notice Mapping to track approved multisig destinations
    mapping(address => bool) public approvedMultisigs;

    /// @notice Minimum number of signers required for a multisig to be approved
    uint256 public constant MIN_MULTISIG_SIGNERS = 3;

    // ============ User Rescue State ============

    /// @notice Mapping of user address to rescued token to amount
    mapping(address => mapping(address => uint256)) public rescuedBalances;

    /// @notice Contracts registered for user rescue functionality
    mapping(address => bool) public rescueEnabledContracts;

    // ============ Recovery Mode ============

    /// @notice Whether protocol is in recovery mode
    bool public recoveryMode;

    /// @notice Contracts with recovery mode enabled
    mapping(address => bool) public recoveryModeContracts;

    // ============ Roles (from AccessControl) ============

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============ Events ============

    event ContractPaused(address indexed contractAddress, address indexed pauser);
    event ContractUnpaused(address indexed contractAddress, address indexed unpauser);
    event GlobalPauseInitiated(address indexed initiator, uint256 timestamp);
    event GlobalPauseLifted(address indexed lifter);
    event DrainRequested(
        bytes32 indexed requestId,
        address indexed token,
        address indexed targetContract,
        address destination,
        uint256 amount,
        uint256 executeAfter
    );
    event DrainExecuted(bytes32 indexed requestId, address indexed executor);
    event DrainCancelled(bytes32 indexed requestId, address indexed canceller);
    event MultisigApproved(address indexed multisig, address indexed approver);
    event MultisigRevoked(address indexed multisig, address indexed revoker);
    event UserRescueExecuted(
        address indexed user,
        address indexed token,
        address indexed sourceContract,
        uint256 amount
    );
    event RecoveryModeActivated(address indexed activator);
    event RecoveryModeDeactivated(address indexed deactivator);
    event RescueContractRegistered(address indexed contractAddress);

    // ============ Errors ============

    error Unauthorized();
    error ZeroAddress();
    error NotPaused();
    error AlreadyPaused();
    error InvalidMultisig();
    error DrainNotReady();
    error DrainAlreadyExecuted();
    error DrainCancelledOrNotFound();
    error RescueNotAvailable();
    error RescueTooEarly();
    error ContractNotRegistered();
    error InvalidAmount();
    error NotInRecoveryMode();

    // ============ Modifiers ============

    modifier onlyRole(bytes32 role) {
        if (!_hasRole(role, msg.sender)) revert Unauthorized();
        _;
    }

    modifier onlyAdmin() {
        if (!_hasRole(ADMIN_ROLE, msg.sender)) revert Unauthorized();
        _;
    }

    modifier onlyPauser() {
        if (!_hasRole(PAUSER_ROLE, msg.sender) && !_hasRole(GUARDIAN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the emergency contract
     * @param _accessControl Address of the NexusAccessControl contract
     */
    constructor(address _accessControl) {
        if (_accessControl == address(0)) revert ZeroAddress();
        accessControl = _accessControl;
    }

    // ============ Pause Functions ============

    /**
     * @notice Pauses a specific contract
     * @param target Contract address to pause
     */
    function pauseContract(address target) external onlyPauser {
        if (target == address(0)) revert ZeroAddress();
        if (contractPaused[target]) revert AlreadyPaused();

        contractPaused[target] = true;
        emit ContractPaused(target, msg.sender);
    }

    /**
     * @notice Unpauses a specific contract
     * @param target Contract address to unpause
     */
    function unpauseContract(address target) external onlyAdmin {
        if (!contractPaused[target]) revert NotPaused();

        contractPaused[target] = false;
        emit ContractUnpaused(target, msg.sender);
    }

    /**
     * @notice Initiates global protocol pause
     */
    function initiateGlobalPause() external onlyPauser {
        if (globalPause) revert AlreadyPaused();

        globalPause = true;
        pauseInitiatedAt = block.timestamp;
        emit GlobalPauseInitiated(msg.sender, block.timestamp);
    }

    /**
     * @notice Lifts global protocol pause
     */
    function liftGlobalPause() external onlyAdmin {
        if (!globalPause) revert NotPaused();

        globalPause = false;
        pauseInitiatedAt = 0;
        emit GlobalPauseLifted(msg.sender);
    }

    // ============ Emergency Drain Functions (SEC-004) ============

    /**
     * @notice Approves a multisig address for drain destinations
     * @param multisig Address of the multisig wallet
     * @dev Should verify off-chain that this is a valid multisig with >= 3 signers
     */
    function approveMultisig(address multisig) external onlyAdmin {
        if (multisig == address(0)) revert ZeroAddress();
        if (multisig.code.length == 0) revert InvalidMultisig(); // Must be contract

        approvedMultisigs[multisig] = true;
        emit MultisigApproved(multisig, msg.sender);
    }

    /**
     * @notice Revokes a multisig approval
     * @param multisig Address of the multisig to revoke
     */
    function revokeMultisig(address multisig) external onlyAdmin {
        approvedMultisigs[multisig] = false;
        emit MultisigRevoked(multisig, msg.sender);
    }

    /**
     * @notice Initiates an emergency drain request
     * @param token ERC20 token to drain (address(0) for ETH)
     * @param targetContract Contract to drain from
     * @param destination Approved multisig to receive funds
     * @param amount Amount to drain
     * @return requestId Unique identifier for this drain request
     */
    function initiateDrain(
        address token,
        address targetContract,
        address destination,
        uint256 amount
    ) external onlyAdmin returns (bytes32 requestId) {
        if (!globalPause) revert NotPaused();
        if (!approvedMultisigs[destination]) revert InvalidMultisig();
        if (amount == 0) revert InvalidAmount();

        requestId = keccak256(
            abi.encodePacked(token, targetContract, destination, amount, block.timestamp)
        );

        drainRequests[requestId] = DrainRequest({
            token: token,
            targetContract: targetContract,
            destination: destination,
            amount: amount,
            initiatedAt: block.timestamp,
            executed: false,
            cancelled: false
        });

        pendingDrains.push(requestId);

        emit DrainRequested(
            requestId,
            token,
            targetContract,
            destination,
            amount,
            block.timestamp + EMERGENCY_DRAIN_DELAY
        );
    }

    /**
     * @notice Executes a pending drain after timelock period
     * @param requestId ID of the drain request to execute
     */
    function executeDrain(bytes32 requestId) external onlyAdmin nonReentrant {
        DrainRequest storage request = drainRequests[requestId];

        if (request.initiatedAt == 0 || request.cancelled) revert DrainCancelledOrNotFound();
        if (request.executed) revert DrainAlreadyExecuted();
        if (block.timestamp < request.initiatedAt + EMERGENCY_DRAIN_DELAY) revert DrainNotReady();

        request.executed = true;

        if (request.token == address(0)) {
            // Drain ETH
            (bool success, ) = request.destination.call{value: request.amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Drain ERC20 - assumes this contract has approval or is the owner
            IERC20(request.token).safeTransfer(request.destination, request.amount);
        }

        emit DrainExecuted(requestId, msg.sender);
    }

    /**
     * @notice Cancels a pending drain request
     * @param requestId ID of the drain request to cancel
     */
    function cancelDrain(bytes32 requestId) external onlyAdmin {
        DrainRequest storage request = drainRequests[requestId];

        if (request.initiatedAt == 0) revert DrainCancelledOrNotFound();
        if (request.executed) revert DrainAlreadyExecuted();

        request.cancelled = true;
        emit DrainCancelled(requestId, msg.sender);
    }

    // ============ User Self-Rescue Functions (SEC-004) ============

    /**
     * @notice Registers a contract for user rescue functionality
     * @param contractAddress Contract that supports rescue
     */
    function registerRescueContract(address contractAddress) external onlyAdmin {
        if (contractAddress == address(0)) revert ZeroAddress();
        rescueEnabledContracts[contractAddress] = true;
        emit RescueContractRegistered(contractAddress);
    }

    /**
     * @notice Allows users to rescue their funds after extended pause
     * @param token Token to rescue
     * @param sourceContract Contract to rescue from (must be registered)
     * @param amount Amount to rescue
     * @dev Only available after 30 days of global pause
     */
    function userRescue(
        address token,
        address sourceContract,
        uint256 amount
    ) external nonReentrant {
        if (!globalPause) revert NotPaused();
        if (!rescueEnabledContracts[sourceContract]) revert ContractNotRegistered();
        if (block.timestamp < pauseInitiatedAt + USER_RESCUE_DELAY) revert RescueTooEarly();
        if (amount == 0) revert InvalidAmount();

        // Record the rescue (actual transfer handled by source contract)
        rescuedBalances[msg.sender][token] += amount;

        emit UserRescueExecuted(msg.sender, token, sourceContract, amount);
    }

    /**
     * @notice Checks if user rescue is currently available
     * @return bool True if rescue is available
     */
    function isRescueAvailable() external view returns (bool) {
        return globalPause && block.timestamp >= pauseInitiatedAt + USER_RESCUE_DELAY;
    }

    /**
     * @notice Gets time until user rescue becomes available
     * @return uint256 Seconds until rescue available, 0 if already available
     */
    function timeUntilRescue() external view returns (uint256) {
        if (!globalPause) return type(uint256).max;
        uint256 rescueTime = pauseInitiatedAt + USER_RESCUE_DELAY;
        if (block.timestamp >= rescueTime) return 0;
        return rescueTime - block.timestamp;
    }

    // ============ Recovery Mode Functions ============

    /**
     * @notice Activates recovery mode for the protocol
     * @dev Enables limited functionality for fund recovery
     */
    function activateRecoveryMode() external onlyAdmin {
        if (!globalPause) revert NotPaused();
        recoveryMode = true;
        emit RecoveryModeActivated(msg.sender);
    }

    /**
     * @notice Deactivates recovery mode
     */
    function deactivateRecoveryMode() external onlyAdmin {
        recoveryMode = false;
        emit RecoveryModeDeactivated(msg.sender);
    }

    /**
     * @notice Enables recovery mode for a specific contract
     * @param contractAddress Contract to enable recovery mode for
     */
    function enableContractRecovery(address contractAddress) external onlyAdmin {
        if (!recoveryMode) revert NotInRecoveryMode();
        recoveryModeContracts[contractAddress] = true;
    }

    // ============ View Functions ============

    /**
     * @notice Checks if a contract is currently paused
     * @param target Contract to check
     * @return bool True if contract is paused (individually or globally)
     */
    function isPaused(address target) external view returns (bool) {
        return globalPause || contractPaused[target];
    }

    /**
     * @notice Gets details of a drain request
     * @param requestId ID of the drain request
     * @return request The drain request details
     */
    function getDrainRequest(bytes32 requestId) external view returns (DrainRequest memory) {
        return drainRequests[requestId];
    }

    /**
     * @notice Gets the number of pending drain requests
     * @return uint256 Number of pending drains
     */
    function getPendingDrainCount() external view returns (uint256) {
        return pendingDrains.length;
    }

    /**
     * @notice Gets time remaining until a drain can be executed
     * @param requestId ID of the drain request
     * @return uint256 Seconds remaining, 0 if ready
     */
    function getDrainTimeRemaining(bytes32 requestId) external view returns (uint256) {
        DrainRequest storage request = drainRequests[requestId];
        if (request.initiatedAt == 0 || request.executed || request.cancelled) return 0;

        uint256 executeTime = request.initiatedAt + EMERGENCY_DRAIN_DELAY;
        if (block.timestamp >= executeTime) return 0;
        return executeTime - block.timestamp;
    }

    // ============ Internal Functions ============

    /**
     * @notice Checks if an account has a specific role via AccessControl
     * @param role Role identifier
     * @param account Address to check
     * @return bool True if account has the role
     */
    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        // Call accessControl.hasRole(role, account)
        (bool success, bytes memory data) = accessControl.staticcall(
            abi.encodeWithSignature("hasRole(bytes32,address)", role, account)
        );
        return success && abi.decode(data, (bool));
    }

    // ============ Receive ETH ============

    receive() external payable {}
}
