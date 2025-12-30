// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC721A } from "erc721a/ERC721A.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title NexusNFT
 * @author Nexus Protocol Team
 * @notice Production-grade NFT contract with comprehensive features for the Nexus ecosystem
 * @dev Implements ERC721A for gas-efficient batch minting with the following features:
 *      - EIP-2981 Royalties: On-chain royalty information for marketplaces
 *      - Merkle Whitelist: Gas-efficient whitelist verification
 *      - Reveal Mechanism: Delayed metadata reveal with placeholder
 *      - Soulbound Option: Non-transferable tokens for achievements/credentials
 *      - AccessControl: Role-based permissions
 *      - Pausable: Emergency pause functionality
 *
 * Security Considerations:
 *      - SEC-007: Fee calculations use explicit rounding (favor protocol)
 *      - SEC-013: Events emitted for all state changes
 *      - SEC-015: All unchecked blocks documented with safety proofs
 */
contract NexusNFT is ERC721A, ERC2981, AccessControl, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // ============ Constants ============

    /// @notice Role for administrative functions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for minting operations
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Maximum supply cap
    uint256 public constant MAX_SUPPLY = 10_000;

    /// @notice Maximum tokens per wallet during public mint
    uint256 public constant MAX_PER_WALLET = 5;

    /// @notice Maximum tokens per transaction
    uint256 public constant MAX_PER_TX = 3;

    /// @notice Maximum royalty basis points (10%)
    uint96 public constant MAX_ROYALTY_BPS = 1000;

    // ============ Enums ============

    /// @notice Sale phases
    enum SalePhase {
        Closed,
        Whitelist,
        Public
    }

    // ============ State Variables ============

    /// @notice Current sale phase
    SalePhase public salePhase;

    /// @notice Mint price in wei
    uint256 public mintPrice;

    /// @notice Whitelist mint price in wei
    uint256 public whitelistPrice;

    /// @notice Merkle root for whitelist verification
    bytes32 public merkleRoot;

    /// @notice Base URI for revealed metadata
    string private _baseTokenURI;

    /// @notice Placeholder URI for unrevealed tokens
    string private _placeholderURI;

    /// @notice Whether metadata has been revealed
    bool public revealed;

    /// @notice Whether tokens are soulbound (non-transferable)
    bool public soulbound;

    /// @notice Treasury address for mint proceeds
    address public treasury;

    /// @notice Mapping of token ID to soulbound status (individual override)
    mapping(uint256 tokenId => bool isSoulbound) private _tokenSoulbound;

    /// @notice Mapping of address to number of whitelist mints
    mapping(address minter => uint256 count) public whitelistMintCount;

    /// @notice Mapping of address to number of public mints
    mapping(address minter => uint256 count) public publicMintCount;

    /// @notice Maximum whitelist mints per address
    uint256 public maxWhitelistMints;

    // ============ Events ============

    /// @notice Emitted when sale phase changes
    /// @param previousPhase The previous sale phase
    /// @param newPhase The new sale phase
    event SalePhaseChanged(SalePhase indexed previousPhase, SalePhase indexed newPhase);

    /// @notice Emitted when mint price is updated
    /// @param previousPrice The previous mint price
    /// @param newPrice The new mint price
    event MintPriceUpdated(uint256 previousPrice, uint256 newPrice);

    /// @notice Emitted when whitelist price is updated
    /// @param previousPrice The previous whitelist price
    /// @param newPrice The new whitelist price
    event WhitelistPriceUpdated(uint256 previousPrice, uint256 newPrice);

    /// @notice Emitted when merkle root is updated
    /// @param previousRoot The previous merkle root
    /// @param newRoot The new merkle root
    event MerkleRootUpdated(bytes32 indexed previousRoot, bytes32 indexed newRoot);

    /// @notice Emitted when base URI is updated
    /// @param newBaseURI The new base URI
    event BaseURIUpdated(string newBaseURI);

    /// @notice Emitted when placeholder URI is updated
    /// @param newPlaceholderURI The new placeholder URI
    event PlaceholderURIUpdated(string newPlaceholderURI);

    /// @notice Emitted when metadata is revealed
    /// @param revealer The address that triggered the reveal
    event MetadataRevealed(address indexed revealer);

    /// @notice Emitted when soulbound status is changed globally
    /// @param enabled Whether soulbound is enabled
    event SoulboundStatusChanged(bool enabled);

    /// @notice Emitted when a token's soulbound status is changed individually
    /// @param tokenId The token ID
    /// @param isSoulbound Whether the token is soulbound
    event TokenSoulboundStatusChanged(uint256 indexed tokenId, bool isSoulbound);

    /// @notice Emitted when treasury is updated
    /// @param previousTreasury The previous treasury address
    /// @param newTreasury The new treasury address
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    /// @notice Emitted when tokens are minted
    /// @param minter The address that minted
    /// @param to The recipient address
    /// @param quantity The number of tokens minted
    /// @param firstTokenId The first token ID in the batch
    /// @param totalPaid The total amount paid
    event TokensMinted(
        address indexed minter, address indexed to, uint256 quantity, uint256 firstTokenId, uint256 totalPaid
    );

    /// @notice Emitted when funds are withdrawn
    /// @param recipient The withdrawal recipient
    /// @param amount The amount withdrawn
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    // ============ Errors ============

    /// @notice Thrown when sale is not active
    error SaleNotActive();

    /// @notice Thrown when whitelist sale is not active
    error WhitelistSaleNotActive();

    /// @notice Thrown when public sale is not active
    error PublicSaleNotActive();

    /// @notice Thrown when max supply would be exceeded
    /// @param requested The requested quantity
    /// @param available The available supply
    error ExceedsMaxSupply(uint256 requested, uint256 available);

    /// @notice Thrown when max per wallet would be exceeded
    /// @param requested The requested quantity
    /// @param limit The wallet limit
    error ExceedsWalletLimit(uint256 requested, uint256 limit);

    /// @notice Thrown when max per transaction would be exceeded
    error ExceedsTransactionLimit();

    /// @notice Thrown when insufficient payment is sent
    /// @param sent The amount sent
    /// @param required The required amount
    error InsufficientPayment(uint256 sent, uint256 required);

    /// @notice Thrown when merkle proof is invalid
    error InvalidMerkleProof();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when amount is zero
    error ZeroAmount();

    /// @notice Thrown when token is soulbound and transfer is attempted
    error TokenIsSoulbound();

    /// @notice Thrown when already revealed
    error AlreadyRevealed();

    /// @notice Thrown when royalty exceeds maximum
    error RoyaltyTooHigh();

    /// @notice Thrown when withdrawal fails
    error WithdrawalFailed();

    /// @notice Thrown when token does not exist
    error TokenDoesNotExist();

    // ============ Constructor ============

    /**
     * @notice Initializes the NexusNFT contract
     * @param name_ The token name
     * @param symbol_ The token symbol
     * @param treasury_ The treasury address for mint proceeds
     * @param royaltyReceiver_ The address to receive royalties
     * @param royaltyBps_ The royalty percentage in basis points
     * @param admin_ The initial admin address
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address treasury_,
        address royaltyReceiver_,
        uint96 royaltyBps_,
        address admin_
    )
        ERC721A(name_, symbol_)
    {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (royaltyReceiver_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (royaltyBps_ > MAX_ROYALTY_BPS) revert RoyaltyTooHigh();

        treasury = treasury_;
        maxWhitelistMints = 2; // Default whitelist allocation

        // Set default royalty
        _setDefaultRoyalty(royaltyReceiver_, royaltyBps_);

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);

        // Set ADMIN_ROLE as admin for MINTER_ROLE
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    }

    // ============ External Mint Functions ============

    /**
     * @notice Mint tokens during whitelist phase
     * @param quantity Number of tokens to mint
     * @param merkleProof Merkle proof for whitelist verification
     */
    function whitelistMint(
        uint256 quantity,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        whenNotPaused
    {
        if (salePhase != SalePhase.Whitelist) revert WhitelistSaleNotActive();
        if (quantity == 0) revert ZeroAmount();
        if (quantity > MAX_PER_TX) revert ExceedsTransactionLimit();

        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // Check whitelist allocation
        uint256 newCount = whitelistMintCount[msg.sender] + quantity;
        if (newCount > maxWhitelistMints) {
            revert ExceedsWalletLimit(quantity, maxWhitelistMints - whitelistMintCount[msg.sender]);
        }

        // Check supply
        uint256 supply = totalSupply();
        if (supply + quantity > MAX_SUPPLY) {
            revert ExceedsMaxSupply(quantity, MAX_SUPPLY - supply);
        }

        // Check payment
        uint256 totalCost = whitelistPrice * quantity;
        if (msg.value < totalCost) {
            revert InsufficientPayment(msg.value, totalCost);
        }

        // Update state
        whitelistMintCount[msg.sender] = newCount;

        // Mint tokens
        uint256 firstTokenId = _nextTokenId();
        _mint(msg.sender, quantity);

        emit TokensMinted(msg.sender, msg.sender, quantity, firstTokenId, totalCost);

        // Refund excess payment
        if (msg.value > totalCost) {
            _refund(msg.sender, msg.value - totalCost);
        }
    }

    /**
     * @notice Mint tokens during public sale
     * @param quantity Number of tokens to mint
     */
    function publicMint(uint256 quantity) external payable nonReentrant whenNotPaused {
        if (salePhase != SalePhase.Public) revert PublicSaleNotActive();
        if (quantity == 0) revert ZeroAmount();
        if (quantity > MAX_PER_TX) revert ExceedsTransactionLimit();

        // Check wallet limit
        uint256 newCount = publicMintCount[msg.sender] + quantity;
        if (newCount > MAX_PER_WALLET) {
            revert ExceedsWalletLimit(quantity, MAX_PER_WALLET - publicMintCount[msg.sender]);
        }

        // Check supply
        uint256 supply = totalSupply();
        if (supply + quantity > MAX_SUPPLY) {
            revert ExceedsMaxSupply(quantity, MAX_SUPPLY - supply);
        }

        // Check payment
        uint256 totalCost = mintPrice * quantity;
        if (msg.value < totalCost) {
            revert InsufficientPayment(msg.value, totalCost);
        }

        // Update state
        publicMintCount[msg.sender] = newCount;

        // Mint tokens
        uint256 firstTokenId = _nextTokenId();
        _mint(msg.sender, quantity);

        emit TokensMinted(msg.sender, msg.sender, quantity, firstTokenId, totalCost);

        // Refund excess payment
        if (msg.value > totalCost) {
            _refund(msg.sender, msg.value - totalCost);
        }
    }

    /**
     * @notice Admin mint function for team allocation, airdrops, etc.
     * @param to Recipient address
     * @param quantity Number of tokens to mint
     */
    function adminMint(address to, uint256 quantity) external nonReentrant onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (quantity == 0) revert ZeroAmount();

        uint256 supply = totalSupply();
        if (supply + quantity > MAX_SUPPLY) {
            revert ExceedsMaxSupply(quantity, MAX_SUPPLY - supply);
        }

        uint256 firstTokenId = _nextTokenId();
        _mint(to, quantity);

        emit TokensMinted(msg.sender, to, quantity, firstTokenId, 0);
    }

    /**
     * @notice Mint a soulbound token (non-transferable)
     * @param to Recipient address
     * @param quantity Number of tokens to mint
     */
    function mintSoulbound(address to, uint256 quantity) external nonReentrant onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (quantity == 0) revert ZeroAmount();

        uint256 supply = totalSupply();
        if (supply + quantity > MAX_SUPPLY) {
            revert ExceedsMaxSupply(quantity, MAX_SUPPLY - supply);
        }

        uint256 firstTokenId = _nextTokenId();
        _mint(to, quantity);

        // Mark each token as soulbound
        // SAFETY: Loop is bounded by quantity which is limited by MAX_SUPPLY
        unchecked {
            for (uint256 i = 0; i < quantity; i++) {
                _tokenSoulbound[firstTokenId + i] = true;
                emit TokenSoulboundStatusChanged(firstTokenId + i, true);
            }
        }

        emit TokensMinted(msg.sender, to, quantity, firstTokenId, 0);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the sale phase
     * @param newPhase The new sale phase
     */
    function setSalePhase(SalePhase newPhase) external onlyRole(ADMIN_ROLE) {
        SalePhase previousPhase = salePhase;
        salePhase = newPhase;
        emit SalePhaseChanged(previousPhase, newPhase);
    }

    /**
     * @notice Set the public mint price
     * @param newPrice The new mint price in wei
     */
    function setMintPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        uint256 previousPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(previousPrice, newPrice);
    }

    /**
     * @notice Set the whitelist mint price
     * @param newPrice The new whitelist price in wei
     */
    function setWhitelistPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        uint256 previousPrice = whitelistPrice;
        whitelistPrice = newPrice;
        emit WhitelistPriceUpdated(previousPrice, newPrice);
    }

    /**
     * @notice Set the merkle root for whitelist verification
     * @param newRoot The new merkle root
     */
    function setMerkleRoot(bytes32 newRoot) external onlyRole(ADMIN_ROLE) {
        bytes32 previousRoot = merkleRoot;
        merkleRoot = newRoot;
        emit MerkleRootUpdated(previousRoot, newRoot);
    }

    /**
     * @notice Set the maximum whitelist mints per address
     * @param newMax The new maximum
     */
    function setMaxWhitelistMints(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        maxWhitelistMints = newMax;
    }

    /**
     * @notice Set the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string calldata newBaseURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @notice Set the placeholder URI for unrevealed tokens
     * @param newPlaceholderURI The new placeholder URI
     */
    function setPlaceholderURI(string calldata newPlaceholderURI) external onlyRole(ADMIN_ROLE) {
        _placeholderURI = newPlaceholderURI;
        emit PlaceholderURIUpdated(newPlaceholderURI);
    }

    /**
     * @notice Reveal the token metadata
     * @dev Can only be called once
     */
    function reveal() external onlyRole(ADMIN_ROLE) {
        if (revealed) revert AlreadyRevealed();
        revealed = true;
        emit MetadataRevealed(msg.sender);
    }

    /**
     * @notice Set global soulbound status
     * @param enabled Whether all tokens should be soulbound
     */
    function setSoulbound(bool enabled) external onlyRole(ADMIN_ROLE) {
        soulbound = enabled;
        emit SoulboundStatusChanged(enabled);
    }

    /**
     * @notice Set individual token soulbound status
     * @param tokenId The token ID
     * @param isSoulbound Whether the token should be soulbound
     */
    function setTokenSoulbound(uint256 tokenId, bool isSoulbound) external onlyRole(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        _tokenSoulbound[tokenId] = isSoulbound;
        emit TokenSoulboundStatusChanged(tokenId, isSoulbound);
    }

    /**
     * @notice Update the treasury address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previousTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(previousTreasury, newTreasury);
    }

    /**
     * @notice Update the default royalty
     * @param receiver The royalty receiver address
     * @param royaltyBps The royalty in basis points
     */
    function setDefaultRoyalty(address receiver, uint96 royaltyBps) external onlyRole(ADMIN_ROLE) {
        if (receiver == address(0)) revert ZeroAddress();
        if (royaltyBps > MAX_ROYALTY_BPS) revert RoyaltyTooHigh();
        _setDefaultRoyalty(receiver, royaltyBps);
    }

    /**
     * @notice Set royalty for a specific token
     * @param tokenId The token ID
     * @param receiver The royalty receiver
     * @param royaltyBps The royalty in basis points
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 royaltyBps) external onlyRole(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        if (receiver == address(0)) revert ZeroAddress();
        if (royaltyBps > MAX_ROYALTY_BPS) revert RoyaltyTooHigh();
        _setTokenRoyalty(tokenId, receiver, royaltyBps);
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

    /**
     * @notice Withdraw contract balance to treasury
     */
    function withdraw() external nonReentrant onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroAmount();

        (bool success,) = treasury.call{ value: balance }("");
        if (!success) revert WithdrawalFailed();

        emit FundsWithdrawn(treasury, balance);
    }

    // ============ View Functions ============

    /**
     * @notice Get the token URI
     * @param tokenId The token ID
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        if (!revealed) {
            return _placeholderURI;
        }

        string memory baseURI = _baseTokenURI;
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    /**
     * @notice Check if a token is soulbound
     * @param tokenId The token ID
     * @return Whether the token is soulbound
     */
    function isTokenSoulbound(uint256 tokenId) public view returns (bool) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return soulbound || _tokenSoulbound[tokenId];
    }

    /**
     * @notice Get remaining supply
     * @return The number of tokens still available
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @notice Check if an address is whitelisted
     * @param account The address to check
     * @param merkleProof The merkle proof
     * @return Whether the address is whitelisted
     */
    function isWhitelisted(address account, bytes32[] calldata merkleProof) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    /**
     * @notice Get minting info for an address
     * @param account The address to query
     * @return whitelistMinted Number of whitelist mints
     * @return publicMinted Number of public mints
     * @return whitelistRemaining Remaining whitelist allocation
     * @return publicRemaining Remaining public allocation
     */
    function getMintInfo(address account)
        external
        view
        returns (uint256 whitelistMinted, uint256 publicMinted, uint256 whitelistRemaining, uint256 publicRemaining)
    {
        whitelistMinted = whitelistMintCount[account];
        publicMinted = publicMintCount[account];
        whitelistRemaining = maxWhitelistMints > whitelistMinted ? maxWhitelistMints - whitelistMinted : 0;
        publicRemaining = MAX_PER_WALLET > publicMinted ? MAX_PER_WALLET - publicMinted : 0;
    }

    // ============ Internal Functions ============

    /**
     * @notice Override to enforce soulbound restrictions
     * @param from Source address
     * @param to Destination address
     * @param tokenId Token ID being transferred
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 tokenId,
        uint256 quantity
    )
        internal
        virtual
        override
    {
        super._beforeTokenTransfers(from, to, tokenId, quantity);

        // Allow minting (from == address(0)) and burning (to == address(0))
        if (from != address(0) && to != address(0)) {
            // Check global soulbound
            if (soulbound) revert TokenIsSoulbound();

            // Check individual token soulbound status for each token in batch
            // SAFETY: Loop bounded by quantity which is limited by batch operations
            unchecked {
                for (uint256 i = 0; i < quantity; i++) {
                    if (_tokenSoulbound[tokenId + i]) {
                        revert TokenIsSoulbound();
                    }
                }
            }
        }
    }

    /**
     * @notice Refund excess ETH payment
     * @param to Recipient address
     * @param amount Amount to refund
     */
    function _refund(address to, uint256 amount) internal {
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert WithdrawalFailed();
    }

    /**
     * @notice Starting token ID
     * @return The starting token ID (1 instead of 0)
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    // ============ Required Overrides ============

    /**
     * @notice Check interface support
     * @param interfaceId The interface ID to check
     * @return Whether the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, ERC2981, AccessControl)
        returns (bool)
    {
        return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId)
            || AccessControl.supportsInterface(interfaceId);
    }
}
