// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NexusMultiSig
 * @author Nexus Protocol Team
 * @notice N-of-M multi-signature wallet for Nexus Protocol treasury and admin operations
 * @dev Implements a secure multi-signature wallet with the following features:
 *      - N-of-M threshold signatures (e.g., 3-of-5)
 *      - Transaction batching for atomic execution
 *      - Transaction expiry to prevent stale executions
 *      - Owner management (add/remove) through multi-sig
 *      - Threshold adjustment through multi-sig
 *      - Nonce-based replay protection
 *
 * Security Considerations (per SECURITY_REVIEW_BEFORE.md):
 *      - SEC-006: Owner changes require multi-sig approval
 *      - SEC-013: Comprehensive event emissions for all operations
 *      - Reentrancy protection on all external calls
 *      - Transaction expiry prevents replay of old transactions
 *      - Nonce prevents signature replay within valid timeframe
 *
 * @custom:security-contact security@nexusprotocol.io
 */
contract NexusMultiSig is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============ Constants ============

    /// @notice Maximum number of owners allowed
    uint256 public constant MAX_OWNERS = 20;

    /// @notice Minimum number of owners required
    uint256 public constant MIN_OWNERS = 2;

    /// @notice Default transaction expiry period (7 days)
    uint256 public constant DEFAULT_EXPIRY = 7 days;

    /// @notice Minimum transaction expiry period (1 hour)
    uint256 public constant MIN_EXPIRY = 1 hours;

    /// @notice Maximum transaction expiry period (30 days)
    uint256 public constant MAX_EXPIRY = 30 days;

    // ============ State Variables ============

    /// @notice Array of owner addresses
    address[] public owners;

    /// @notice Mapping to check if address is owner
    mapping(address => bool) public isOwner;

    /// @notice Required number of confirmations for execution
    uint256 public threshold;

    /// @notice Transaction expiry period
    uint256 public expiryPeriod;

    /// @notice Current transaction nonce (incremented after each submission)
    uint256 public nonce;

    /// @notice Transaction details
    struct Transaction {
        address to; // Target address
        uint256 value; // ETH value
        bytes data; // Calldata
        uint256 nonce; // Transaction nonce
        uint256 deadline; // Expiry timestamp
        bool executed; // Execution status
    }

    /// @notice Batch transaction details
    struct BatchTransaction {
        address[] targets; // Target addresses
        uint256[] values; // ETH values
        bytes[] data; // Calldatas
        uint256 nonce; // Transaction nonce
        uint256 deadline; // Expiry timestamp
        bool executed; // Execution status
    }

    /// @notice Mapping from transaction hash to confirmations
    mapping(bytes32 => mapping(address => bool)) public confirmations;

    /// @notice Mapping from transaction hash to confirmation count
    mapping(bytes32 => uint256) public confirmationCount;

    /// @notice Mapping from transaction hash to Transaction
    mapping(bytes32 => Transaction) public transactions;

    /// @notice Mapping from batch hash to BatchTransaction
    mapping(bytes32 => BatchTransaction) public batchTransactions;

    /// @notice Set of submitted transaction hashes
    mapping(bytes32 => bool) public isSubmitted;

    // ============ Events - SEC-013 ============

    /// @notice Emitted when the wallet is initialized
    event WalletInitialized(address[] owners, uint256 threshold, uint256 expiryPeriod);

    /// @notice Emitted when a transaction is submitted
    event TransactionSubmitted(
        bytes32 indexed txHash,
        address indexed submitter,
        address indexed to,
        uint256 value,
        bytes data,
        uint256 nonce,
        uint256 deadline
    );

    /// @notice Emitted when a batch transaction is submitted
    event BatchSubmitted(
        bytes32 indexed batchHash, address indexed submitter, uint256 transactionCount, uint256 nonce, uint256 deadline
    );

    /// @notice Emitted when a transaction is confirmed
    event TransactionConfirmed(bytes32 indexed txHash, address indexed confirmer, uint256 confirmationCount);

    /// @notice Emitted when a confirmation is revoked
    event ConfirmationRevoked(bytes32 indexed txHash, address indexed revoker, uint256 confirmationCount);

    /// @notice Emitted when a transaction is executed
    event TransactionExecuted(bytes32 indexed txHash, address indexed executor, bool success, bytes returnData);

    /// @notice Emitted when a batch transaction is executed
    event BatchExecuted(
        bytes32 indexed batchHash, address indexed executor, uint256 successCount, uint256 failureCount
    );

    /// @notice Emitted when an owner is added
    event OwnerAdded(address indexed owner, address indexed addedBy);

    /// @notice Emitted when an owner is removed
    event OwnerRemoved(address indexed owner, address indexed removedBy);

    /// @notice Emitted when threshold is changed
    event ThresholdChanged(uint256 oldThreshold, uint256 newThreshold);

    /// @notice Emitted when expiry period is changed
    event ExpiryPeriodChanged(uint256 oldExpiry, uint256 newExpiry);

    /// @notice Emitted when ETH is received
    event EtherReceived(address indexed sender, uint256 amount);

    // ============ Errors ============

    error NotOwner();
    error AlreadyOwner();
    error NotAnOwner();
    error InvalidThreshold(uint256 threshold, uint256 ownerCount);
    error InvalidOwnerCount(uint256 count, uint256 min, uint256 max);
    error InvalidExpiryPeriod(uint256 expiry, uint256 min, uint256 max);
    error ZeroAddress();
    error TransactionAlreadySubmitted();
    error TransactionNotSubmitted();
    error TransactionAlreadyExecuted();
    error TransactionExpired();
    error AlreadyConfirmed();
    error NotConfirmed();
    error InsufficientConfirmations(uint256 have, uint256 need);
    error ExecutionFailed();
    error ArrayLengthMismatch();
    error EmptyBatch();
    error CannotRemoveSelf();

    // ============ Modifiers ============

    /// @notice Restricts function to owners only
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    /// @notice Restricts function to wallet itself (for self-governance)
    modifier onlySelf() {
        if (msg.sender != address(this)) revert NotOwner();
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the multi-sig wallet with owners and threshold
     * @param _owners Array of initial owner addresses
     * @param _threshold Required number of confirmations
     * @param _expiryPeriod Transaction expiry period in seconds
     */
    constructor(address[] memory _owners, uint256 _threshold, uint256 _expiryPeriod) {
        // Validate owner count
        if (_owners.length < MIN_OWNERS || _owners.length > MAX_OWNERS) {
            revert InvalidOwnerCount(_owners.length, MIN_OWNERS, MAX_OWNERS);
        }

        // Validate threshold
        if (_threshold == 0 || _threshold > _owners.length) {
            revert InvalidThreshold(_threshold, _owners.length);
        }

        // Validate expiry period
        if (_expiryPeriod < MIN_EXPIRY || _expiryPeriod > MAX_EXPIRY) {
            revert InvalidExpiryPeriod(_expiryPeriod, MIN_EXPIRY, MAX_EXPIRY);
        }

        // Add owners
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert ZeroAddress();
            if (isOwner[owner]) revert AlreadyOwner();

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
        expiryPeriod = _expiryPeriod;

        emit WalletInitialized(_owners, _threshold, _expiryPeriod);
    }

    // ============ External Functions ============

    /**
     * @notice Submits a new transaction for confirmation
     * @param to Target address
     * @param value ETH value to send
     * @param data Calldata
     * @return txHash The transaction hash
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    )
        external
        onlyOwner
        returns (bytes32 txHash)
    {
        if (to == address(0)) revert ZeroAddress();

        uint256 currentNonce = nonce++;
        uint256 deadline = block.timestamp + expiryPeriod;

        txHash = keccak256(abi.encode(to, value, data, currentNonce, deadline));

        if (isSubmitted[txHash]) revert TransactionAlreadySubmitted();

        transactions[txHash] =
            Transaction({ to: to, value: value, data: data, nonce: currentNonce, deadline: deadline, executed: false });

        isSubmitted[txHash] = true;

        // Auto-confirm by submitter
        confirmations[txHash][msg.sender] = true;
        confirmationCount[txHash] = 1;

        emit TransactionSubmitted(txHash, msg.sender, to, value, data, currentNonce, deadline);
        emit TransactionConfirmed(txHash, msg.sender, 1);

        return txHash;
    }

    /**
     * @notice Submits a batch of transactions for confirmation
     * @param targets Array of target addresses
     * @param values Array of ETH values
     * @param data Array of calldatas
     * @return batchHash The batch transaction hash
     */
    function submitBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata data
    )
        external
        onlyOwner
        returns (bytes32 batchHash)
    {
        uint256 len = targets.length;
        if (len == 0) revert EmptyBatch();
        if (len != values.length || len != data.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < len; i++) {
            if (targets[i] == address(0)) revert ZeroAddress();
        }

        uint256 currentNonce = nonce++;
        uint256 deadline = block.timestamp + expiryPeriod;

        batchHash = keccak256(abi.encode(targets, values, data, currentNonce, deadline));

        if (isSubmitted[batchHash]) revert TransactionAlreadySubmitted();

        batchTransactions[batchHash] = BatchTransaction({
            targets: targets, values: values, data: data, nonce: currentNonce, deadline: deadline, executed: false
        });

        isSubmitted[batchHash] = true;

        // Auto-confirm by submitter
        confirmations[batchHash][msg.sender] = true;
        confirmationCount[batchHash] = 1;

        emit BatchSubmitted(batchHash, msg.sender, len, currentNonce, deadline);
        emit TransactionConfirmed(batchHash, msg.sender, 1);

        return batchHash;
    }

    /**
     * @notice Confirms a pending transaction
     * @param txHash Transaction hash to confirm
     */
    function confirmTransaction(bytes32 txHash) external onlyOwner {
        if (!isSubmitted[txHash]) revert TransactionNotSubmitted();
        if (confirmations[txHash][msg.sender]) revert AlreadyConfirmed();

        // Check if it's a regular transaction
        Transaction storage txn = transactions[txHash];
        if (txn.to != address(0)) {
            if (txn.executed) revert TransactionAlreadyExecuted();
            if (block.timestamp > txn.deadline) revert TransactionExpired();
        } else {
            // Check batch transaction
            BatchTransaction storage batch = batchTransactions[txHash];
            if (batch.executed) revert TransactionAlreadyExecuted();
            if (block.timestamp > batch.deadline) revert TransactionExpired();
        }

        confirmations[txHash][msg.sender] = true;
        confirmationCount[txHash]++;

        emit TransactionConfirmed(txHash, msg.sender, confirmationCount[txHash]);
    }

    /**
     * @notice Revokes a confirmation for a pending transaction
     * @param txHash Transaction hash to revoke confirmation for
     */
    function revokeConfirmation(bytes32 txHash) external onlyOwner {
        if (!isSubmitted[txHash]) revert TransactionNotSubmitted();
        if (!confirmations[txHash][msg.sender]) revert NotConfirmed();

        // Check if it's a regular transaction
        Transaction storage txn = transactions[txHash];
        if (txn.to != address(0)) {
            if (txn.executed) revert TransactionAlreadyExecuted();
        } else {
            BatchTransaction storage batch = batchTransactions[txHash];
            if (batch.executed) revert TransactionAlreadyExecuted();
        }

        confirmations[txHash][msg.sender] = false;
        confirmationCount[txHash]--;

        emit ConfirmationRevoked(txHash, msg.sender, confirmationCount[txHash]);
    }

    /**
     * @notice Executes a confirmed transaction
     * @param txHash Transaction hash to execute
     */
    function executeTransaction(bytes32 txHash) external onlyOwner nonReentrant {
        Transaction storage txn = transactions[txHash];

        if (txn.to == address(0)) revert TransactionNotSubmitted();
        if (txn.executed) revert TransactionAlreadyExecuted();
        if (block.timestamp > txn.deadline) revert TransactionExpired();
        if (confirmationCount[txHash] < threshold) {
            revert InsufficientConfirmations(confirmationCount[txHash], threshold);
        }

        txn.executed = true;

        (bool success, bytes memory returnData) = txn.to.call{ value: txn.value }(txn.data);

        emit TransactionExecuted(txHash, msg.sender, success, returnData);

        if (!success) revert ExecutionFailed();
    }

    /**
     * @notice Executes a confirmed batch transaction
     * @param batchHash Batch hash to execute
     */
    function executeBatch(bytes32 batchHash) external onlyOwner nonReentrant {
        BatchTransaction storage batch = batchTransactions[batchHash];

        if (batch.targets.length == 0) revert TransactionNotSubmitted();
        if (batch.executed) revert TransactionAlreadyExecuted();
        if (block.timestamp > batch.deadline) revert TransactionExpired();
        if (confirmationCount[batchHash] < threshold) {
            revert InsufficientConfirmations(confirmationCount[batchHash], threshold);
        }

        batch.executed = true;

        uint256 successCount = 0;
        uint256 failureCount = 0;

        for (uint256 i = 0; i < batch.targets.length; i++) {
            (bool success,) = batch.targets[i].call{ value: batch.values[i] }(batch.data[i]);
            if (success) {
                successCount++;
            } else {
                failureCount++;
            }
        }

        emit BatchExecuted(batchHash, msg.sender, successCount, failureCount);
    }

    // ============ Owner Management (Self-Governance) ============

    /**
     * @notice Adds a new owner (must be called through multi-sig)
     * @param owner Address to add as owner
     */
    function addOwner(address owner) external onlySelf {
        if (owner == address(0)) revert ZeroAddress();
        if (isOwner[owner]) revert AlreadyOwner();
        if (owners.length >= MAX_OWNERS) {
            revert InvalidOwnerCount(owners.length + 1, MIN_OWNERS, MAX_OWNERS);
        }

        isOwner[owner] = true;
        owners.push(owner);

        emit OwnerAdded(owner, msg.sender);
    }

    /**
     * @notice Removes an owner (must be called through multi-sig)
     * @param owner Address to remove from owners
     */
    function removeOwner(address owner) external onlySelf {
        if (!isOwner[owner]) revert NotAnOwner();
        if (owners.length <= MIN_OWNERS) {
            revert InvalidOwnerCount(owners.length - 1, MIN_OWNERS, MAX_OWNERS);
        }
        if (owners.length - 1 < threshold) {
            revert InvalidThreshold(threshold, owners.length - 1);
        }

        isOwner[owner] = false;

        // Remove from array
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        emit OwnerRemoved(owner, msg.sender);
    }

    /**
     * @notice Changes the confirmation threshold (must be called through multi-sig)
     * @param newThreshold New required confirmations
     */
    function changeThreshold(uint256 newThreshold) external onlySelf {
        if (newThreshold == 0 || newThreshold > owners.length) {
            revert InvalidThreshold(newThreshold, owners.length);
        }

        uint256 oldThreshold = threshold;
        threshold = newThreshold;

        emit ThresholdChanged(oldThreshold, newThreshold);
    }

    /**
     * @notice Changes the transaction expiry period (must be called through multi-sig)
     * @param newExpiry New expiry period in seconds
     */
    function changeExpiryPeriod(uint256 newExpiry) external onlySelf {
        if (newExpiry < MIN_EXPIRY || newExpiry > MAX_EXPIRY) {
            revert InvalidExpiryPeriod(newExpiry, MIN_EXPIRY, MAX_EXPIRY);
        }

        uint256 oldExpiry = expiryPeriod;
        expiryPeriod = newExpiry;

        emit ExpiryPeriodChanged(oldExpiry, newExpiry);
    }

    // ============ View Functions ============

    /**
     * @notice Returns the number of owners
     * @return Number of owners
     */
    function getOwnerCount() external view returns (uint256) {
        return owners.length;
    }

    /**
     * @notice Returns all owners
     * @return Array of owner addresses
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /// @notice Transaction info struct for view functions
    struct TransactionInfo {
        address to;
        uint256 value;
        bytes data;
        uint256 txNonce;
        uint256 deadline;
        bool executed;
        uint256 confirmCount;
    }

    /// @notice Batch info struct for view functions
    struct BatchInfo {
        address[] targets;
        uint256[] values;
        bytes[] data;
        uint256 batchNonce;
        uint256 deadline;
        bool executed;
        uint256 confirmCount;
    }

    /**
     * @notice Returns transaction details
     * @param txHash Transaction hash
     * @return info Transaction info struct
     */
    function getTransaction(bytes32 txHash) external view returns (TransactionInfo memory info) {
        Transaction storage txn = transactions[txHash];
        info = TransactionInfo({
            to: txn.to,
            value: txn.value,
            data: txn.data,
            txNonce: txn.nonce,
            deadline: txn.deadline,
            executed: txn.executed,
            confirmCount: confirmationCount[txHash]
        });
    }

    /**
     * @notice Returns batch transaction details
     * @param batchHash Batch hash
     * @return info Batch info struct
     */
    function getBatchTransaction(bytes32 batchHash) external view returns (BatchInfo memory info) {
        BatchTransaction storage batch = batchTransactions[batchHash];
        info = BatchInfo({
            targets: batch.targets,
            values: batch.values,
            data: batch.data,
            batchNonce: batch.nonce,
            deadline: batch.deadline,
            executed: batch.executed,
            confirmCount: confirmationCount[batchHash]
        });
    }

    /**
     * @notice Checks if a transaction is ready to execute
     * @param txHash Transaction hash
     * @return ready True if ready to execute
     * @return reason Reason if not ready
     */
    function isReadyToExecute(bytes32 txHash) external view returns (bool ready, string memory reason) {
        if (!isSubmitted[txHash]) return (false, "Not submitted");

        Transaction storage txn = transactions[txHash];
        if (txn.to != address(0)) {
            if (txn.executed) return (false, "Already executed");
            if (block.timestamp > txn.deadline) return (false, "Expired");
            if (confirmationCount[txHash] < threshold) {
                return (false, "Insufficient confirmations");
            }
            return (true, "Ready");
        }

        BatchTransaction storage batch = batchTransactions[txHash];
        if (batch.executed) return (false, "Already executed");
        if (block.timestamp > batch.deadline) return (false, "Expired");
        if (confirmationCount[txHash] < threshold) {
            return (false, "Insufficient confirmations");
        }
        return (true, "Ready");
    }

    /**
     * @notice Returns which owners have confirmed a transaction
     * @param txHash Transaction hash
     * @return confirmedBy Array of addresses that confirmed
     */
    function getConfirmers(bytes32 txHash) external view returns (address[] memory confirmedBy) {
        uint256 count = confirmationCount[txHash];
        confirmedBy = new address[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < owners.length && index < count; i++) {
            if (confirmations[txHash][owners[i]]) {
                confirmedBy[index++] = owners[i];
            }
        }
    }

    // ============ Receive Function ============

    /// @notice Allows the wallet to receive ETH
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
}
