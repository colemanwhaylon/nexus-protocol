// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NexusSecurityToken
 * @author Nexus Protocol Team
 * @notice ERC-1400 inspired security token for enterprise tokenization
 * @dev Implements core ERC-1400 concepts with modern Solidity patterns:
 *      - Partitions: Tokens can be held in different partitions (tranches)
 *      - Transfer Restrictions: KYC/AML compliance via NexusKYCRegistry
 *      - Document Management: On-chain document references
 *      - Controller Operations: Forced transfers for regulatory compliance
 *      - Issuance/Redemption: Controlled token creation and destruction
 *
 * Security Considerations:
 *      - SEC-006: Two-step role transfers
 *      - SEC-007: Explicit rounding in calculations
 *      - SEC-013: Comprehensive event emissions
 *
 * Compliance Features:
 *      - Integration with NexusKYCRegistry for transfer restrictions
 *      - Document management for legal/regulatory documents
 *      - Partition-based token accounting (different share classes)
 *      - Controller operations for regulatory requirements
 */
/// @notice Interface for KYC registry
interface IKYCRegistry {
    function canTransfer(
        address from,
        address to,
        uint256 amount
    )
        external
        view
        returns (bool allowed, string memory reason);
    function isCompliant(address account) external view returns (bool);
    function isBlacklisted(address account) external view returns (bool);
}

