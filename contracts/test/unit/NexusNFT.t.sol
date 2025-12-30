// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {NexusNFT} from "../../src/core/NexusNFT.sol";

/**
 * @title NexusNFTTest
 * @notice Unit tests for NexusNFT contract
 * @dev Tests cover:
 *      - Deployment and initialization
 *      - Minting (public, whitelist, admin)
 *      - Reveal mechanism
 *      - Royalties (ERC-2981)
 *      - Soulbound functionality
 *      - Access control
 *      - Pause functionality
 *      - Token URI handling
 */
contract NexusNFTTest is Test {
    NexusNFT public nft;

    address public admin = address(1);
    address public minter = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public treasury = address(5);
    address public royaltyReceiver = address(6);
    address public user3 = address(7);

    uint256 public constant MINT_PRICE = 0.08 ether;
    uint256 public constant WHITELIST_PRICE = 0.05 ether;
    uint96 public constant ROYALTY_BPS = 500; // 5%
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MAX_PER_WALLET = 5;
    uint256 public constant MAX_PER_TX = 3;
    uint256 public constant MAX_ROYALTY_BPS = 1000;

    // Merkle tree for whitelist - we'll build a simple one with user1, user2, user3
    bytes32 public merkleRoot;
    bytes32[] public user1Proof;
    bytes32[] public user2Proof;
    bytes32[] public user3Proof;

    // Events from NexusNFT
    event SalePhaseChanged(NexusNFT.SalePhase indexed previousPhase, NexusNFT.SalePhase indexed newPhase);
    event MintPriceUpdated(uint256 previousPrice, uint256 newPrice);
    event WhitelistPriceUpdated(uint256 previousPrice, uint256 newPrice);
    event MerkleRootUpdated(bytes32 indexed previousRoot, bytes32 indexed newRoot);
    event BaseURIUpdated(string newBaseURI);
    event PlaceholderURIUpdated(string newPlaceholderURI);
    event MetadataRevealed(address indexed revealer);
    event SoulboundStatusChanged(bool enabled);
    event TokenSoulboundStatusChanged(uint256 indexed tokenId, bool isSoulbound);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event TokensMinted(
        address indexed minter,
        address indexed to,
        uint256 quantity,
        uint256 firstTokenId,
        uint256 totalPaid
    );
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    function setUp() public {
        // Build merkle tree for whitelist
        // Leaves: hash(user1), hash(user2), hash(user3)
        bytes32 leaf1 = keccak256(abi.encodePacked(user1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2));
        bytes32 leaf3 = keccak256(abi.encodePacked(user3));

        // For a simple 3-leaf merkle tree:
        // Layer 1: [leaf1, leaf2, leaf3, leaf3] (padding)
        // Layer 2: [hash(leaf1, leaf2), hash(leaf3, leaf3)]
        // Root: hash(layer2[0], layer2[1])

        bytes32 node12 = _hashPair(leaf1, leaf2);
        bytes32 node33 = _hashPair(leaf3, leaf3);
        merkleRoot = _hashPair(node12, node33);

        // Proof for user1: [leaf2, node33]
        user1Proof = new bytes32[](2);
        user1Proof[0] = leaf2;
        user1Proof[1] = node33;

        // Proof for user2: [leaf1, node33]
        user2Proof = new bytes32[](2);
        user2Proof[0] = leaf1;
        user2Proof[1] = node33;

        // Proof for user3: [leaf3, node12]
        user3Proof = new bytes32[](2);
        user3Proof[0] = leaf3;
        user3Proof[1] = node12;

        vm.startPrank(admin);
        nft = new NexusNFT(
            "Nexus NFT",
            "NNFT",
            treasury,
            royaltyReceiver,
            ROYALTY_BPS,
            admin
        );

        // Set prices
        nft.setMintPrice(MINT_PRICE);
        nft.setWhitelistPrice(WHITELIST_PRICE);
        nft.setMerkleRoot(merkleRoot);

        // Set URIs
        nft.setBaseURI("https://api.nexus.io/nft/");
        nft.setPlaceholderURI("https://api.nexus.io/nft/placeholder.json");
        vm.stopPrank();

        // Fund users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    // Helper to hash pairs in merkle tree (sorted)
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(nft.name(), "Nexus NFT");
        assertEq(nft.symbol(), "NNFT");
        assertEq(nft.treasury(), treasury);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.whitelistPrice(), WHITELIST_PRICE);
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.revealed(), false);
        assertEq(nft.soulbound(), false);
    }

    function test_DeploymentRoles() public view {
        assertTrue(nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(nft.hasRole(nft.ADMIN_ROLE(), admin));
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), admin));
    }

    function test_Deployment_RevertZeroTreasury() public {
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        new NexusNFT("Test", "TEST", address(0), royaltyReceiver, ROYALTY_BPS, admin);
    }

    function test_Deployment_RevertZeroRoyaltyReceiver() public {
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        new NexusNFT("Test", "TEST", treasury, address(0), ROYALTY_BPS, admin);
    }

    function test_Deployment_RevertZeroAdmin() public {
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        new NexusNFT("Test", "TEST", treasury, royaltyReceiver, ROYALTY_BPS, address(0));
    }

    function test_Deployment_RevertRoyaltyTooHigh() public {
        vm.expectRevert(NexusNFT.RoyaltyTooHigh.selector);
        new NexusNFT("Test", "TEST", treasury, royaltyReceiver, uint96(MAX_ROYALTY_BPS + 1), admin);
    }

    // ============ Sale Phase Tests ============

    function test_SetSalePhase() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit SalePhaseChanged(NexusNFT.SalePhase.Closed, NexusNFT.SalePhase.Whitelist);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        assertEq(uint256(nft.salePhase()), uint256(NexusNFT.SalePhase.Whitelist));
    }

    function test_SetSalePhase_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setSalePhase(NexusNFT.SalePhase.Public);
    }

    // ============ Whitelist Mint Tests ============

    function test_WhitelistMint() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        uint256 quantity = 2;
        uint256 totalCost = WHITELIST_PRICE * quantity;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(user1, user1, quantity, 1, totalCost);
        nft.whitelistMint{value: totalCost}(quantity, user1Proof);

        assertEq(nft.balanceOf(user1), quantity);
        assertEq(nft.totalSupply(), quantity);
        assertEq(nft.whitelistMintCount(user1), quantity);
    }

    function test_WhitelistMint_RevertNotWhitelistPhase() public {
        // Sale is closed by default
        vm.prank(user1);
        vm.expectRevert(NexusNFT.WhitelistSaleNotActive.selector);
        nft.whitelistMint{value: WHITELIST_PRICE}(1, user1Proof);
    }

    function test_WhitelistMint_RevertInvalidProof() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        // User1 tries with user2's proof
        vm.prank(user1);
        vm.expectRevert(NexusNFT.InvalidMerkleProof.selector);
        nft.whitelistMint{value: WHITELIST_PRICE}(1, user2Proof);
    }

    function test_WhitelistMint_RevertZeroAmount() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        vm.prank(user1);
        vm.expectRevert(NexusNFT.ZeroAmount.selector);
        nft.whitelistMint{value: 0}(0, user1Proof);
    }

    function test_WhitelistMint_RevertExceedsTransactionLimit() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        vm.prank(user1);
        vm.expectRevert(NexusNFT.ExceedsTransactionLimit.selector);
        nft.whitelistMint{value: WHITELIST_PRICE * 4}(4, user1Proof);
    }

    function test_WhitelistMint_RevertExceedsWalletLimit() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        // Max whitelist mints is 2 by default
        vm.startPrank(user1);
        nft.whitelistMint{value: WHITELIST_PRICE * 2}(2, user1Proof);

        // Try to mint more
        vm.expectRevert(abi.encodeWithSelector(NexusNFT.ExceedsWalletLimit.selector, 1, 0));
        nft.whitelistMint{value: WHITELIST_PRICE}(1, user1Proof);
        vm.stopPrank();
    }

    function test_WhitelistMint_RevertInsufficientPayment() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(NexusNFT.InsufficientPayment.selector, WHITELIST_PRICE - 1, WHITELIST_PRICE));
        nft.whitelistMint{value: WHITELIST_PRICE - 1}(1, user1Proof);
    }

    function test_WhitelistMint_RefundsExcess() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);

        uint256 balanceBefore = user1.balance;
        uint256 overpayment = 0.1 ether;

        vm.prank(user1);
        nft.whitelistMint{value: WHITELIST_PRICE + overpayment}(1, user1Proof);

        assertEq(user1.balance, balanceBefore - WHITELIST_PRICE);
    }

    function test_SetMaxWhitelistMints() public {
        vm.prank(admin);
        nft.setMaxWhitelistMints(5);

        assertEq(nft.maxWhitelistMints(), 5);
    }

    // ============ Public Mint Tests ============

    function test_PublicMint() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        uint256 quantity = 3;
        uint256 totalCost = MINT_PRICE * quantity;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(user1, user1, quantity, 1, totalCost);
        nft.publicMint{value: totalCost}(quantity);

        assertEq(nft.balanceOf(user1), quantity);
        assertEq(nft.publicMintCount(user1), quantity);
    }

    function test_PublicMint_RevertNotPublicPhase() public {
        // Sale is closed by default
        vm.prank(user1);
        vm.expectRevert(NexusNFT.PublicSaleNotActive.selector);
        nft.publicMint{value: MINT_PRICE}(1);
    }

    function test_PublicMint_RevertZeroAmount() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        vm.prank(user1);
        vm.expectRevert(NexusNFT.ZeroAmount.selector);
        nft.publicMint{value: 0}(0);
    }

    function test_PublicMint_RevertExceedsTransactionLimit() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        vm.prank(user1);
        vm.expectRevert(NexusNFT.ExceedsTransactionLimit.selector);
        nft.publicMint{value: MINT_PRICE * 4}(4);
    }

    function test_PublicMint_RevertExceedsWalletLimit() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        vm.startPrank(user1);
        // Mint max per wallet (5) in two transactions (3 + 2)
        nft.publicMint{value: MINT_PRICE * 3}(3);
        nft.publicMint{value: MINT_PRICE * 2}(2);

        // Try to mint one more
        vm.expectRevert(abi.encodeWithSelector(NexusNFT.ExceedsWalletLimit.selector, 1, 0));
        nft.publicMint{value: MINT_PRICE}(1);
        vm.stopPrank();
    }

    function test_PublicMint_RevertInsufficientPayment() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(NexusNFT.InsufficientPayment.selector, MINT_PRICE - 1, MINT_PRICE));
        nft.publicMint{value: MINT_PRICE - 1}(1);
    }

    function test_PublicMint_RefundsExcess() public {
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        uint256 balanceBefore = user1.balance;
        uint256 overpayment = 0.1 ether;

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE + overpayment}(1);

        assertEq(user1.balance, balanceBefore - MINT_PRICE);
    }

    // ============ Admin Mint Tests ============

    function test_AdminMint() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(admin, user1, 5, 1, 0);
        nft.adminMint(user1, 5);

        assertEq(nft.balanceOf(user1), 5);
    }

    function test_AdminMint_OnlyMinterRole() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.adminMint(user2, 5);
    }

    function test_AdminMint_GrantMinterRole() public {
        vm.startPrank(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.prank(minter);
        nft.adminMint(user1, 5);

        assertEq(nft.balanceOf(user1), 5);
    }

    function test_AdminMint_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        nft.adminMint(address(0), 5);
    }

    function test_AdminMint_RevertZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAmount.selector);
        nft.adminMint(user1, 0);
    }

    // ============ Soulbound Mint Tests ============

    function test_MintSoulbound() public {
        vm.prank(admin);
        nft.mintSoulbound(user1, 3);

        assertEq(nft.balanceOf(user1), 3);
        assertTrue(nft.isTokenSoulbound(1));
        assertTrue(nft.isTokenSoulbound(2));
        assertTrue(nft.isTokenSoulbound(3));
    }

    function test_MintSoulbound_OnlyMinterRole() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.mintSoulbound(user2, 1);
    }

    function test_MintSoulbound_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        nft.mintSoulbound(address(0), 1);
    }

    function test_MintSoulbound_RevertZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAmount.selector);
        nft.mintSoulbound(user1, 0);
    }

    // ============ Soulbound Transfer Tests ============

    function test_Soulbound_RevertOnTransfer() public {
        vm.prank(admin);
        nft.mintSoulbound(user1, 1);

        vm.prank(user1);
        vm.expectRevert(NexusNFT.TokenIsSoulbound.selector);
        nft.transferFrom(user1, user2, 1);
    }

    function test_GlobalSoulbound_RevertOnTransfer() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);
        nft.setSoulbound(true);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(NexusNFT.TokenIsSoulbound.selector);
        nft.transferFrom(user1, user2, 1);
    }

    function test_GlobalSoulbound_AllowAfterDisable() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);
        nft.setSoulbound(true);
        nft.setSoulbound(false);
        vm.stopPrank();

        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    function test_SetTokenSoulbound() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);
        nft.setTokenSoulbound(1, true);
        vm.stopPrank();

        assertTrue(nft.isTokenSoulbound(1));

        vm.prank(user1);
        vm.expectRevert(NexusNFT.TokenIsSoulbound.selector);
        nft.transferFrom(user1, user2, 1);
    }

    function test_SetTokenSoulbound_RevertTokenDoesNotExist() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.TokenDoesNotExist.selector);
        nft.setTokenSoulbound(999, true);
    }

    // ============ Reveal Mechanism Tests ============

    function test_TokenURI_BeforeReveal() public {
        vm.prank(admin);
        nft.adminMint(user1, 1);

        string memory uri = nft.tokenURI(1);
        assertEq(uri, "https://api.nexus.io/nft/placeholder.json");
    }

    function test_TokenURI_AfterReveal() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);
        nft.reveal();
        vm.stopPrank();

        string memory uri = nft.tokenURI(1);
        assertEq(uri, "https://api.nexus.io/nft/1.json");
    }

    function test_Reveal() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit MetadataRevealed(admin);
        nft.reveal();

        assertTrue(nft.revealed());
    }

    function test_Reveal_RevertAlreadyRevealed() public {
        vm.startPrank(admin);
        nft.reveal();

        vm.expectRevert(NexusNFT.AlreadyRevealed.selector);
        nft.reveal();
        vm.stopPrank();
    }

    function test_Reveal_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.reveal();
    }

    function test_TokenURI_RevertNonexistentToken() public {
        vm.expectRevert(NexusNFT.TokenDoesNotExist.selector);
        nft.tokenURI(999);
    }

    function test_SetBaseURI() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated("https://new.uri/");
        nft.setBaseURI("https://new.uri/");
    }

    function test_SetPlaceholderURI() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit PlaceholderURIUpdated("https://new.placeholder/");
        nft.setPlaceholderURI("https://new.placeholder/");
    }

    // ============ Royalty Tests (ERC-2981) ============

    function test_RoyaltyInfo() public view {
        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, salePrice * ROYALTY_BPS / 10000);
    }

    function test_SetDefaultRoyalty() public {
        address newReceiver = address(100);
        uint96 newBps = 750; // 7.5%

        vm.prank(admin);
        nft.setDefaultRoyalty(newReceiver, newBps);

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, newReceiver);
        assertEq(royaltyAmount, 1 ether * newBps / 10000);
    }

    function test_SetDefaultRoyalty_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        nft.setDefaultRoyalty(address(0), ROYALTY_BPS);
    }

    function test_SetDefaultRoyalty_RevertTooHigh() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.RoyaltyTooHigh.selector);
        nft.setDefaultRoyalty(royaltyReceiver, uint96(MAX_ROYALTY_BPS + 1));
    }

    function test_SetTokenRoyalty() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);

        address tokenReceiver = address(101);
        uint96 tokenBps = 250; // 2.5%
        nft.setTokenRoyalty(1, tokenReceiver, tokenBps);
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, tokenReceiver);
        assertEq(royaltyAmount, 1 ether * tokenBps / 10000);
    }

    function test_SetTokenRoyalty_RevertTokenDoesNotExist() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.TokenDoesNotExist.selector);
        nft.setTokenRoyalty(999, royaltyReceiver, ROYALTY_BPS);
    }

    function test_SetTokenRoyalty_RevertZeroAddress() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);

        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        nft.setTokenRoyalty(1, address(0), ROYALTY_BPS);
        vm.stopPrank();
    }

    function test_SetTokenRoyalty_RevertTooHigh() public {
        vm.startPrank(admin);
        nft.adminMint(user1, 1);

        vm.expectRevert(NexusNFT.RoyaltyTooHigh.selector);
        nft.setTokenRoyalty(1, royaltyReceiver, uint96(MAX_ROYALTY_BPS + 1));
        vm.stopPrank();
    }

    // ============ Access Control Tests ============

    function test_GrantMinterRole() public {
        vm.startPrank(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
        vm.stopPrank();

        assertTrue(nft.hasRole(nft.MINTER_ROLE(), minter));
    }

    function test_RevokeMinterRole() public {
        vm.startPrank(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
        nft.revokeRole(nft.MINTER_ROLE(), minter);
        vm.stopPrank();

        assertFalse(nft.hasRole(nft.MINTER_ROLE(), minter));
    }

    function test_MinterRoleAdmin() public view {
        // ADMIN_ROLE should be the admin of MINTER_ROLE
        bytes32 roleAdmin = nft.getRoleAdmin(nft.MINTER_ROLE());
        assertEq(roleAdmin, nft.ADMIN_ROLE());
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        vm.prank(admin);
        nft.pause();

        assertTrue(nft.paused());
    }

    function test_Unpause() public {
        vm.startPrank(admin);
        nft.pause();
        nft.unpause();
        vm.stopPrank();

        assertFalse(nft.paused());
    }

    function test_Pause_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.pause();
    }

    function test_WhitelistMint_RevertWhenPaused() public {
        vm.startPrank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);
        nft.pause();
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        nft.whitelistMint{value: WHITELIST_PRICE}(1, user1Proof);
    }

    function test_PublicMint_RevertWhenPaused() public {
        vm.startPrank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);
        nft.pause();
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        nft.publicMint{value: MINT_PRICE}(1);
    }

    // ============ Treasury & Withdrawal Tests ============

    function test_SetTreasury() public {
        address newTreasury = address(200);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit TreasuryUpdated(treasury, newTreasury);
        nft.setTreasury(newTreasury);

        assertEq(nft.treasury(), newTreasury);
    }

    function test_SetTreasury_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAddress.selector);
        nft.setTreasury(address(0));
    }

    function test_Withdraw() public {
        // Mint some tokens to accumulate funds
        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE * 3}(3);

        uint256 contractBalance = address(nft).balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(treasury, contractBalance);
        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(treasury.balance, treasuryBalanceBefore + contractBalance);
    }

    function test_Withdraw_RevertZeroBalance() public {
        vm.prank(admin);
        vm.expectRevert(NexusNFT.ZeroAmount.selector);
        nft.withdraw();
    }

    function test_Withdraw_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.withdraw();
    }

    // ============ View Function Tests ============

    function test_RemainingSupply() public {
        assertEq(nft.remainingSupply(), MAX_SUPPLY);

        vm.prank(admin);
        nft.adminMint(user1, 100);

        assertEq(nft.remainingSupply(), MAX_SUPPLY - 100);
    }

    function test_IsWhitelisted() public view {
        assertTrue(nft.isWhitelisted(user1, user1Proof));
        assertTrue(nft.isWhitelisted(user2, user2Proof));
        assertTrue(nft.isWhitelisted(user3, user3Proof));

        // Non-whitelisted user
        assertFalse(nft.isWhitelisted(admin, user1Proof));
    }

    function test_GetMintInfo() public {
        vm.startPrank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);
        vm.stopPrank();

        vm.prank(user1);
        nft.whitelistMint{value: WHITELIST_PRICE}(1, user1Proof);

        (
            uint256 whitelistMinted,
            uint256 publicMinted,
            uint256 whitelistRemaining,
            uint256 publicRemaining
        ) = nft.getMintInfo(user1);

        assertEq(whitelistMinted, 1);
        assertEq(publicMinted, 0);
        assertEq(whitelistRemaining, 1); // 2 - 1 = 1
        assertEq(publicRemaining, MAX_PER_WALLET);
    }

    function test_SupportsInterface() public view {
        // ERC721
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(nft.supportsInterface(0x5b5e139f));
        // ERC2981 (Royalties)
        assertTrue(nft.supportsInterface(0x2a55205a));
        // AccessControl
        assertTrue(nft.supportsInterface(0x7965db0b));
    }

    // ============ Max Supply Tests ============

    function test_AdminMint_RevertExceedsMaxSupply() public {
        // This would normally require minting MAX_SUPPLY tokens first
        // For efficiency, we'll test with a smaller amount that demonstrates the behavior
        vm.startPrank(admin);

        // Mint up to near max (we'll do a batch that demonstrates the check)
        // Since MAX_SUPPLY is 10,000, let's mint most of it
        for (uint256 i = 0; i < 99; i++) {
            nft.adminMint(user1, 100);
        }

        // Total minted: 9900
        // Remaining: 100
        assertEq(nft.totalSupply(), 9900);

        // Try to mint 101 more (should fail)
        vm.expectRevert(abi.encodeWithSelector(NexusNFT.ExceedsMaxSupply.selector, 101, 100));
        nft.adminMint(user2, 101);

        vm.stopPrank();
    }

    // ============ Price Configuration Tests ============

    function test_SetMintPrice() public {
        uint256 newPrice = 0.1 ether;

        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit MintPriceUpdated(MINT_PRICE, newPrice);
        nft.setMintPrice(newPrice);

        assertEq(nft.mintPrice(), newPrice);
    }

    function test_SetWhitelistPrice() public {
        uint256 newPrice = 0.03 ether;

        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit WhitelistPriceUpdated(WHITELIST_PRICE, newPrice);
        nft.setWhitelistPrice(newPrice);

        assertEq(nft.whitelistPrice(), newPrice);
    }

    function test_SetMerkleRoot() public {
        bytes32 newRoot = keccak256("newRoot");

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit MerkleRootUpdated(merkleRoot, newRoot);
        nft.setMerkleRoot(newRoot);

        assertEq(nft.merkleRoot(), newRoot);
    }

    // ============ Transfer Tests ============

    function test_Transfer() public {
        vm.prank(admin);
        nft.adminMint(user1, 1);

        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_SafeTransferFrom() public {
        vm.prank(admin);
        nft.adminMint(user1, 1);

        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    function test_Approval() public {
        vm.prank(admin);
        nft.adminMint(user1, 1);

        vm.prank(user1);
        nft.approve(user2, 1);

        assertEq(nft.getApproved(1), user2);

        vm.prank(user2);
        nft.transferFrom(user1, user3, 1);

        assertEq(nft.ownerOf(1), user3);
    }

    function test_SetApprovalForAll() public {
        vm.prank(admin);
        nft.adminMint(user1, 3);

        vm.prank(user1);
        nft.setApprovalForAll(user2, true);

        assertTrue(nft.isApprovedForAll(user1, user2));

        // User2 can transfer all of user1's tokens
        vm.startPrank(user2);
        nft.transferFrom(user1, user3, 1);
        nft.transferFrom(user1, user3, 2);
        nft.transferFrom(user1, user3, 3);
        vm.stopPrank();

        assertEq(nft.balanceOf(user3), 3);
    }

    // ============ Fuzz Tests ============

    function testFuzz_PublicMint(uint256 quantity) public {
        quantity = bound(quantity, 1, MAX_PER_TX);

        vm.prank(admin);
        nft.setSalePhase(NexusNFT.SalePhase.Public);

        uint256 totalCost = MINT_PRICE * quantity;

        vm.prank(user1);
        nft.publicMint{value: totalCost}(quantity);

        assertEq(nft.balanceOf(user1), quantity);
    }

    function testFuzz_AdminMint(uint256 quantity) public {
        quantity = bound(quantity, 1, 100);

        vm.prank(admin);
        nft.adminMint(user1, quantity);

        assertEq(nft.balanceOf(user1), quantity);
    }

    function testFuzz_Royalty(uint96 royaltyBps, uint256 salePrice) public {
        royaltyBps = uint96(bound(royaltyBps, 0, MAX_ROYALTY_BPS));
        salePrice = bound(salePrice, 0, 1000 ether);

        vm.prank(admin);
        nft.setDefaultRoyalty(royaltyReceiver, royaltyBps);

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, salePrice * royaltyBps / 10000);
    }

    // ============ Edge Cases ============

    function test_TokenIdStartsAtOne() public {
        vm.prank(admin);
        nft.adminMint(user1, 1);

        // First token should be ID 1, not 0
        assertEq(nft.ownerOf(1), user1);

        // Token 0 should not exist
        vm.expectRevert();
        nft.ownerOf(0);
    }

    function test_BatchMinting() public {
        vm.prank(admin);
        nft.adminMint(user1, 100);

        assertEq(nft.balanceOf(user1), 100);

        // Check first and last tokens
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(100), user1);
    }

    function test_FreeMint_WhitelistPriceZero() public {
        vm.startPrank(admin);
        nft.setWhitelistPrice(0);
        nft.setSalePhase(NexusNFT.SalePhase.Whitelist);
        vm.stopPrank();

        vm.prank(user1);
        nft.whitelistMint{value: 0}(1, user1Proof);

        assertEq(nft.balanceOf(user1), 1);
    }

    function test_FreeMint_PublicPriceZero() public {
        vm.startPrank(admin);
        nft.setMintPrice(0);
        nft.setSalePhase(NexusNFT.SalePhase.Public);
        vm.stopPrank();

        vm.prank(user1);
        nft.publicMint{value: 0}(1);

        assertEq(nft.balanceOf(user1), 1);
    }
}

