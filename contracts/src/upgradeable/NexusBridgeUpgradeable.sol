// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NexusBridgeUpgradeable
 * @notice UUPS upgradeable version of NexusBridge
 * @dev Cross-chain bridge with multi-sig verification and rate limiting
 */
contract NexusBridgeUpgradeable is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IERC20 public bridgeToken;
    uint256 public sourceChainId;
    bool public isSourceChain;

    uint256 public relayerThreshold;
    address[] public relayers;
    mapping(address => bool) public isRelayer;

    uint256 public dailyLimit;
    uint256 public singleTransferLimit;
    uint256 public largeTransferThreshold;
    uint256 public largeTransferDelay;

    uint256 public dailyTransferred;
    uint256 public lastResetTime;
    uint256 public outboundNonce;

    mapping(bytes32 => bool) public processedTransfers;
    mapping(bytes32 => uint256) public pendingLargeTransfers;
    mapping(uint256 => bool) public supportedChains;

    event TokensLocked(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 destinationChainId,
        uint256 nonce
    );
    event TokensUnlocked(
        address indexed recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce
    );
    event LargeTransferQueued(bytes32 indexed transferId, uint256 unlockTime);
    event LargeTransferExecuted(bytes32 indexed transferId);
    event LargeTransferCancelled(bytes32 indexed transferId);
    event ChainAdded(uint256 chainId);
    event ChainRemoved(uint256 chainId);

    error UnsupportedChain();
    error SingleTransferLimitExceeded();
    error DailyLimitExceeded();
    error InsufficientSignatures();
    error InvalidSignature();
    error TransferAlreadyProcessed();
    error TransferStillLocked();
    error TransferNotPending();
    error InvalidAmount();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     */
    function initialize(
        address _bridgeToken,
        uint256 _sourceChainId,
        bool _isSourceChain,
        uint256 _relayerThreshold,
        address[] calldata _relayers
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();

        bridgeToken = IERC20(_bridgeToken);
        sourceChainId = _sourceChainId;
        isSourceChain = _isSourceChain;
        relayerThreshold = _relayerThreshold;

        dailyLimit = 1_000_000e18;
        singleTransferLimit = 100_000e18;
        largeTransferThreshold = 50_000e18;
        largeTransferDelay = 1 hours;
        lastResetTime = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        for (uint256 i = 0; i < _relayers.length; i++) {
            relayers.push(_relayers[i]);
            isRelayer[_relayers[i]] = true;
            _grantRole(RELAYER_ROLE, _relayers[i]);
        }
    }

    /**
     * @notice Lock tokens on source chain
     */
    function lockTokens(
        address recipient,
        uint256 amount,
        uint256 destinationChainId
    ) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (!supportedChains[destinationChainId]) revert UnsupportedChain();
        if (amount > singleTransferLimit) revert SingleTransferLimitExceeded();

        _resetDailyLimit();
        if (dailyTransferred + amount > dailyLimit) revert DailyLimitExceeded();

        bridgeToken.safeTransferFrom(msg.sender, address(this), amount);
        dailyTransferred += amount;
        outboundNonce++;

        emit TokensLocked(msg.sender, recipient, amount, destinationChainId, outboundNonce);
    }

    /**
     * @notice Unlock tokens on destination chain
     */
    function unlockTokens(
        address recipient,
        uint256 amount,
        uint256 srcChainId,
        uint256 nonce,
        bytes[] calldata signatures
    ) external nonReentrant whenNotPaused {
        bytes32 transferId = keccak256(abi.encode(recipient, amount, srcChainId, sourceChainId, nonce));

        if (processedTransfers[transferId]) revert TransferAlreadyProcessed();
        _verifySignatures(transferId, signatures);

        processedTransfers[transferId] = true;

        if (amount >= largeTransferThreshold) {
            pendingLargeTransfers[transferId] = block.timestamp + largeTransferDelay;
            emit LargeTransferQueued(transferId, pendingLargeTransfers[transferId]);
        } else {
            bridgeToken.safeTransfer(recipient, amount);
            emit TokensUnlocked(recipient, amount, srcChainId, nonce);
        }
    }

    /**
     * @notice Execute a large transfer after delay
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
        bridgeToken.safeTransfer(recipient, amount);

        emit LargeTransferExecuted(transferId);
    }

    /**
     * @notice Cancel a pending large transfer (admin only)
     */
    function cancelLargeTransfer(bytes32 transferId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (pendingLargeTransfers[transferId] == 0) revert TransferNotPending();
        delete pendingLargeTransfers[transferId];
        emit LargeTransferCancelled(transferId);
    }

    /**
     * @notice Verify signatures from relayers
     */
    function _verifySignatures(bytes32 transferId, bytes[] calldata signatures) internal view {
        if (signatures.length < relayerThreshold) revert InsufficientSignatures();

        bytes32 ethSignedHash = transferId.toEthSignedMessageHash();
        address lastSigner = address(0);

        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ethSignedHash.recover(signatures[i]);

            // Check signer is a relayer and signatures are in order
            if (!isRelayer[signer]) revert InvalidSignature();
            if (signer <= lastSigner) revert InvalidSignature();

            lastSigner = signer;
        }
    }

    /**
     * @notice Reset daily limit if window passed
     */
    function _resetDailyLimit() internal {
        if (block.timestamp >= lastResetTime + 24 hours) {
            dailyTransferred = 0;
            lastResetTime = block.timestamp;
        }
    }

    // Admin functions

    function addSupportedChain(uint256 chainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedChains[chainId] = true;
        emit ChainAdded(chainId);
    }

    function removeSupportedChain(uint256 chainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedChains[chainId] = false;
        emit ChainRemoved(chainId);
    }

    function updateDailyLimit(uint256 _limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyLimit = _limit;
    }

    function updateSingleTransferLimit(uint256 _limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        singleTransferLimit = _limit;
    }

    function updateLargeTransferThreshold(uint256 _threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        largeTransferThreshold = _threshold;
    }

    function updateRelayerThreshold(uint256 _threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_threshold > 0 && _threshold <= relayers.length, "Invalid threshold");
        relayerThreshold = _threshold;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // View functions

    function getBridgeConfig() external view returns (
        uint256 _sourceChainId,
        bool _isSourceChain,
        uint256 _relayerThreshold,
        uint256 _dailyLimit,
        uint256 _singleTransferLimit
    ) {
        return (sourceChainId, isSourceChain, relayerThreshold, dailyLimit, singleTransferLimit);
    }

    function getDailyTransferInfo() external view returns (
        uint256 _dailyTransferred,
        uint256 _dailyLimit,
        uint256 _remaining,
        uint256 _resetTime
    ) {
        uint256 remaining = dailyLimit > dailyTransferred ? dailyLimit - dailyTransferred : 0;
        return (dailyTransferred, dailyLimit, remaining, lastResetTime + 24 hours);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