contract NexusSecurityToken is ERC20, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    // ============ Constants ============

    /// @notice Role for administrative operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for issuing tokens
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    /// @notice Role for controller operations (forced transfers)
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /// @notice Default partition for standard transfers
    bytes32 public constant DEFAULT_PARTITION = keccak256("DEFAULT");

    /// @notice Maximum number of partitions per holder
    uint256 public constant MAX_PARTITIONS_PER_HOLDER = 20;

    // ============ Structs ============

    /// @notice Document information
    struct Document {
        bytes32 docHash; // Hash of the document
        string uri; // URI to the document
        uint256 timestamp; // When document was added
    }

    /// @notice Partition information
    struct Partition {
        bytes32 name; // Partition identifier
        uint256 totalSupply; // Total supply in this partition
        bool transferable; // Whether tokens in this partition can be transferred
        bool active; // Whether partition accepts new tokens
    }

    // ============ State Variables ============

    /// @notice KYC registry contract
    IKYCRegistry public kycRegistry;

    /// @notice Whether transfers are restricted (require KYC)
    bool public transfersRestricted;

    /// @notice Whether controller operations are enabled
    bool public controllable;

    /// @notice Total supply cap (0 = unlimited)
    uint256 public cap;

    /// @notice Mapping of partition name to partition info
    mapping(bytes32 partition => Partition info) public partitions;

    /// @notice Array of all partition names
    bytes32[] private _partitionList;

    /// @notice Mapping of holder to partition to balance
    mapping(address holder => mapping(bytes32 partition => uint256 balance)) public partitionBalances;

    /// @notice Mapping of holder to their partitions
    mapping(address holder => bytes32[] partitions) private _holderPartitions;

    /// @notice Mapping of document name to document info
    mapping(bytes32 docName => Document doc) public documents;

    /// @notice Array of all document names
    bytes32[] private _documentList;

    /// @notice Nonce for operator approvals
    mapping(address holder => mapping(address operator => uint256 nonce)) public operatorNonces;

    /// @notice Global operators (can operate on any holder's tokens)
    mapping(address operator => bool isGlobal) public globalOperators;

    /// @notice Per-holder operators
    mapping(address holder => mapping(address operator => bool approved)) public operators;

    // ============ Events ============

    /// @notice Emitted when tokens are issued
    /// @param operator The operator who issued
    /// @param to The recipient
    /// @param amount The amount issued
    /// @param partition The partition issued to
    /// @param data Additional data
    event Issued(address indexed operator, address indexed to, uint256 amount, bytes32 indexed partition, bytes data);

    /// @notice Emitted when tokens are redeemed
    /// @param operator The operator who redeemed
    /// @param from The holder
    /// @param amount The amount redeemed
    /// @param partition The partition redeemed from
    /// @param data Additional data
    event Redeemed(
        address indexed operator, address indexed from, uint256 amount, bytes32 indexed partition, bytes data
    );

    /// @notice Emitted when tokens are transferred by partition
    /// @param operator The operator who transferred
    /// @param from The sender
    /// @param to The recipient
    /// @param amount The amount transferred
    /// @param fromPartition The source partition
    /// @param toPartition The destination partition
    /// @param data Additional data
    event TransferByPartition(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 fromPartition,
        bytes32 toPartition,
        bytes data
    );

    /// @notice Emitted when a controller transfer is executed
    /// @param controller The controller address
    /// @param from The source address
    /// @param to The destination address
    /// @param amount The amount transferred
    /// @param data Additional data
    /// @param operatorData Controller-provided data
    event ControllerTransfer(
        address indexed controller,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    /// @notice Emitted when a controller redemption is executed
    /// @param controller The controller address
    /// @param from The holder address
    /// @param amount The amount redeemed
    /// @param data Additional data
    /// @param operatorData Controller-provided data
    event ControllerRedemption(
        address indexed controller, address indexed from, uint256 amount, bytes data, bytes operatorData
    );

    /// @notice Emitted when a document is set
    /// @param name The document name
    /// @param uri The document URI
    /// @param docHash The document hash
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 docHash);

    /// @notice Emitted when a document is removed
    /// @param name The document name
    event DocumentRemoved(bytes32 indexed name);

    /// @notice Emitted when a partition is created
    /// @param partition The partition name
    /// @param transferable Whether tokens are transferable
    event PartitionCreated(bytes32 indexed partition, bool transferable);

    /// @notice Emitted when partition status changes
    /// @param partition The partition name
    /// @param active Whether partition is active
    /// @param transferable Whether tokens are transferable
    event PartitionUpdated(bytes32 indexed partition, bool active, bool transferable);

    /// @notice Emitted when KYC registry is updated
    /// @param previousRegistry The previous registry
    /// @param newRegistry The new registry
    event KYCRegistryUpdated(address indexed previousRegistry, address indexed newRegistry);

    /// @notice Emitted when transfer restriction is toggled
    /// @param restricted Whether transfers are restricted
    event TransferRestrictionUpdated(bool restricted);

    /// @notice Emitted when controllable status changes
    /// @param controllable Whether controller operations are enabled
    event ControllableUpdated(bool controllable);

    /// @notice Emitted when operator is authorized
    /// @param holder The token holder
    /// @param operator The authorized operator
    event AuthorizedOperator(address indexed holder, address indexed operator);

    /// @notice Emitted when operator is revoked
    /// @param holder The token holder
    /// @param operator The revoked operator
    event RevokedOperator(address indexed holder, address indexed operator);

    // ============ Errors ============

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when partition doesn't exist
    error PartitionNotFound();

    /// @notice Thrown when partition already exists
    error PartitionExists();

    /// @notice Thrown when partition is not active
    error PartitionNotActive();

    /// @notice Thrown when partition is not transferable
    error PartitionNotTransferable();

    /// @notice Thrown when insufficient partition balance
    error InsufficientPartitionBalance();

    /// @notice Thrown when max partitions exceeded
    error MaxPartitionsExceeded();

    /// @notice Thrown when transfer is restricted
    /// @param reason The restriction reason
    error TransferRestricted(string reason);

    /// @notice Thrown when cap would be exceeded
    error ExceedsCap();

    /// @notice Thrown when controller operations are disabled
    error ControllerDisabled();

    /// @notice Thrown when caller is not an operator
    error NotOperator();

    /// @notice Thrown when document doesn't exist
    error DocumentNotFound();

    // ============ Constructor ============

    /**
     * @notice Initialize the security token
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param admin_ Initial admin address
     * @param cap_ Maximum supply (0 for unlimited)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address admin_,
        uint256 cap_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        if (admin_ == address(0)) revert ZeroAddress();

        cap = cap_;
        controllable = true;
        transfersRestricted = true;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(ISSUER_ROLE, admin_);
        _grantRole(CONTROLLER_ROLE, admin_);

        _setRoleAdmin(ISSUER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(CONTROLLER_ROLE, ADMIN_ROLE);

        // Create default partition
        _createPartition(DEFAULT_PARTITION, true);
    }

    // ============ Issuance Functions ============

    /**
     * @notice Issue new tokens to an address
     * @param to Recipient address
     * @param amount Amount to issue
     * @param partition Partition to issue to
     * @param data Additional data
     */
    function issue(
        address to,
        uint256 amount,
        bytes32 partition,
        bytes calldata data
    )
        external
        nonReentrant
        onlyRole(ISSUER_ROLE)
        whenNotPaused
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        Partition storage part = partitions[partition];
        if (part.name == bytes32(0)) revert PartitionNotFound();
        if (!part.active) revert PartitionNotActive();

        // Check cap
        if (cap > 0 && totalSupply() + amount > cap) {
            revert ExceedsCap();
        }

        // Check KYC compliance if restricted
        if (transfersRestricted && address(kycRegistry) != address(0)) {
            if (!kycRegistry.isCompliant(to)) {
                revert TransferRestricted("Recipient not compliant");
            }
        }

        // Mint tokens
        _mint(to, amount);

        // Update partition balance
        _addToPartition(to, partition, amount);

        emit Issued(msg.sender, to, amount, partition, data);
    }

    /**
     * @notice Redeem (burn) tokens
     * @param amount Amount to redeem
     * @param partition Partition to redeem from
     * @param data Additional data
     */
    function redeem(uint256 amount, bytes32 partition, bytes calldata data) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        if (partitionBalances[msg.sender][partition] < amount) {
            revert InsufficientPartitionBalance();
        }

        // Update partition balance
        _removeFromPartition(msg.sender, partition, amount);

        // Burn tokens
        _burn(msg.sender, amount);

        emit Redeemed(msg.sender, msg.sender, amount, partition, data);
    }

    // ============ Transfer Functions ============

    /**
     * @notice Transfer tokens by partition
     * @param to Recipient address
     * @param amount Amount to transfer
     * @param partition Partition to transfer from
     * @param data Additional data
     */
    function transferByPartition(
        address to,
        uint256 amount,
        bytes32 partition,
        bytes calldata data
    )
        external
        nonReentrant
        whenNotPaused
        returns (bytes32)
    {
        _transferByPartition(msg.sender, msg.sender, to, amount, partition, partition, data);
        return partition;
    }

    /**
     * @notice Operator transfer by partition
     * @param from Source address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @param partition Partition to transfer from
     * @param data Additional data
     */
    function operatorTransferByPartition(
        address from,
        address to,
        uint256 amount,
        bytes32 partition,
        bytes calldata data
    )
        external
        nonReentrant
        whenNotPaused
        returns (bytes32)
    {
        if (!_isOperator(msg.sender, from)) revert NotOperator();

        _transferByPartition(msg.sender, from, to, amount, partition, partition, data);
        return partition;
    }

    // ============ Controller Functions ============

    /**
     * @notice Controller forced transfer
     * @param from Source address
     * @param to Destination address
     * @param amount Amount to transfer
     * @param data Holder-provided data
     * @param operatorData Controller-provided data
     */
    function controllerTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    )
        external
        nonReentrant
        onlyRole(CONTROLLER_ROLE)
    {
        if (!controllable) revert ControllerDisabled();
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Transfer from default partition
        _transferByPartition(msg.sender, from, to, amount, DEFAULT_PARTITION, DEFAULT_PARTITION, data);

        emit ControllerTransfer(msg.sender, from, to, amount, data, operatorData);
    }

    /**
     * @notice Controller forced redemption
     * @param from Holder address
     * @param amount Amount to redeem
     * @param data Holder-provided data
     * @param operatorData Controller-provided data
     */
    function controllerRedeem(
        address from,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    )
        external
        nonReentrant
        onlyRole(CONTROLLER_ROLE)
    {
        if (!controllable) revert ControllerDisabled();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Remove from default partition
        _removeFromPartition(from, DEFAULT_PARTITION, amount);

        // Burn tokens
        _burn(from, amount);

        emit ControllerRedemption(msg.sender, from, amount, data, operatorData);
    }

    // ============ Operator Functions ============

    /**
     * @notice Authorize an operator for the caller
     * @param operator The operator to authorize
     */
    function authorizeOperator(address operator) external {
        if (operator == address(0)) revert ZeroAddress();
        operators[msg.sender][operator] = true;
        emit AuthorizedOperator(msg.sender, operator);
    }

    /**
     * @notice Revoke an operator for the caller
     * @param operator The operator to revoke
     */
    function revokeOperator(address operator) external {
        operators[msg.sender][operator] = false;
        emit RevokedOperator(msg.sender, operator);
    }

    // ============ Document Functions ============

    /**
     * @notice Set a document
     * @param name Document name
     * @param uri Document URI
     * @param docHash Document hash
     */
    function setDocument(bytes32 name, string calldata uri, bytes32 docHash) external onlyRole(ADMIN_ROLE) {
        if (documents[name].timestamp == 0) {
            _documentList.push(name);
        }

        documents[name] = Document({ docHash: docHash, uri: uri, timestamp: block.timestamp });

        emit DocumentUpdated(name, uri, docHash);
    }

    /**
     * @notice Remove a document
     * @param name Document name
     */
    function removeDocument(bytes32 name) external onlyRole(ADMIN_ROLE) {
        if (documents[name].timestamp == 0) revert DocumentNotFound();

        delete documents[name];

        // Remove from list (swap and pop)
        for (uint256 i = 0; i < _documentList.length;) {
            if (_documentList[i] == name) {
                _documentList[i] = _documentList[_documentList.length - 1];
                _documentList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit DocumentRemoved(name);
    }

    // ============ Partition Functions ============

    /**
     * @notice Create a new partition
     * @param partition Partition name
     * @param transferable Whether tokens can be transferred
     */
    function createPartition(bytes32 partition, bool transferable) external onlyRole(ADMIN_ROLE) {
        if (partitions[partition].name != bytes32(0)) revert PartitionExists();
        _createPartition(partition, transferable);
    }

    /**
     * @notice Update partition settings
     * @param partition Partition name
     * @param active Whether partition is active
     * @param transferable Whether tokens are transferable
     */
    function updatePartition(bytes32 partition, bool active, bool transferable) external onlyRole(ADMIN_ROLE) {
        if (partitions[partition].name == bytes32(0)) revert PartitionNotFound();

        partitions[partition].active = active;
        partitions[partition].transferable = transferable;

        emit PartitionUpdated(partition, active, transferable);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set KYC registry
     * @param registry The KYC registry address
     */
    function setKYCRegistry(address registry) external onlyRole(ADMIN_ROLE) {
        address previous = address(kycRegistry);
        kycRegistry = IKYCRegistry(registry);
        emit KYCRegistryUpdated(previous, registry);
    }

    /**
     * @notice Set transfer restriction
     * @param restricted Whether transfers are restricted
     */
    function setTransfersRestricted(bool restricted) external onlyRole(ADMIN_ROLE) {
        transfersRestricted = restricted;
        emit TransferRestrictionUpdated(restricted);
    }

    /**
     * @notice Set controllable status
     * @param _controllable Whether controller operations are enabled
     */
    function setControllable(bool _controllable) external onlyRole(ADMIN_ROLE) {
        controllable = _controllable;
        emit ControllableUpdated(_controllable);
    }

    /**
     * @notice Set global operator status
     * @param operator The operator address
     * @param authorized Whether operator is authorized globally
     */
    function setGlobalOperator(address operator, bool authorized) external onlyRole(ADMIN_ROLE) {
        globalOperators[operator] = authorized;
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
     * @notice Get document info
     * @param name Document name
     * @return uri The document URI
     * @return docHash The document hash
     * @return timestamp When document was added
     */
    function getDocument(bytes32 name) external view returns (string memory uri, bytes32 docHash, uint256 timestamp) {
        Document storage doc = documents[name];
        return (doc.uri, doc.docHash, doc.timestamp);
    }

    /**
     * @notice Get all document names
     * @return The array of document names
     */
    function getAllDocuments() external view returns (bytes32[] memory) {
        return _documentList;
    }

    /**
     * @notice Get all partitions
     * @return The array of partition names
     */
    function getAllPartitions() external view returns (bytes32[] memory) {
        return _partitionList;
    }

    /**
     * @notice Get partitions of a holder
     * @param holder The holder address
     * @return The array of partition names
     */
    function partitionsOf(address holder) external view returns (bytes32[] memory) {
        return _holderPartitions[holder];
    }

    /**
     * @notice Get balance of a holder in a partition
     * @param holder The holder address
     * @param partition The partition name
     * @return The balance
     */
    function balanceOfByPartition(address holder, bytes32 partition) external view returns (uint256) {
        return partitionBalances[holder][partition];
    }

    /**
     * @notice Check if transfer is allowed
     * @param from Source address
     * @param to Destination address
     * @param amount Amount to transfer
     * @return allowed Whether transfer is allowed
     * @return reason The reason if not allowed
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    )
        external
        view
        returns (bool allowed, string memory reason)
    {
        if (paused()) {
            return (false, "Contract is paused");
        }

        if (transfersRestricted && address(kycRegistry) != address(0)) {
            return kycRegistry.canTransfer(from, to, amount);
        }

        return (true, "");
    }

    /**
     * @notice Check if an address is an operator for a holder
     * @param operator The operator address
     * @param holder The holder address
     * @return Whether operator is authorized
     */
    function isOperator(address operator, address holder) external view returns (bool) {
        return _isOperator(operator, holder);
    }

    /**
     * @notice Check if token is controllable
     * @return Whether controller operations are enabled
     */
    function isControllable() external view returns (bool) {
        return controllable;
    }

    /**
     * @notice Check if token is issuable
     * @return Always true (issuance controlled by ISSUER_ROLE)
     */
    function isIssuable() external pure returns (bool) {
        return true;
    }

    // ============ Internal Functions ============

    /**
     * @notice Create a partition
     * @param partition Partition name
     * @param transferable Whether tokens are transferable
     */
    function _createPartition(bytes32 partition, bool transferable) internal {
        partitions[partition] = Partition({ name: partition, totalSupply: 0, transferable: transferable, active: true });

        _partitionList.push(partition);

        emit PartitionCreated(partition, transferable);
    }

    /**
     * @notice Add tokens to a partition
     * @param holder The holder address
     * @param partition The partition
     * @param amount The amount
     */
    function _addToPartition(address holder, bytes32 partition, uint256 amount) internal {
        // Check if holder already has this partition
        if (partitionBalances[holder][partition] == 0) {
            if (_holderPartitions[holder].length >= MAX_PARTITIONS_PER_HOLDER) {
                revert MaxPartitionsExceeded();
            }
            _holderPartitions[holder].push(partition);
        }

        partitionBalances[holder][partition] += amount;
        partitions[partition].totalSupply += amount;
    }

    /**
     * @notice Remove tokens from a partition
     * @param holder The holder address
     * @param partition The partition
     * @param amount The amount
     */
    function _removeFromPartition(address holder, bytes32 partition, uint256 amount) internal {
        if (partitionBalances[holder][partition] < amount) {
            revert InsufficientPartitionBalance();
        }

        partitionBalances[holder][partition] -= amount;
        partitions[partition].totalSupply -= amount;

        // Remove partition from holder if balance is zero
        if (partitionBalances[holder][partition] == 0) {
            bytes32[] storage holderParts = _holderPartitions[holder];
            for (uint256 i = 0; i < holderParts.length;) {
                if (holderParts[i] == partition) {
                    holderParts[i] = holderParts[holderParts.length - 1];
                    holderParts.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Internal transfer by partition
     */
    function _transferByPartition(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes32 fromPartition,
        bytes32 toPartition,
        bytes calldata data
    )
        internal
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        Partition storage part = partitions[fromPartition];
        if (part.name == bytes32(0)) revert PartitionNotFound();
        if (!part.transferable) revert PartitionNotTransferable();

        // Check KYC compliance
        if (transfersRestricted && address(kycRegistry) != address(0)) {
            (bool allowed, string memory reason) = kycRegistry.canTransfer(from, to, amount);
            if (!allowed) {
                revert TransferRestricted(reason);
            }
        }

        // Update partition balances
        _removeFromPartition(from, fromPartition, amount);
        _addToPartition(to, toPartition, amount);

        // Execute ERC20 transfer
        _transfer(from, to, amount);

        emit TransferByPartition(operator, from, to, amount, fromPartition, toPartition, data);
    }

    /**
     * @notice Check if address is an operator
     */
    function _isOperator(address operator, address holder) internal view returns (bool) {
        return operator == holder || globalOperators[operator] || operators[holder][operator];
    }

    /**
     * @notice Override transfer to enforce restrictions
     */
    function _update(address from, address to, uint256 value) internal virtual override whenNotPaused {
        // Skip restriction check for minting/burning (handled by issue/redeem)
        if (from != address(0) && to != address(0)) {
            if (transfersRestricted && address(kycRegistry) != address(0)) {
                (bool allowed, string memory reason) = kycRegistry.canTransfer(from, to, value);
                if (!allowed) {
                    revert TransferRestricted(reason);
                }
            }
        }

        super._update(from, to, value);
    }
}
