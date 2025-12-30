// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NexusBridge
 * @author Nexus Protocol Team
 * @notice Cross-chain bridge contract implementing lock/mint pattern for Nexus tokens
 * @dev Implements a secure bridge with the following features:
 *      - Lock tokens on source chain, mint on destination
 *      - Burn tokens on destination, unlock on source
 *      - Multi-relayer validation with threshold signatures
 *      - Rate limiting to prevent large-scale exploits
 *      - Emergency pause and circuit breaker mechanisms
 *      - Nonce-based replay protection
 *
 * Security Considerations:
 *      - SEC-011: Rate limiting (configurable daily/hourly limits)
 *      - SEC-013: Comprehensive event emissions for all bridge operations
 *      - Multi-sig relayer validation prevents single point of failure
 *      - Timelock on large transfers
 *      - Emergency pause capability
 *
 * Architecture:
 *      Source Chain: Lock tokens → Emit event → Relayers observe
 *      Destination Chain: Relayers submit proof → Validate → Mint tokens
 *      Return: Burn tokens → Emit event → Relayers observe → Unlock on source
 *
 * @custom:security-contact security@nexusprotocol.io
 */
contract NexusBridge is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============ Constants ============

    /// @notice Role for bridge administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for bridge relayers
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @notice Role for emergency pause
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Minimum relayer threshold
    uint256 public constant MIN_RELAYER_THRESHOLD = 2;

    /// @notice Maximum relayer count
    uint256 public constant MAX_RELAYERS = 20;

    /// @notice Default daily transfer limit (1M tokens with 18 decimals)
    uint256 public constant DEFAULT_DAILY_LIMIT = 1_000_000 * 1e18;

    /// @notice Default single transfer limit (100K tokens)
    uint256 public constant DEFAULT_SINGLE_LIMIT = 100_000 * 1e18;

    /// @notice Large transfer threshold requiring timelock (50K tokens)
    uint256 public constant LARGE_TRANSFER_THRESHOLD = 50_000 * 1e18;

    /// @notice Timelock delay for large transfers (1 hour)
    uint256 public constant LARGE_TRANSFER_DELAY = 1 hours;

    /// @notice Rate limit window (24 hours)
    uint256 public constant RATE_LIMIT_WINDOW = 24 hours;

    // ============ State Variables ============

    /// @notice The bridged token
    IERC20 public immutable token;

    /// @notice Chain ID of this deployment
    uint256 public immutable chainId;

    /// @notice Whether this is the source chain (lock/unlock) or destination (mint/burn)
    bool public immutable isSourceChain;

    /// @notice Required number of relayer signatures
    uint256 public relayerThreshold;

    /// @notice Current daily limit
    uint256 public dailyLimit;

    /// @notice Current single transfer limit
    uint256 public singleTransferLimit;

    /// @notice Total amount transferred in current window
    uint256 public currentWindowTotal;

    /// @notice Start of current rate limit window
    uint256 public windowStart;

    /// @notice Outbound nonce (incremented for each bridge out)
    uint256 public outboundNonce;

    /// @notice Mapping of processed inbound transfers (chainId => nonce => processed)
    mapping(uint256 => mapping(uint256 => bool)) public processedTransfers;

    /// @notice Pending large transfers (transferId => unlock timestamp)
    mapping(bytes32 => uint256) public pendingLargeTransfers;

    /// @notice Supported destination chains
    mapping(uint256 => bool) public supportedChains;

    /// @notice Bridge transfer details
    struct BridgeTransfer {
        address sender;
        address recipient;
        uint256 amount;
        uint256 sourceChain;
        uint256 destChain;
        uint256 nonce;
        uint256 timestamp;
    }

    // ============ Events - SEC-013 ============

    /// @notice Emitted when bridge is initialized
    event BridgeInitialized(
        address indexed token,
        uint256 chainId,
        bool isSourceChain,
        uint256 relayerThreshold
    );

    /// @notice Emitted when tokens are locked (source chain)
    event TokensLocked(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destChain,
        uint256 nonce
    );

    /// @notice Emitted when tokens are unlocked (source chain)
    event TokensUnlocked(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 nonce
    );

    /// @notice Emitted when tokens are minted (destination chain)
    event TokensMinted(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 nonce
    );

    /// @notice Emitted when tokens are burned (destination chain)
    event TokensBurned(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destChain,
        uint256 nonce
    );

    /// @notice Emitted when a large transfer is queued
    event LargeTransferQueued(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 amount,
        uint256 unlockTime
    );

    /// @notice Emitted when a large transfer is executed
    event LargeTransferExecuted(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 amount
    );

    /// @notice Emitted when a large transfer is cancelled
    event LargeTransferCancelled(bytes32 indexed transferId);

    /// @notice Emitted when relayer threshold is updated
    event RelayerThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /// @notice Emitted when daily limit is updated
    event DailyLimitUpdated(uint256 oldLimit, uint256 newLimit);

    /// @notice Emitted when a chain is added/removed
    event ChainSupportUpdated(uint256 indexed chainId, bool supported);

    // ============ Errors ============

    error InvalidToken();
    error InvalidChainId();
    error InvalidThreshold();
    error InvalidAmount();
    error InvalidRecipient();
    error UnsupportedChain();
    error TransferAlreadyProcessed();
    error InsufficientSignatures();
    error InvalidSignature();
    error DailyLimitExceeded();
    error SingleTransferLimitExceeded();
    error TransferNotPending();
    error TransferStillLocked();
    error NotSourceChain();
    error NotDestinationChain();

    // ============ Constructor ============

    /**
     * @notice Initializes the bridge contract
     * @param _token Address of the bridged token
     * @param _chainId Chain ID of this deployment
     * @param _isSourceChain Whether this is the source chain
     * @param _relayerThreshold Required number of relayer signatures
     * @param _relayers Initial relayer addresses
     */
    constructor(
        address _token,
        uint256 _chainId,
        bool _isSourceChain,
        uint256 _relayerThreshold,
        address[] memory _relayers
    ) {
        if (_token == address(0)) revert InvalidToken();
        if (_chainId == 0) revert InvalidChainId();
        if (_relayerThreshold < MIN_RELAYER_THRESHOLD) revert InvalidThreshold();
        if (_relayers.length < _relayerThreshold) revert InvalidThreshold();

        token = IERC20(_token);
        chainId = _chainId;
        isSourceChain = _isSourceChain;
        relayerThreshold = _relayerThreshold;
        dailyLimit = DEFAULT_DAILY_LIMIT;
        singleTransferLimit = DEFAULT_SINGLE_LIMIT;
        windowStart = block.timestamp;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);

        // Add relayers
        for (uint256 i = 0; i < _relayers.length; i++) {
            _grantRole(RELAYER_ROLE, _relayers[i]);
        }

        emit BridgeInitialized(_token, _chainId, _isSourceChain, _relayerThreshold);
    }

    // ============ External Functions - Source Chain ============

    /**
     * @notice Lock tokens to bridge to another chain
     * @param recipient Address to receive tokens on destination chain
     * @param amount Amount of tokens to bridge
     * @param destChain Destination chain ID
     * @return transferId Unique transfer identifier
     */
    function lockTokens(
        address recipient,
        uint256 amount,
        uint256 destChain
    ) external nonReentrant whenNotPaused returns (bytes32 transferId) {
        if (!isSourceChain) revert NotSourceChain();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (!supportedChains[destChain]) revert UnsupportedChain();

        // Check limits
        _checkAndUpdateLimits(amount);

        // Generate transfer ID
        uint256 currentNonce = outboundNonce++;
        transferId = keccak256(abi.encode(
            msg.sender,
            recipient,
            amount,
            chainId,
            destChain,
            currentNonce,
            block.timestamp
        ));

        // Transfer tokens to bridge
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit TokensLocked(
            transferId,
            msg.sender,
            recipient,
            amount,
            destChain,
            currentNonce
        );
    }

    /**
     * @notice Unlock tokens returning from another chain
     * @param recipient Address to receive unlocked tokens
     * @param amount Amount to unlock
     * @param sourceChain Chain ID where tokens were burned
     * @param nonce Transfer nonce from source chain
     * @param signatures Relayer signatures validating the transfer
     */
    function unlockTokens(
        address recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 nonce,
        bytes[] calldata signatures
    ) external nonReentrant whenNotPaused {
        if (!isSourceChain) revert NotSourceChain();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (processedTransfers[sourceChain][nonce]) revert TransferAlreadyProcessed();

        // Generate transfer ID and verify signatures
        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            sourceChain,
            chainId,
            nonce
        ));

        _verifySignatures(transferId, signatures);

        // Mark as processed
        processedTransfers[sourceChain][nonce] = true;

        // Handle large transfers
        if (amount >= LARGE_TRANSFER_THRESHOLD) {
            uint256 unlockTime = block.timestamp + LARGE_TRANSFER_DELAY;
            pendingLargeTransfers[transferId] = unlockTime;
            emit LargeTransferQueued(transferId, recipient, amount, unlockTime);
            return;
        }

        // Transfer tokens
        token.safeTransfer(recipient, amount);

        emit TokensUnlocked(transferId, recipient, amount, sourceChain, nonce);
    }

    // ============ External Functions - Destination Chain ============

    /**
     * @notice Mint tokens bridged from source chain
     * @dev Only callable on destination chain
     * @param recipient Address to receive minted tokens
     * @param amount Amount to mint
     * @param sourceChain Chain ID where tokens were locked
     * @param nonce Transfer nonce from source chain
     * @param signatures Relayer signatures validating the transfer
     */
    function mintTokens(
        address recipient,
        uint256 amount,
        uint256 sourceChain,
        uint256 nonce,
        bytes[] calldata signatures
    ) external nonReentrant whenNotPaused {
        if (isSourceChain) revert NotDestinationChain();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (processedTransfers[sourceChain][nonce]) revert TransferAlreadyProcessed();

        // Generate transfer ID and verify signatures
        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            sourceChain,
            chainId,
            nonce
        ));

        _verifySignatures(transferId, signatures);

        // Mark as processed
        processedTransfers[sourceChain][nonce] = true;

        // Handle large transfers
        if (amount >= LARGE_TRANSFER_THRESHOLD) {
            uint256 unlockTime = block.timestamp + LARGE_TRANSFER_DELAY;
            pendingLargeTransfers[transferId] = unlockTime;
            emit LargeTransferQueued(transferId, recipient, amount, unlockTime);
            return;
        }

        // For destination chain, we assume token has mint capability
        // In production, use a mintable token interface
        token.safeTransfer(recipient, amount);

        emit TokensMinted(transferId, recipient, amount, sourceChain, nonce);
    }

    /**
     * @notice Burn tokens to bridge back to source chain
     * @param recipient Address to receive tokens on source chain
     * @param amount Amount of tokens to burn
     * @return transferId Unique transfer identifier
     */
    function burnTokens(
        address recipient,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (bytes32 transferId) {
        if (isSourceChain) revert NotDestinationChain();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        // Check limits
        _checkAndUpdateLimits(amount);

        // Generate transfer ID
        uint256 currentNonce = outboundNonce++;
        uint256 destChain = 1; // Assuming source chain is mainnet (chain 1)

        transferId = keccak256(abi.encode(
            msg.sender,
            recipient,
            amount,
            chainId,
            destChain,
            currentNonce,
            block.timestamp
        ));

        // Transfer tokens to bridge (to be burned or held)
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit TokensBurned(
            transferId,
            msg.sender,
            recipient,
            amount,
            destChain,
            currentNonce
        );
    }

    // ============ Large Transfer Execution ============

    /**
     * @notice Execute a pending large transfer after timelock
     * @param transferId The transfer ID
     * @param recipient The recipient address
     * @param amount The transfer amount
     */
    function executeLargeTransfer(
        bytes32 transferId,
        address recipient,
        uint256 amount
    ) external nonReentrant {
        uint256 unlockTime = pendingLargeTransfers[transferId];
        if (unlockTime == 0) revert TransferNotPending();
        if (block.timestamp < unlockTime) revert TransferStillLocked();

        delete pendingLargeTransfers[transferId];

        token.safeTransfer(recipient, amount);

        emit LargeTransferExecuted(transferId, recipient, amount);
    }

    /**
     * @notice Cancel a pending large transfer (admin only)
     * @param transferId The transfer ID to cancel
     */
    function cancelLargeTransfer(bytes32 transferId) external onlyRole(ADMIN_ROLE) {
        if (pendingLargeTransfers[transferId] == 0) revert TransferNotPending();

        delete pendingLargeTransfers[transferId];

        emit LargeTransferCancelled(transferId);
    }

    // ============ Admin Functions ============

    /**
     * @notice Add support for a destination chain
     * @param _chainId Chain ID to add
     */
    function addSupportedChain(uint256 _chainId) external onlyRole(ADMIN_ROLE) {
        supportedChains[_chainId] = true;
        emit ChainSupportUpdated(_chainId, true);
    }

    /**
     * @notice Remove support for a destination chain
     * @param _chainId Chain ID to remove
     */
    function removeSupportedChain(uint256 _chainId) external onlyRole(ADMIN_ROLE) {
        supportedChains[_chainId] = false;
        emit ChainSupportUpdated(_chainId, false);
    }

    /**
     * @notice Update the relayer threshold
     * @param newThreshold New required signature count
     */
    function updateRelayerThreshold(uint256 newThreshold) external onlyRole(ADMIN_ROLE) {
        if (newThreshold < MIN_RELAYER_THRESHOLD) revert InvalidThreshold();

        uint256 oldThreshold = relayerThreshold;
        relayerThreshold = newThreshold;

        emit RelayerThresholdUpdated(oldThreshold, newThreshold);
    }

    /**
     * @notice Update the daily transfer limit
     * @param newLimit New daily limit
     */
    function updateDailyLimit(uint256 newLimit) external onlyRole(ADMIN_ROLE) {
        uint256 oldLimit = dailyLimit;
        dailyLimit = newLimit;

        emit DailyLimitUpdated(oldLimit, newLimit);
    }

    /**
     * @notice Update the single transfer limit
     * @param newLimit New single transfer limit
     */
    function updateSingleTransferLimit(uint256 newLimit) external onlyRole(ADMIN_ROLE) {
        singleTransferLimit = newLimit;
    }

    /**
     * @notice Pause the bridge (guardian)
     */
    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the bridge (admin)
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdraw tokens (admin only, when paused)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address to,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) whenPaused {
        token.safeTransfer(to, amount);
    }

    // ============ View Functions ============

    /**
     * @notice Get remaining daily limit
     * @return Remaining amount that can be bridged today
     */
    function getRemainingDailyLimit() external view returns (uint256) {
        if (block.timestamp >= windowStart + RATE_LIMIT_WINDOW) {
            return dailyLimit;
        }
        if (currentWindowTotal >= dailyLimit) {
            return 0;
        }
        return dailyLimit - currentWindowTotal;
    }

    /**
     * @notice Check if a transfer has been processed
     * @param sourceChain Source chain ID
     * @param nonce Transfer nonce
     * @return True if processed
     */
    function isTransferProcessed(
        uint256 sourceChain,
        uint256 nonce
    ) external view returns (bool) {
        return processedTransfers[sourceChain][nonce];
    }

    /**
     * @notice Get bridge configuration
     * @return _chainId This chain's ID
     * @return _isSourceChain Whether this is source chain
     * @return _relayerThreshold Required signatures
     * @return _dailyLimit Daily transfer limit
     * @return _singleLimit Single transfer limit
     */
    function getBridgeConfig()
        external
        view
        returns (
            uint256 _chainId,
            bool _isSourceChain,
            uint256 _relayerThreshold,
            uint256 _dailyLimit,
            uint256 _singleLimit
        )
    {
        return (chainId, isSourceChain, relayerThreshold, dailyLimit, singleTransferLimit);
    }

    // ============ Internal Functions ============

    /**
     * @notice Check and update rate limits
     * @param amount Amount being transferred
     */
    function _checkAndUpdateLimits(uint256 amount) internal {
        if (amount > singleTransferLimit) revert SingleTransferLimitExceeded();

        // Reset window if expired
        if (block.timestamp >= windowStart + RATE_LIMIT_WINDOW) {
            windowStart = block.timestamp;
            currentWindowTotal = 0;
        }

        if (currentWindowTotal + amount > dailyLimit) revert DailyLimitExceeded();

        currentWindowTotal += amount;
    }

    /**
     * @notice Verify relayer signatures
     * @param messageHash Hash of the transfer data
     * @param signatures Array of relayer signatures
     */
    function _verifySignatures(
        bytes32 messageHash,
        bytes[] calldata signatures
    ) internal view {
        if (signatures.length < relayerThreshold) revert InsufficientSignatures();

        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address lastSigner = address(0);

        for (uint256 i = 0; i < relayerThreshold; i++) {
            address signer = ethSignedHash.recover(signatures[i]);

            // Ensure signers are unique and in ascending order
            if (signer <= lastSigner) revert InvalidSignature();
            if (!hasRole(RELAYER_ROLE, signer)) revert InvalidSignature();

            lastSigner = signer;
        }
    }

    // ============ Receive Function ============

    /// @notice Reject direct ETH transfers
    receive() external payable {
        revert();
    }
}
