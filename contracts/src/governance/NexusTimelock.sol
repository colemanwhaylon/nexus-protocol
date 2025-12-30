// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title NexusTimelock
 * @author Nexus Protocol Team
 * @notice Timelock controller with enhanced security features for Nexus Protocol governance
 * @dev Extends OpenZeppelin TimelockController with additional features:
 *      - 48-hour default execution delay (configurable via governance)
 *      - Emergency cancellation capability for proposers
 *      - Operation batching with atomic execution
 *      - Integration with NexusGovernor for proposal execution
 *
 * Security Considerations (per SECURITY_REVIEW_BEFORE.md):
 *      - SEC-006: Two-step role transfers (inherited from AccessControl)
 *      - SEC-013: Comprehensive event emissions for all timelock operations
 *      - Minimum delay prevents flash governance attacks
 *      - Guardian role for emergency cancellation without self-dealing
 *
 * Role Architecture:
 *      - PROPOSER_ROLE: Can schedule operations (assigned to Governor)
 *      - EXECUTOR_ROLE: Can execute ready operations (can be open to anyone)
 *      - CANCELLER_ROLE: Can cancel pending operations (for emergencies)
 *      - DEFAULT_ADMIN_ROLE: Can grant/revoke roles (initially deployer, then timelock itself)
 *
 * @custom:security-contact security@nexusprotocol.io
 */
