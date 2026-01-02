// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NexusKYCRegistry
 * @author Nexus Protocol Team
 * @notice On-chain KYC/AML compliance registry for the Nexus Protocol ecosystem
 * @dev Manages whitelist/blacklist status and KYC verification levels for addresses.
 *      This contract integrates with NexusSecurityToken to enforce transfer restrictions.
 *
 * Features:
 *      - Multi-level KYC status (None, Basic, Enhanced, Accredited)
 *      - Whitelist for approved addresses
 *      - Blacklist for restricted addresses
 *      - Country/jurisdiction restrictions
 *      - Expiring KYC with renewal requirements
 *      - Batch operations for efficiency
 *      - Role-based access (COMPLIANCE_ROLE for KYC management)
 *
 * Security Considerations:
 *      - SEC-006: Two-step role transfers inherited from AccessControl
 *      - SEC-013: Events emitted for all state changes
 */
contract NexusKYCRegistry is AccessControl, Pausable {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Role for administrative operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for compliance officers managing KYC
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    /// @notice Maximum expiry duration (5 years)
    uint256 public constant MAX_EXPIRY_DURATION = 5 * 365 days;

    /// @notice Default KYC expiry duration (1 year)
    uint256 public constant DEFAULT_EXPIRY_DURATION = 365 days;

    // ============ Enums ============

    /// @notice KYC verification levels
    enum KYCLevel {
        None, // 0: No KYC completed
        Basic, // 1: Basic identity verification
        Enhanced, // 2: Enhanced due diligence
        Accredited // 3: Accredited investor verification
    }

    // ============ Structs ============

    /// @notice KYC information for an address
    struct KYCInfo {
        KYCLevel level; // Current KYC level
        uint256 verifiedAt; // Timestamp of verification
        uint256 expiresAt; // Timestamp when KYC expires
        bytes32 countryCode; // ISO 3166-1 alpha-3 country code (hashed)
        bool isWhitelisted; // Whether address is whitelisted
        bool isBlacklisted; // Whether address is blacklisted
        string kycProvider; // KYC provider identifier
        bytes32 kycHash; // Hash of KYC documents/data
    }

    /// @notice Country restriction settings
    struct CountryRestriction {
        bool isRestricted; // Whether country is restricted
        KYCLevel requiredLevel; // Minimum KYC level required
        uint256 maxTransactionAmount; // Maximum transaction amount (0 = unlimited)
    }

    // ============ State Variables ============

    /// @notice Mapping of address to KYC info
    mapping(address account => KYCInfo info) private _kycInfo;

    /// @notice Mapping of country code hash to restrictions
    mapping(bytes32 countryHash => CountryRestriction restriction) public countryRestrictions;

    /// @notice Set of all known whitelisted addresses
    address[] private _whitelistedAddresses;

    /// @notice Mapping to check if address is in whitelist array
    mapping(address account => uint256 index) private _whitelistIndex;

    /// @notice Set of all known blacklisted addresses
    address[] private _blacklistedAddresses;

    /// @notice Mapping to check if address is in blacklist array
    mapping(address account => uint256 index) private _blacklistIndex;

    /// @notice Default required KYC level for transfers
    KYCLevel public defaultRequiredLevel;

    /// @notice Whether KYC is required for all transfers
    bool public kycRequired;

    /// @notice Whether blacklist checking is enabled
    bool public blacklistEnabled;

    /// @notice Fee treasury address for collected fees
    address public feeTreasury;

    /// @notice KYC verification fee in native currency (ETH/MATIC)
    uint256 public kycFeeNative;

    /// @notice KYC verification fee in NEXUS tokens
    uint256 public kycFeeNexus;

    /// @notice NEXUS token contract for fee payments
    IERC20 public nexusToken;

    /// @notice Mapping to track if address has paid for KYC
    mapping(address account => bool hasPaid) public hasPaidKYCFee;

    /// @notice Mapping to track payment method used
    mapping(address account => PaymentMethod method) public paymentMethodUsed;

    /// @notice Total fees collected in native currency
    uint256 public totalNativeFeesCollected;

    /// @notice Total fees collected in NEXUS tokens
    uint256 public totalNexusFeesCollected;

    // ============ Enums ============

    /// @notice Payment methods for KYC fee
    enum PaymentMethod {
        None,
        Native,   // ETH/MATIC
        Nexus,    // NEXUS token
        Stripe,   // Fiat via Stripe (recorded by backend)
        Free      // Fee waived by admin
    }

    // ============ Events ============

    /// @notice Emitted when KYC status is updated
    /// @param account The account address
    /// @param level The new KYC level
    /// @param expiresAt When the KYC expires
    /// @param updatedBy The compliance officer who made the update
    event KYCUpdated(address indexed account, KYCLevel indexed level, uint256 expiresAt, address indexed updatedBy);

    /// @notice Emitted when an address is whitelisted
    /// @param account The whitelisted address
    /// @param addedBy The compliance officer who added it
    event Whitelisted(address indexed account, address indexed addedBy);

    /// @notice Emitted when an address is removed from whitelist
    /// @param account The removed address
    /// @param removedBy The compliance officer who removed it
    event WhitelistRemoved(address indexed account, address indexed removedBy);

    /// @notice Emitted when an address is blacklisted
    /// @param account The blacklisted address
    /// @param reason The reason for blacklisting
    /// @param addedBy The compliance officer who added it
    event Blacklisted(address indexed account, string reason, address indexed addedBy);

    /// @notice Emitted when an address is removed from blacklist
    /// @param account The removed address
    /// @param removedBy The compliance officer who removed it
    event BlacklistRemoved(address indexed account, address indexed removedBy);

    /// @notice Emitted when country restriction is updated
    /// @param countryHash The hashed country code
    /// @param isRestricted Whether the country is restricted
    /// @param requiredLevel The required KYC level
    event CountryRestrictionUpdated(bytes32 indexed countryHash, bool isRestricted, KYCLevel requiredLevel);

    /// @notice Emitted when default required level changes
    /// @param previousLevel The previous required level
    /// @param newLevel The new required level
    event DefaultRequiredLevelUpdated(KYCLevel previousLevel, KYCLevel newLevel);

    /// @notice Emitted when KYC requirement is toggled
    /// @param required Whether KYC is now required
    event KYCRequirementUpdated(bool required);

    /// @notice Emitted when blacklist checking is toggled
    /// @param enabled Whether blacklist checking is enabled
    event BlacklistCheckingUpdated(bool enabled);

    /// @notice Emitted when KYC is revoked
    /// @param account The account whose KYC was revoked
    /// @param revokedBy The compliance officer who revoked it
    /// @param reason The reason for revocation
    event KYCRevoked(address indexed account, address indexed revokedBy, string reason);

    /// @notice Emitted when KYC fee is paid
    /// @param account The account that paid
    /// @param method The payment method used
    /// @param amount The fee amount paid
    event KYCFeePaid(address indexed account, PaymentMethod indexed method, uint256 amount);

    /// @notice Emitted when KYC fee is waived
    /// @param account The account whose fee was waived
    /// @param waivedBy The admin who waived the fee
    event KYCFeeWaived(address indexed account, address indexed waivedBy);

    /// @notice Emitted when fees are updated
    /// @param nativeFee The new native currency fee
    /// @param nexusFee The new NEXUS token fee
    event KYCFeesUpdated(uint256 nativeFee, uint256 nexusFee);

    /// @notice Emitted when fee treasury is updated
    /// @param previousTreasury The previous treasury address
    /// @param newTreasury The new treasury address
    event FeeTreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    /// @notice Emitted when fees are withdrawn
    /// @param to The recipient address
    /// @param nativeAmount Amount of native currency withdrawn
    /// @param nexusAmount Amount of NEXUS tokens withdrawn
    event FeesWithdrawn(address indexed to, uint256 nativeAmount, uint256 nexusAmount);

    /// @notice Emitted when off-chain payment is recorded
    /// @param account The account that paid
    /// @param method The payment method (Stripe)
    /// @param externalId External payment reference
    /// @param recordedBy The compliance officer who recorded it
    event OffChainPaymentRecorded(address indexed account, PaymentMethod indexed method, string externalId, address indexed recordedBy);

    // ============ Errors ============

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when array length is zero
    error EmptyArray();

    /// @notice Thrown when arrays have mismatched lengths
    error ArrayLengthMismatch();

    /// @notice Thrown when KYC level is invalid
    error InvalidKYCLevel();

    /// @notice Thrown when expiry duration is invalid
    error InvalidExpiryDuration();

    /// @notice Thrown when address is already whitelisted
    error AlreadyWhitelisted();

    /// @notice Thrown when address is not whitelisted
    error NotWhitelisted();

    /// @notice Thrown when address is already blacklisted
    error AlreadyBlacklisted();

    /// @notice Thrown when address is not blacklisted
    error NotBlacklisted();

    /// @notice Thrown when address is blacklisted
    error AddressBlacklisted();

    /// @notice Thrown when KYC is required but not met
    /// @param account The account that failed KYC check
    /// @param required The required KYC level
    /// @param actual The actual KYC level
    error KYCNotMet(address account, KYCLevel required, KYCLevel actual);

    /// @notice Thrown when KYC has expired
    /// @param account The account with expired KYC
    /// @param expiredAt When the KYC expired
    error KYCExpired(address account, uint256 expiredAt);

    /// @notice Thrown when country is restricted
    /// @param countryHash The restricted country hash
    error CountryRestricted(bytes32 countryHash);

    /// @notice Thrown when KYC fee has already been paid
    error FeeAlreadyPaid();

    /// @notice Thrown when KYC fee has not been paid
    error FeeNotPaid();

    /// @notice Thrown when insufficient fee is sent
    /// @param sent Amount sent
    /// @param required Amount required
    error InsufficientFee(uint256 sent, uint256 required);

    /// @notice Thrown when fee transfer fails
    error FeeTransferFailed();

    /// @notice Thrown when fee treasury is not set
    error TreasuryNotSet();

    /// @notice Thrown when NEXUS token is not configured
    error NexusTokenNotConfigured();

    // ============ Constructor ============

    /**
     * @notice Initializes the KYC Registry
     * @param admin The initial admin address
     */
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);

        // Set ADMIN_ROLE as admin for COMPLIANCE_ROLE
        _setRoleAdmin(COMPLIANCE_ROLE, ADMIN_ROLE);

        // Enable blacklist by default
        blacklistEnabled = true;

        // KYC not required by default (opt-in)
        kycRequired = false;

        // Default to Basic KYC level
        defaultRequiredLevel = KYCLevel.Basic;
    }

    // ============ External KYC Functions ============

    /**
     * @notice Set KYC status for an address
     * @param account The address to update
     * @param level The KYC level to set
     * @param countryCode The ISO 3166-1 alpha-3 country code
     * @param expiryDuration Duration until KYC expires (0 for default)
     * @param kycProvider The KYC provider identifier
     * @param kycHash Hash of KYC documents/data
     */
    function setKYC(
        address account,
        KYCLevel level,
        string calldata countryCode,
        uint256 expiryDuration,
        string calldata kycProvider,
        bytes32 kycHash
    )
        external
        onlyRole(COMPLIANCE_ROLE)
        whenNotPaused
    {
        if (account == address(0)) revert ZeroAddress();
        if (expiryDuration > MAX_EXPIRY_DURATION) revert InvalidExpiryDuration();

        uint256 duration = expiryDuration == 0 ? DEFAULT_EXPIRY_DURATION : expiryDuration;
        uint256 expiresAt = block.timestamp + duration;
        bytes32 countryHash = keccak256(abi.encodePacked(countryCode));

        KYCInfo storage info = _kycInfo[account];
        info.level = level;
        info.verifiedAt = block.timestamp;
        info.expiresAt = expiresAt;
        info.countryCode = countryHash;
        info.kycProvider = kycProvider;
        info.kycHash = kycHash;

        // Auto-whitelist if KYC level is set above None
        if (level != KYCLevel.None && !info.isWhitelisted) {
            _addToWhitelist(account);
        }

        emit KYCUpdated(account, level, expiresAt, msg.sender);
    }

    /**
     * @notice Batch set KYC for multiple addresses
     * @param accounts The addresses to update
     * @param levels The KYC levels to set
     * @param countryCodes The country codes
     * @param expiryDuration Duration until KYC expires (applied to all)
     */
    function batchSetKYC(
        address[] calldata accounts,
        KYCLevel[] calldata levels,
        string[] calldata countryCodes,
        uint256 expiryDuration
    )
        external
        onlyRole(COMPLIANCE_ROLE)
        whenNotPaused
    {
        if (accounts.length == 0) revert EmptyArray();
        if (accounts.length != levels.length || accounts.length != countryCodes.length) {
            revert ArrayLengthMismatch();
        }
        if (expiryDuration > MAX_EXPIRY_DURATION) revert InvalidExpiryDuration();

        uint256 duration = expiryDuration == 0 ? DEFAULT_EXPIRY_DURATION : expiryDuration;
        uint256 expiresAt = block.timestamp + duration;

        // SAFETY: Loop bounded by input array length which is validated above
        for (uint256 i = 0; i < accounts.length;) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();

            bytes32 countryHash = keccak256(abi.encodePacked(countryCodes[i]));

            KYCInfo storage info = _kycInfo[account];
            info.level = levels[i];
            info.verifiedAt = block.timestamp;
            info.expiresAt = expiresAt;
            info.countryCode = countryHash;

            if (levels[i] != KYCLevel.None && !info.isWhitelisted) {
                _addToWhitelist(account);
            }

            emit KYCUpdated(account, levels[i], expiresAt, msg.sender);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Revoke KYC for an address
     * @param account The address to revoke
     * @param reason The reason for revocation
     */
    function revokeKYC(address account, string calldata reason) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();

        KYCInfo storage info = _kycInfo[account];
        info.level = KYCLevel.None;
        info.expiresAt = 0;

        // Remove from whitelist if whitelisted
        if (info.isWhitelisted) {
            _removeFromWhitelist(account);
        }

        emit KYCRevoked(account, msg.sender, reason);
    }

    // ============ Whitelist Functions ============

    /**
     * @notice Add address to whitelist
     * @param account The address to whitelist
     */
    function addToWhitelist(address account) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();
        if (_kycInfo[account].isWhitelisted) revert AlreadyWhitelisted();

        _addToWhitelist(account);
        emit Whitelisted(account, msg.sender);
    }

    /**
     * @notice Batch add addresses to whitelist
     * @param accounts The addresses to whitelist
     */
    function batchAddToWhitelist(address[] calldata accounts) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (accounts.length == 0) revert EmptyArray();

        for (uint256 i = 0; i < accounts.length;) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();

            if (!_kycInfo[account].isWhitelisted) {
                _addToWhitelist(account);
                emit Whitelisted(account, msg.sender);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Remove address from whitelist
     * @param account The address to remove
     */
    function removeFromWhitelist(address account) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();
        if (!_kycInfo[account].isWhitelisted) revert NotWhitelisted();

        _removeFromWhitelist(account);
        emit WhitelistRemoved(account, msg.sender);
    }

    // ============ Blacklist Functions ============

    /**
     * @notice Add address to blacklist
     * @param account The address to blacklist
     * @param reason The reason for blacklisting
     */
    function addToBlacklist(address account, string calldata reason) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();
        if (_kycInfo[account].isBlacklisted) revert AlreadyBlacklisted();

        _addToBlacklist(account);

        // Remove from whitelist if present
        if (_kycInfo[account].isWhitelisted) {
            _removeFromWhitelist(account);
        }

        emit Blacklisted(account, reason, msg.sender);
    }

    /**
     * @notice Remove address from blacklist
     * @param account The address to remove
     */
    function removeFromBlacklist(address account) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();
        if (!_kycInfo[account].isBlacklisted) revert NotBlacklisted();

        _removeFromBlacklist(account);
        emit BlacklistRemoved(account, msg.sender);
    }

    // ============ Country Restriction Functions ============

    /**
     * @notice Set country restriction
     * @param countryCode The ISO 3166-1 alpha-3 country code
     * @param isRestricted Whether the country is restricted
     * @param requiredLevel The minimum required KYC level
     * @param maxAmount Maximum transaction amount (0 = unlimited)
     */
    function setCountryRestriction(
        string calldata countryCode,
        bool isRestricted,
        KYCLevel requiredLevel,
        uint256 maxAmount
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        bytes32 countryHash = keccak256(abi.encodePacked(countryCode));

        countryRestrictions[countryHash] = CountryRestriction({
            isRestricted: isRestricted, requiredLevel: requiredLevel, maxTransactionAmount: maxAmount
        });

        emit CountryRestrictionUpdated(countryHash, isRestricted, requiredLevel);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set default required KYC level
     * @param level The new default required level
     */
    function setDefaultRequiredLevel(KYCLevel level) external onlyRole(ADMIN_ROLE) {
        KYCLevel previousLevel = defaultRequiredLevel;
        defaultRequiredLevel = level;
        emit DefaultRequiredLevelUpdated(previousLevel, level);
    }

    /**
     * @notice Set whether KYC is required
     * @param required Whether KYC should be required
     */
    function setKYCRequired(bool required) external onlyRole(ADMIN_ROLE) {
        kycRequired = required;
        emit KYCRequirementUpdated(required);
    }

    /**
     * @notice Set whether blacklist checking is enabled
     * @param enabled Whether blacklist checking should be enabled
     */
    function setBlacklistEnabled(bool enabled) external onlyRole(ADMIN_ROLE) {
        blacklistEnabled = enabled;
        emit BlacklistCheckingUpdated(enabled);
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

    // ============ Fee Configuration Functions ============

    /**
     * @notice Set the fee treasury address
     * @param treasury The new treasury address
     */
    function setFeeTreasury(address treasury) external onlyRole(ADMIN_ROLE) {
        if (treasury == address(0)) revert ZeroAddress();
        address previousTreasury = feeTreasury;
        feeTreasury = treasury;
        emit FeeTreasuryUpdated(previousTreasury, treasury);
    }

    /**
     * @notice Set the NEXUS token contract
     * @param token The NEXUS token address
     */
    function setNexusToken(address token) external onlyRole(ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        nexusToken = IERC20(token);
    }

    /**
     * @notice Set KYC verification fees
     * @param nativeFee Fee in native currency (ETH/MATIC)
     * @param nexusFee Fee in NEXUS tokens
     */
    function setKYCFees(uint256 nativeFee, uint256 nexusFee) external onlyRole(ADMIN_ROLE) {
        kycFeeNative = nativeFee;
        kycFeeNexus = nexusFee;
        emit KYCFeesUpdated(nativeFee, nexusFee);
    }

    // ============ Fee Payment Functions ============

    /**
     * @notice Pay KYC fee with native currency (ETH/MATIC)
     * @dev Requires exact fee amount or more. Excess is not refunded.
     */
    function payKYCFeeNative() external payable whenNotPaused {
        if (hasPaidKYCFee[msg.sender]) revert FeeAlreadyPaid();
        if (msg.value < kycFeeNative) revert InsufficientFee(msg.value, kycFeeNative);

        hasPaidKYCFee[msg.sender] = true;
        paymentMethodUsed[msg.sender] = PaymentMethod.Native;
        totalNativeFeesCollected += msg.value;

        emit KYCFeePaid(msg.sender, PaymentMethod.Native, msg.value);
    }

    /**
     * @notice Pay KYC fee with NEXUS tokens
     * @dev Requires prior approval of NEXUS tokens
     */
    function payKYCFeeNexus() external whenNotPaused {
        if (hasPaidKYCFee[msg.sender]) revert FeeAlreadyPaid();
        if (address(nexusToken) == address(0)) revert NexusTokenNotConfigured();

        hasPaidKYCFee[msg.sender] = true;
        paymentMethodUsed[msg.sender] = PaymentMethod.Nexus;
        totalNexusFeesCollected += kycFeeNexus;

        nexusToken.safeTransferFrom(msg.sender, address(this), kycFeeNexus);

        emit KYCFeePaid(msg.sender, PaymentMethod.Nexus, kycFeeNexus);
    }

    /**
     * @notice Record off-chain payment (Stripe, etc.)
     * @param account The account that paid
     * @param externalId External payment reference ID
     */
    function recordOffChainPayment(
        address account,
        string calldata externalId
    ) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();
        if (hasPaidKYCFee[account]) revert FeeAlreadyPaid();

        hasPaidKYCFee[account] = true;
        paymentMethodUsed[account] = PaymentMethod.Stripe;

        emit OffChainPaymentRecorded(account, PaymentMethod.Stripe, externalId, msg.sender);
    }

    /**
     * @notice Waive KYC fee for an account
     * @param account The account to waive fee for
     */
    function waiveKYCFee(address account) external onlyRole(ADMIN_ROLE) whenNotPaused {
        if (account == address(0)) revert ZeroAddress();
        if (hasPaidKYCFee[account]) revert FeeAlreadyPaid();

        hasPaidKYCFee[account] = true;
        paymentMethodUsed[account] = PaymentMethod.Free;

        emit KYCFeeWaived(account, msg.sender);
    }

    /**
     * @notice Batch record off-chain payments
     * @param accounts The accounts that paid
     * @param externalIds External payment reference IDs
     */
    function batchRecordOffChainPayments(
        address[] calldata accounts,
        string[] calldata externalIds
    ) external onlyRole(COMPLIANCE_ROLE) whenNotPaused {
        if (accounts.length == 0) revert EmptyArray();
        if (accounts.length != externalIds.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < accounts.length;) {
            address account = accounts[i];
            if (account != address(0) && !hasPaidKYCFee[account]) {
                hasPaidKYCFee[account] = true;
                paymentMethodUsed[account] = PaymentMethod.Stripe;
                emit OffChainPaymentRecorded(account, PaymentMethod.Stripe, externalIds[i], msg.sender);
            }
            unchecked { ++i; }
        }
    }

    // ============ Fee Withdrawal Functions ============

    /**
     * @notice Withdraw collected fees to treasury
     */
    function withdrawFees() external onlyRole(ADMIN_ROLE) {
        if (feeTreasury == address(0)) revert TreasuryNotSet();

        uint256 nativeBalance = address(this).balance;
        uint256 nexusBalance = address(nexusToken) != address(0)
            ? nexusToken.balanceOf(address(this))
            : 0;

        if (nativeBalance > 0) {
            (bool success, ) = feeTreasury.call{value: nativeBalance}("");
            if (!success) revert FeeTransferFailed();
        }

        if (nexusBalance > 0) {
            nexusToken.safeTransfer(feeTreasury, nexusBalance);
        }

        emit FeesWithdrawn(feeTreasury, nativeBalance, nexusBalance);
    }

    /**
     * @notice Withdraw specific amounts of fees
     * @param nativeAmount Amount of native currency to withdraw
     * @param nexusAmount Amount of NEXUS tokens to withdraw
     */
    function withdrawFeesPartial(uint256 nativeAmount, uint256 nexusAmount) external onlyRole(ADMIN_ROLE) {
        if (feeTreasury == address(0)) revert TreasuryNotSet();

        if (nativeAmount > 0) {
            if (nativeAmount > address(this).balance) revert InsufficientFee(address(this).balance, nativeAmount);
            (bool success, ) = feeTreasury.call{value: nativeAmount}("");
            if (!success) revert FeeTransferFailed();
        }

        if (nexusAmount > 0) {
            if (address(nexusToken) == address(0)) revert NexusTokenNotConfigured();
            nexusToken.safeTransfer(feeTreasury, nexusAmount);
        }

        emit FeesWithdrawn(feeTreasury, nativeAmount, nexusAmount);
    }

    // ============ Verification Functions ============

    /**
     * @notice Check if a transfer is allowed between two addresses
     * @param from Source address
     * @param to Destination address
     * @param amount Transfer amount
     * @return allowed Whether the transfer is allowed
     * @return reason The reason if not allowed (empty if allowed)
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
        // Check blacklist
        if (blacklistEnabled) {
            if (_kycInfo[from].isBlacklisted) {
                return (false, "Sender is blacklisted");
            }
            if (_kycInfo[to].isBlacklisted) {
                return (false, "Recipient is blacklisted");
            }
        }

        // If KYC not required, only check blacklist
        if (!kycRequired) {
            return (true, "");
        }

        // Check KYC for sender
        KYCInfo storage fromInfo = _kycInfo[from];
        if (fromInfo.level < defaultRequiredLevel) {
            return (false, "Sender KYC level insufficient");
        }
        if (fromInfo.expiresAt != 0 && block.timestamp > fromInfo.expiresAt) {
            return (false, "Sender KYC expired");
        }

        // Check KYC for recipient
        KYCInfo storage toInfo = _kycInfo[to];
        if (toInfo.level < defaultRequiredLevel) {
            return (false, "Recipient KYC level insufficient");
        }
        if (toInfo.expiresAt != 0 && block.timestamp > toInfo.expiresAt) {
            return (false, "Recipient KYC expired");
        }

        // Check country restrictions for sender
        CountryRestriction storage fromRestriction = countryRestrictions[fromInfo.countryCode];
        if (fromRestriction.isRestricted) {
            return (false, "Sender country restricted");
        }
        if (fromRestriction.maxTransactionAmount > 0 && amount > fromRestriction.maxTransactionAmount) {
            return (false, "Amount exceeds sender country limit");
        }

        // Check country restrictions for recipient
        CountryRestriction storage toRestriction = countryRestrictions[toInfo.countryCode];
        if (toRestriction.isRestricted) {
            return (false, "Recipient country restricted");
        }
        if (toRestriction.maxTransactionAmount > 0 && amount > toRestriction.maxTransactionAmount) {
            return (false, "Amount exceeds recipient country limit");
        }

        return (true, "");
    }

    /**
     * @notice Check if an address is compliant for transfers
     * @param account The address to check
     * @return Whether the address is compliant
     */
    function isCompliant(address account) external view returns (bool) {
        if (blacklistEnabled && _kycInfo[account].isBlacklisted) {
            return false;
        }

        if (!kycRequired) {
            return true;
        }

        KYCInfo storage info = _kycInfo[account];
        if (info.level < defaultRequiredLevel) {
            return false;
        }
        if (info.expiresAt != 0 && block.timestamp > info.expiresAt) {
            return false;
        }

        CountryRestriction storage restriction = countryRestrictions[info.countryCode];
        if (restriction.isRestricted) {
            return false;
        }

        return true;
    }

    // ============ View Functions ============

    /**
     * @notice Get KYC info for an address
     * @param account The address to query
     * @return level The KYC level
     * @return verifiedAt When KYC was verified
     * @return expiresAt When KYC expires
     * @return countryCode The hashed country code
     * @return isWhitelisted Whether address is whitelisted
     * @return isBlacklisted Whether address is blacklisted
     */
    function getKYCInfo(address account)
        external
        view
        returns (
            KYCLevel level,
            uint256 verifiedAt,
            uint256 expiresAt,
            bytes32 countryCode,
            bool isWhitelisted,
            bool isBlacklisted
        )
    {
        KYCInfo storage info = _kycInfo[account];
        return (info.level, info.verifiedAt, info.expiresAt, info.countryCode, info.isWhitelisted, info.isBlacklisted);
    }

    /**
     * @notice Get KYC level for an address
     * @param account The address to query
     * @return The KYC level
     */
    function getKYCLevel(address account) external view returns (KYCLevel) {
        return _kycInfo[account].level;
    }

    /**
     * @notice Check if address is whitelisted
     * @param account The address to check
     * @return Whether the address is whitelisted
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _kycInfo[account].isWhitelisted;
    }

    /**
     * @notice Check if address is blacklisted
     * @param account The address to check
     * @return Whether the address is blacklisted
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _kycInfo[account].isBlacklisted;
    }

    /**
     * @notice Check if KYC is expired for an address
     * @param account The address to check
     * @return Whether KYC is expired
     */
    function isKYCExpired(address account) external view returns (bool) {
        KYCInfo storage info = _kycInfo[account];
        return info.expiresAt != 0 && block.timestamp > info.expiresAt;
    }

    /**
     * @notice Get count of whitelisted addresses
     * @return The number of whitelisted addresses
     */
    function getWhitelistCount() external view returns (uint256) {
        return _whitelistedAddresses.length;
    }

    /**
     * @notice Get count of blacklisted addresses
     * @return The number of blacklisted addresses
     */
    function getBlacklistCount() external view returns (uint256) {
        return _blacklistedAddresses.length;
    }

    /**
     * @notice Get fee payment status for an account
     * @param account The address to check
     * @return hasPaid Whether the account has paid the KYC fee
     * @return method The payment method used
     */
    function getFeeStatus(address account) external view returns (bool hasPaid, PaymentMethod method) {
        return (hasPaidKYCFee[account], paymentMethodUsed[account]);
    }

    /**
     * @notice Get current KYC fee amounts
     * @return nativeFee Fee in native currency (ETH/MATIC)
     * @return nexusFee Fee in NEXUS tokens
     */
    function getKYCFees() external view returns (uint256 nativeFee, uint256 nexusFee) {
        return (kycFeeNative, kycFeeNexus);
    }

    /**
     * @notice Get total fees collected
     * @return nativeTotal Total native currency collected
     * @return nexusTotal Total NEXUS tokens collected
     */
    function getTotalFeesCollected() external view returns (uint256 nativeTotal, uint256 nexusTotal) {
        return (totalNativeFeesCollected, totalNexusFeesCollected);
    }

    /**
     * @notice Get current fee balances in contract
     * @return nativeBalance Native currency balance
     * @return nexusBalance NEXUS token balance
     */
    function getFeeBalances() external view returns (uint256 nativeBalance, uint256 nexusBalance) {
        nativeBalance = address(this).balance;
        nexusBalance = address(nexusToken) != address(0) ? nexusToken.balanceOf(address(this)) : 0;
    }

    /**
     * @notice Get whitelisted addresses (paginated)
     * @param offset Starting index
     * @param limit Maximum number to return
     * @return addresses The whitelisted addresses
     */
    function getWhitelistedAddresses(uint256 offset, uint256 limit) external view returns (address[] memory addresses) {
        uint256 total = _whitelistedAddresses.length;
        if (offset >= total) {
            return new address[](0);
        }

        uint256 remaining = total - offset;
        uint256 count = remaining < limit ? remaining : limit;

        addresses = new address[](count);
        for (uint256 i = 0; i < count;) {
            addresses[i] = _whitelistedAddresses[offset + i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Get blacklisted addresses (paginated)
     * @param offset Starting index
     * @param limit Maximum number to return
     * @return addresses The blacklisted addresses
     */
    function getBlacklistedAddresses(uint256 offset, uint256 limit) external view returns (address[] memory addresses) {
        uint256 total = _blacklistedAddresses.length;
        if (offset >= total) {
            return new address[](0);
        }

        uint256 remaining = total - offset;
        uint256 count = remaining < limit ? remaining : limit;

        addresses = new address[](count);
        for (uint256 i = 0; i < count;) {
            addresses[i] = _blacklistedAddresses[offset + i];
            unchecked {
                ++i;
            }
        }
    }

    // ============ Internal Functions ============

    /**
     * @notice Internal function to add address to whitelist
     * @param account The address to add
     */
    function _addToWhitelist(address account) internal {
        _kycInfo[account].isWhitelisted = true;
        _whitelistIndex[account] = _whitelistedAddresses.length;
        _whitelistedAddresses.push(account);
    }

    /**
     * @notice Internal function to remove address from whitelist
     * @param account The address to remove
     */
    function _removeFromWhitelist(address account) internal {
        _kycInfo[account].isWhitelisted = false;

        // Swap and pop to remove from array
        uint256 index = _whitelistIndex[account];
        uint256 lastIndex = _whitelistedAddresses.length - 1;

        if (index != lastIndex) {
            address lastAddress = _whitelistedAddresses[lastIndex];
            _whitelistedAddresses[index] = lastAddress;
            _whitelistIndex[lastAddress] = index;
        }

        _whitelistedAddresses.pop();
        delete _whitelistIndex[account];
    }

    /**
     * @notice Internal function to add address to blacklist
     * @param account The address to add
     */
    function _addToBlacklist(address account) internal {
        _kycInfo[account].isBlacklisted = true;
        _blacklistIndex[account] = _blacklistedAddresses.length;
        _blacklistedAddresses.push(account);
    }

    /**
     * @notice Internal function to remove address from blacklist
     * @param account The address to remove
     */
    function _removeFromBlacklist(address account) internal {
        _kycInfo[account].isBlacklisted = false;

        // Swap and pop to remove from array
        uint256 index = _blacklistIndex[account];
        uint256 lastIndex = _blacklistedAddresses.length - 1;

        if (index != lastIndex) {
            address lastAddress = _blacklistedAddresses[lastIndex];
            _blacklistedAddresses[index] = lastAddress;
            _blacklistIndex[lastAddress] = index;
        }

        _blacklistedAddresses.pop();
        delete _blacklistIndex[account];
    }
}