/**
 * @title ReceiveRejectContract
 * @notice Contract that rejects ETH transfers to test refund failures
 */
contract ReceiveRejectContract {
    receive() external payable {
        revert("No ETH accepted");
    }
}

/**
 * @title NexusNFTRefundTest
 * @notice Additional tests for refund/withdrawal failure scenarios
 */
contract NexusNFTRefundTest is Test {
    NexusNFT public nft;
    ReceiveRejectContract public rejectContract;

    address public admin = address(1);
    address public treasury = address(2);
    address public royaltyReceiver = address(3);

    uint256 public constant MINT_PRICE = 0.08 ether;

    function setUp() public {
        rejectContract = new ReceiveRejectContract();

        vm.prank(admin);
        nft = new NexusNFT(
            "Nexus NFT",
            "NNFT",
            treasury,
            royaltyReceiver,
            500,
            admin
        );

        vm.startPrank(admin);
        nft.setMintPrice(MINT_PRICE);
        nft.setSalePhase(NexusNFT.SalePhase.Public);
        vm.stopPrank();

        // Fund the reject contract
        vm.deal(address(rejectContract), 100 ether);
    }

    function test_PublicMint_RevertOnRefundFailure() public {
        // The rejectContract will reject the refund
        vm.prank(address(rejectContract));
        vm.expectRevert(NexusNFT.WithdrawalFailed.selector);
        nft.publicMint{value: MINT_PRICE + 0.1 ether}(1);
    }
}