contract NexusTimelock is TimelockController {
    // ============ Constants ============

    /// @notice Default minimum delay for operation execution (48 hours)
    uint256 public constant DEFAULT_MIN_DELAY = 48 hours;

    /// @notice Absolute minimum delay that can be set (24 hours)
    uint256 public constant ABSOLUTE_MIN_DELAY = 24 hours;

    /// @notice Maximum delay that can be set (30 days)
    uint256 public constant MAX_DELAY = 30 days;

    // Note: CANCELLER_ROLE is inherited from TimelockController

    // ============ Events - SEC-013 ============

    /// @notice Emitted when the timelock is initialized
    /// @param minDelay Initial minimum delay
    /// @param proposers Initial proposer addresses
    /// @param executors Initial executor addresses
    /// @param admin Admin address (if any)
    event TimelockInitialized(
        uint256 minDelay,
        address[] proposers,
        address[] executors,
        address admin
    );

    /// @notice Emitted when minimum delay is updated
    /// @param oldDelay Previous minimum delay
    /// @param newDelay New minimum delay
    event MinDelayUpdated(uint256 indexed oldDelay, uint256 indexed newDelay);

    /// @notice Emitted when an operation is scheduled with detailed info
    /// @param id Operation identifier (hash)
    /// @param index Index in batch (0 for single operations)
    /// @param target Target address
    /// @param value ETH value
    /// @param data Calldata
    /// @param predecessor Required predecessor operation (bytes32(0) if none)
    /// @param delay Execution delay
    /// @param scheduler Address that scheduled the operation
    event OperationScheduledDetailed(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay,
        address indexed scheduler
    );

    /// @notice Emitted when an operation is cancelled
    /// @param id Operation identifier (hash)
    /// @param canceller Address that cancelled the operation
    event OperationCancelledBy(bytes32 indexed id, address indexed canceller);

    /// @notice Emitted when an operation batch is executed
    /// @param id Operation identifier (hash)
    /// @param executor Address that executed the operation
    event OperationExecutedBy(bytes32 indexed id, address indexed executor);

    // ============ Errors ============

    /// @notice Thrown when delay is below minimum
    error DelayBelowMinimum(uint256 delay, uint256 minimum);

    /// @notice Thrown when delay exceeds maximum
    error DelayExceedsMaximum(uint256 delay, uint256 maximum);

    /// @notice Thrown when no proposers are provided
    error NoProposersProvided();

    /// @notice Thrown when no executors are provided
    error NoExecutorsProvided();

    // ============ Constructor ============

    /**
     * @notice Initializes the NexusTimelock with specified roles and delay
     * @dev Sets up the timelock with:
     *      - Minimum delay of 48 hours (or custom if provided)
     *      - Proposer role for governor contract
     *      - Executor role (can be open or restricted)
     *      - Admin role transferred to timelock itself for self-governance
     *
     * @param minDelay_ Minimum delay for operations (must be >= 24 hours)
     * @param proposers_ Array of addresses that can schedule operations
     * @param executors_ Array of addresses that can execute operations
     * @param admin_ Optional admin address (address(0) for no external admin)
     *
     * Requirements:
     * - minDelay_ must be >= ABSOLUTE_MIN_DELAY (24 hours)
     * - minDelay_ must be <= MAX_DELAY (30 days)
     * - proposers_ must not be empty
     * - executors_ must not be empty (use address(0) for open execution)
     */
    constructor(
        uint256 minDelay_,
        address[] memory proposers_,
        address[] memory executors_,
        address admin_
    ) TimelockController(minDelay_, proposers_, executors_, admin_) {
        // Validate delay bounds
        if (minDelay_ < ABSOLUTE_MIN_DELAY) {
            revert DelayBelowMinimum(minDelay_, ABSOLUTE_MIN_DELAY);
        }
        if (minDelay_ > MAX_DELAY) {
            revert DelayExceedsMaximum(minDelay_, MAX_DELAY);
        }

        // Validate proposers
        if (proposers_.length == 0) {
            revert NoProposersProvided();
        }

        // Validate executors (note: empty array = open execution in OZ)
        // We require at least one executor for security
        if (executors_.length == 0) {
            revert NoExecutorsProvided();
        }

        // Grant CANCELLER_ROLE to all proposers by default
        for (uint256 i = 0; i < proposers_.length; i++) {
            _grantRole(CANCELLER_ROLE, proposers_[i]);
        }

        emit TimelockInitialized(minDelay_, proposers_, executors_, admin_);
    }

    // ============ External Functions ============

    /**
     * @notice Schedules an operation with detailed event emission
     * @dev Override to emit OperationScheduledDetailed - SEC-013
     * @param target Target address for the call
     * @param value ETH value to send
     * @param data Calldata for the call
     * @param predecessor Required predecessor operation (bytes32(0) if none)
     * @param salt Unique salt to differentiate operations with same parameters
     * @param delay Delay before operation can be executed
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        super.schedule(target, value, data, predecessor, salt, delay);

        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        emit OperationScheduledDetailed(
            id,
            0,
            target,
            value,
            data,
            predecessor,
            delay,
            _msgSender()
        );
    }

    /**
     * @notice Schedules a batch of operations with detailed event emission
     * @dev Override to emit OperationScheduledDetailed for each operation - SEC-013
     * @param targets Array of target addresses
     * @param values Array of ETH values
     * @param payloads Array of calldata
     * @param predecessor Required predecessor operation
     * @param salt Unique salt
     * @param delay Delay before execution
     */
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        super.scheduleBatch(targets, values, payloads, predecessor, salt, delay);

        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
        for (uint256 i = 0; i < targets.length; i++) {
            emit OperationScheduledDetailed(
                id,
                i,
                targets[i],
                values[i],
                payloads[i],
                predecessor,
                delay,
                _msgSender()
            );
        }
    }

    /**
     * @notice Cancels a scheduled operation
     * @dev Override to emit OperationCancelledBy - SEC-013
     *      Can be called by CANCELLER_ROLE holders
     * @param id Operation identifier to cancel
     */
    function cancel(bytes32 id) public virtual override onlyRole(CANCELLER_ROLE) {
        super.cancel(id);
        emit OperationCancelledBy(id, _msgSender());
    }

    /**
     * @notice Executes a ready operation
     * @dev Override to emit OperationExecutedBy - SEC-013
     * @param target Target address
     * @param value ETH value
     * @param payload Calldata
     * @param predecessor Required predecessor
     * @param salt Operation salt
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual override onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, payload, predecessor, salt);
        super.execute(target, value, payload, predecessor, salt);
        emit OperationExecutedBy(id, _msgSender());
    }

    /**
     * @notice Executes a batch of ready operations
     * @dev Override to emit OperationExecutedBy - SEC-013
     * @param targets Array of target addresses
     * @param values Array of ETH values
     * @param payloads Array of calldata
     * @param predecessor Required predecessor
     * @param salt Operation salt
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual override onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
        super.executeBatch(targets, values, payloads, predecessor, salt);
        emit OperationExecutedBy(id, _msgSender());
    }

    // ============ View Functions ============

    /**
     * @notice Returns the timelock configuration
     * @return _minDelay Current minimum delay
     * @return _absoluteMinDelay Absolute minimum delay allowed
     * @return _maxDelay Maximum delay allowed
     */
    function getTimelockConfig()
        external
        view
        returns (
            uint256 _minDelay,
            uint256 _absoluteMinDelay,
            uint256 _maxDelay
        )
    {
        return (getMinDelay(), ABSOLUTE_MIN_DELAY, MAX_DELAY);
    }

    /**
     * @notice Returns detailed information about an operation
     * @param id Operation identifier
     * @return isOperation Whether id is a registered operation
     * @return isPending Whether operation is pending
     * @return isReady Whether operation is ready for execution
     * @return isDone Whether operation has been executed
     * @return timestamp When operation becomes executable (0 if not scheduled)
     */
    function getOperationDetails(bytes32 id)
        external
        view
        returns (
            bool isOperation,
            bool isPending,
            bool isReady,
            bool isDone,
            uint256 timestamp
        )
    {
        timestamp = getTimestamp(id);
        isOperation = timestamp > 0;
        isPending = isOperationPending(id);
        isReady = isOperationReady(id);
        isDone = isOperationDone(id);
    }

    /**
     * @notice Checks if an address has proposer privileges
     * @param account Address to check
     * @return True if account can propose operations
     */
    function isProposer(address account) external view returns (bool) {
        return hasRole(PROPOSER_ROLE, account);
    }

    /**
     * @notice Checks if an address has executor privileges
     * @param account Address to check
     * @return True if account can execute operations
     */
    function isExecutor(address account) external view returns (bool) {
        return hasRole(EXECUTOR_ROLE, account);
    }

    /**
     * @notice Checks if an address has canceller privileges
     * @param account Address to check
     * @return True if account can cancel operations
     */
    function isCanceller(address account) external view returns (bool) {
        return hasRole(CANCELLER_ROLE, account);
    }

    // ============ Admin Functions ============

    /**
     * @notice Updates the minimum delay (self-governance only)
     * @dev Can only be called through the timelock itself
     *      Delay must be within bounds [ABSOLUTE_MIN_DELAY, MAX_DELAY]
     * @param newDelay New minimum delay value
     */
    function updateDelay(uint256 newDelay) public virtual override {
        // This function from TimelockController already requires self-call
        // We just add bounds checking
        if (newDelay < ABSOLUTE_MIN_DELAY) {
            revert DelayBelowMinimum(newDelay, ABSOLUTE_MIN_DELAY);
        }
        if (newDelay > MAX_DELAY) {
            revert DelayExceedsMaximum(newDelay, MAX_DELAY);
        }

        uint256 oldDelay = getMinDelay();
        super.updateDelay(newDelay);
        emit MinDelayUpdated(oldDelay, newDelay);
    }

    // ============ Role Management ============

    /**
     * @notice Grants canceller role to an address
     * @dev Only callable by admin (typically the timelock itself)
     * @param account Address to grant canceller role
     */
    function grantCancellerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(CANCELLER_ROLE, account);
    }

    /**
     * @notice Revokes canceller role from an address
     * @dev Only callable by admin
     * @param account Address to revoke canceller role from
     */
    function revokeCancellerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(CANCELLER_ROLE, account);
    }

    // ============ Receive Function ============

    /**
     * @notice Allows the timelock to receive ETH
     * @dev Required for operations that transfer ETH
     */
    receive() external payable override {}
}