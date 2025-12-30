// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { NexusBridge } from "../../src/bridge/NexusBridge.sol";
import { NexusToken } from "../../src/core/NexusToken.sol";

/**
 * @title NexusBridgeTest
 * @notice Unit tests for NexusBridge contract
 * @dev Tests cover:
 *      - Initialization
 *      - Lock/unlock operations (source chain)
 *      - Rate limiting
 *      - Chain management
 *      - Access control
 *      - Pause functionality
 */
contract NexusBridgeTest is Test {
    NexusBridge public bridge;
    NexusToken public token;

    address public admin = address(1);
    address public relayer1 = address(2);
    address public relayer2 = address(3);
    address public relayer3 = address(4);
    address public user1 = address(5);
    address public user2 = address(6);
    address public guardian = address(7);

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant BRIDGE_AMOUNT = 10_000 * 1e18;
    uint256 public constant DEST_CHAIN_ID = 137; // Polygon
    uint256 public constant SOURCE_CHAIN_ID = 1; // Ethereum

    function setUp() public {
        vm.startPrank(admin);

        // Deploy token
        token = new NexusToken(admin);
        token.mint(admin, INITIAL_SUPPLY);

        // Prepare initial relayers array
        address[] memory initialRelayers = new address[](3);
        initialRelayers[0] = relayer1;
        initialRelayers[1] = relayer2;
        initialRelayers[2] = relayer3;

        // Deploy bridge (source chain)
        bridge = new NexusBridge(
            address(token),
            SOURCE_CHAIN_ID,
            true, // isSourceChain
            2, // relayerThreshold (MIN_RELAYER_THRESHOLD)
            initialRelayers
        );

        // Setup additional roles
        bridge.grantRole(bridge.GUARDIAN_ROLE(), guardian);

        // Add supported chain
        bridge.addSupportedChain(DEST_CHAIN_ID);

        // Transfer tokens to users
        token.transfer(user1, BRIDGE_AMOUNT * 10);
        token.transfer(user2, BRIDGE_AMOUNT * 10);

        vm.stopPrank();

        // Approve bridge
        vm.prank(user1);
        token.approve(address(bridge), type(uint256).max);

        vm.prank(user2);
        token.approve(address(bridge), type(uint256).max);
    }

    // ============ Initialization Tests ============

    function test_Deployment() public view {
        assertEq(address(bridge.token()), address(token));
        assertEq(bridge.chainId(), SOURCE_CHAIN_ID);
        assertTrue(bridge.isSourceChain());
        assertEq(bridge.relayerThreshold(), 2); // MIN_RELAYER_THRESHOLD
    }

    function test_AdminHasRoles() public view {
        assertTrue(bridge.hasRole(bridge.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(bridge.hasRole(bridge.ADMIN_ROLE(), admin));
    }

    function test_RelayersHaveRole() public view {
        assertTrue(bridge.hasRole(bridge.RELAYER_ROLE(), relayer1));
        assertTrue(bridge.hasRole(bridge.RELAYER_ROLE(), relayer2));
        assertTrue(bridge.hasRole(bridge.RELAYER_ROLE(), relayer3));
    }

    // ============ Lock Tests (Source Chain) ============

    function test_LockTokens() public {
        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);

        assertEq(token.balanceOf(user1), balanceBefore - BRIDGE_AMOUNT);
        assertEq(token.balanceOf(address(bridge)), BRIDGE_AMOUNT);
        assertEq(bridge.outboundNonce(), 1);
    }

    function test_LockTokens_EmitsEvent() public {
        vm.prank(user1);
        vm.expectEmit(false, true, true, true);
        // We don't know the exact transferId, so we skip first indexed param
        emit NexusBridge.TokensLocked(
            bytes32(0), // transferId (skipped)
            user1,
            user2,
            BRIDGE_AMOUNT,
            DEST_CHAIN_ID,
            0 // nonce (starts at 0)
        );
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);
    }

    function test_LockTokens_MultipleLocks() public {
        vm.startPrank(user1);
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);
        vm.stopPrank();

        assertEq(bridge.outboundNonce(), 3);
        assertEq(token.balanceOf(address(bridge)), BRIDGE_AMOUNT * 3);
    }

    function test_LockTokens_RevertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.lockTokens(user2, 0, DEST_CHAIN_ID);
    }

    function test_LockTokens_RevertZeroRecipient() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.lockTokens(address(0), BRIDGE_AMOUNT, DEST_CHAIN_ID);
    }

    function test_LockTokens_RevertUnsupportedChain() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.lockTokens(user2, BRIDGE_AMOUNT, 999); // Unsupported chain
    }

    function test_LockTokens_RevertExceedsSingleLimit() public {
        uint256 singleLimit = bridge.singleTransferLimit();

        vm.prank(user1);
        vm.expectRevert();
        bridge.lockTokens(user2, singleLimit + 1, DEST_CHAIN_ID);
    }

    // ============ Rate Limiting Tests ============

    function test_RateLimit_DailyLimit() public {
        uint256 dailyLimit = bridge.dailyLimit();
        uint256 singleLimit = bridge.singleTransferLimit();

        // Transfer up to daily limit in chunks
        uint256 transfers = dailyLimit / singleLimit;

        vm.startPrank(admin);
        token.transfer(user1, dailyLimit * 2); // Ensure enough tokens
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(bridge), type(uint256).max);

        for (uint256 i = 0; i < transfers; i++) {
            bridge.lockTokens(user2, singleLimit, DEST_CHAIN_ID);
        }

        // Next transfer should fail (exceeds daily limit)
        vm.expectRevert();
        bridge.lockTokens(user2, singleLimit, DEST_CHAIN_ID);
        vm.stopPrank();
    }

    function test_RateLimit_WindowReset() public {
        uint256 singleLimit = bridge.singleTransferLimit();

        vm.startPrank(admin);
        token.transfer(user1, singleLimit * 20);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(bridge), type(uint256).max);

        // Use up some of the daily limit
        bridge.lockTokens(user2, singleLimit, DEST_CHAIN_ID);
        bridge.lockTokens(user2, singleLimit, DEST_CHAIN_ID);

        uint256 windowTotalBefore = bridge.currentWindowTotal();
        assertGt(windowTotalBefore, 0);

        // Fast forward past rate limit window
        vm.warp(block.timestamp + 24 hours + 1);

        // Should be able to transfer again (window reset)
        bridge.lockTokens(user2, singleLimit, DEST_CHAIN_ID);

        vm.stopPrank();
    }

    // ============ Chain Management Tests ============

    function test_AddSupportedChain() public {
        uint256 newChainId = 42_161; // Arbitrum

        vm.prank(admin);
        bridge.addSupportedChain(newChainId);

        assertTrue(bridge.supportedChains(newChainId));
    }

    function test_RemoveSupportedChain() public {
        vm.prank(admin);
        bridge.removeSupportedChain(DEST_CHAIN_ID);

        assertFalse(bridge.supportedChains(DEST_CHAIN_ID));
    }

    function test_AddSupportedChain_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.addSupportedChain(42_161);
    }

    // ============ Relayer Threshold Tests ============

    function test_UpdateRelayerThreshold() public {
        vm.prank(admin);
        bridge.updateRelayerThreshold(3);

        assertEq(bridge.relayerThreshold(), 3);
    }

    function test_UpdateRelayerThreshold_RevertBelowMin() public {
        vm.prank(admin);
        vm.expectRevert();
        bridge.updateRelayerThreshold(1); // Below MIN_RELAYER_THRESHOLD
    }

    function test_UpdateRelayerThreshold_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.updateRelayerThreshold(3);
    }

    // ============ Limit Configuration Tests ============

    function test_UpdateDailyLimit() public {
        uint256 newLimit = 500_000 * 1e18;

        vm.prank(admin);
        bridge.updateDailyLimit(newLimit);

        assertEq(bridge.dailyLimit(), newLimit);
    }

    function test_UpdateSingleTransferLimit() public {
        uint256 newLimit = 50_000 * 1e18;

        vm.prank(admin);
        bridge.updateSingleTransferLimit(newLimit);

        assertEq(bridge.singleTransferLimit(), newLimit);
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        vm.prank(admin);
        bridge.pause();

        assertTrue(bridge.paused());

        vm.prank(user1);
        vm.expectRevert();
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);
    }

    function test_Unpause() public {
        vm.prank(admin);
        bridge.pause();

        vm.prank(admin);
        bridge.unpause();

        assertFalse(bridge.paused());

        // Should work now
        vm.prank(user1);
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);
    }

    function test_GuardianCanPause() public {
        vm.prank(guardian);
        bridge.pause();

        assertTrue(bridge.paused());
    }

    // ============ View Functions ============

    function test_GetRemainingDailyLimit() public {
        uint256 remaining = bridge.getRemainingDailyLimit();
        assertEq(remaining, bridge.dailyLimit());

        vm.prank(user1);
        bridge.lockTokens(user2, BRIDGE_AMOUNT, DEST_CHAIN_ID);

        uint256 newRemaining = bridge.getRemainingDailyLimit();
        assertEq(newRemaining, bridge.dailyLimit() - BRIDGE_AMOUNT);
    }

    // ============ Fuzz Tests ============

    function testFuzz_LockTokens(uint256 amount) public {
        uint256 singleLimit = bridge.singleTransferLimit();
        amount = bound(amount, 1, singleLimit);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        bridge.lockTokens(user2, amount, DEST_CHAIN_ID);

        assertEq(token.balanceOf(user1), balanceBefore - amount);
    }
}
