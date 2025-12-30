// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {NexusBridge} from "../../src/bridge/NexusBridge.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NexusBridgeFuzzTest
 * @notice Fuzz tests for NexusBridge contract
 * @dev Tests rate limiting, signature verification, and cross-chain operations
 */
contract NexusBridgeFuzzTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    NexusBridge public bridge;
    ERC20Mock public token;

    address public admin;
    uint256 public adminKey;

    // Relayer keys for signing
    uint256[] public relayerKeys;
    address[] public relayers;

    uint256 public constant SOURCE_CHAIN_ID = 1;
    uint256 public constant DEST_CHAIN_ID = 137;
    uint256 public constant DEFAULT_DAILY_LIMIT = 1_000_000e18;
    uint256 public constant DEFAULT_SINGLE_LIMIT = 100_000e18;
    uint256 public constant LARGE_TRANSFER_THRESHOLD = 50_000e18;
    uint256 public constant RATE_LIMIT_WINDOW = 24 hours;

    function setUp() public {
        (admin, adminKey) = makeAddrAndKey("admin");

        // Create 3 relayers
        for (uint256 i = 0; i < 3; i++) {
            (address relayer, uint256 key) = makeAddrAndKey(string(abi.encodePacked("relayer", i)));
            relayers.push(relayer);
            relayerKeys.push(key);
        }

        // Sort relayers by address (required for signature verification)
        _sortRelayers();

        token = new ERC20Mock("Nexus Token", "NEXUS", 18);

        vm.prank(admin);
        bridge = new NexusBridge(
            address(token),
            SOURCE_CHAIN_ID,
            true, // isSourceChain
            2,    // relayerThreshold
            relayers
        );

        // Add supported chain
        vm.prank(admin);
        bridge.addSupportedChain(DEST_CHAIN_ID);

        // Fund bridge for unlocking
        token.mint(address(bridge), DEFAULT_DAILY_LIMIT * 10);
    }

    function _sortRelayers() internal {
        // Simple bubble sort for 3 relayers
        for (uint256 i = 0; i < relayers.length - 1; i++) {
            for (uint256 j = 0; j < relayers.length - i - 1; j++) {
                if (relayers[j] > relayers[j + 1]) {
                    (relayers[j], relayers[j + 1]) = (relayers[j + 1], relayers[j]);
                    (relayerKeys[j], relayerKeys[j + 1]) = (relayerKeys[j + 1], relayerKeys[j]);
                }
            }
        }
    }

    function _createSignatures(bytes32 messageHash, uint256 count) internal view returns (bytes[] memory) {
        bytes[] memory sigs = new bytes[](count);
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();

        for (uint256 i = 0; i < count; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(relayerKeys[i], ethSignedHash);
            sigs[i] = abi.encodePacked(r, s, v);
        }

        return sigs;
    }

    // ============ Lock Tokens Fuzz Tests ============

    /**
     * @notice Fuzz test: Lock tokens transfers exact amount to bridge
     */
    function testFuzz_LockTokens_TransfersExactAmount(
        address sender,
        address recipient,
        uint256 amount
    ) public {
        vm.assume(sender != address(0) && sender != address(bridge));
        vm.assume(recipient != address(0));
        amount = bound(amount, 1, DEFAULT_SINGLE_LIMIT);

        token.mint(sender, amount);

        vm.startPrank(sender);
        token.approve(address(bridge), amount);

        uint256 bridgeBalanceBefore = token.balanceOf(address(bridge));
        uint256 senderBalanceBefore = token.balanceOf(sender);

        bridge.lockTokens(recipient, amount, DEST_CHAIN_ID);

        uint256 bridgeBalanceAfter = token.balanceOf(address(bridge));
        uint256 senderBalanceAfter = token.balanceOf(sender);

        assertEq(bridgeBalanceAfter - bridgeBalanceBefore, amount, "Bridge should receive exact amount");
        assertEq(senderBalanceBefore - senderBalanceAfter, amount, "Sender should send exact amount");
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Cannot lock more than single transfer limit
     */
    function testFuzz_LockTokens_RespectsTransferLimit(
        address sender,
        address recipient,
        uint256 amount
    ) public {
        vm.assume(sender != address(0) && sender != address(bridge));
        vm.assume(recipient != address(0));
        amount = bound(amount, DEFAULT_SINGLE_LIMIT + 1, DEFAULT_SINGLE_LIMIT * 2);

        token.mint(sender, amount);

        vm.startPrank(sender);
        token.approve(address(bridge), amount);

        vm.expectRevert(NexusBridge.SingleTransferLimitExceeded.selector);
        bridge.lockTokens(recipient, amount, DEST_CHAIN_ID);
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Daily limit is enforced across multiple locks
     */
    function testFuzz_LockTokens_EnforcesDailyLimit(
        address sender,
        uint256[5] memory amounts
    ) public {
        vm.assume(sender != address(0) && sender != address(bridge));

        uint256 totalLocked = 0;

        for (uint256 i = 0; i < 5; i++) {
            uint256 amount = bound(amounts[i], 1, DEFAULT_SINGLE_LIMIT);

            if (totalLocked + amount > DEFAULT_DAILY_LIMIT) {
                // This should fail
                token.mint(sender, amount);
                vm.prank(sender);
                token.approve(address(bridge), amount);

                vm.prank(sender);
                vm.expectRevert(NexusBridge.DailyLimitExceeded.selector);
                bridge.lockTokens(address(1), amount, DEST_CHAIN_ID);
                break;
            }

            token.mint(sender, amount);
            vm.prank(sender);
            token.approve(address(bridge), amount);

            vm.prank(sender);
            bridge.lockTokens(address(1), amount, DEST_CHAIN_ID);
            totalLocked += amount;
        }
    }

    /**
     * @notice Fuzz test: Daily limit resets after window
     */
    function testFuzz_LockTokens_DailyLimitResetsAfterWindow(
        address sender,
        uint256 amount1,
        uint256 amount2
    ) public {
        vm.assume(sender != address(0) && sender != address(bridge));
        // amount1 must be <= DEFAULT_SINGLE_LIMIT and reasonable for daily limit
        amount1 = bound(amount1, 1e18, DEFAULT_SINGLE_LIMIT);
        amount2 = bound(amount2, 1e18, DEFAULT_SINGLE_LIMIT);

        // First lock
        token.mint(sender, amount1);
        vm.prank(sender);
        token.approve(address(bridge), amount1);
        vm.prank(sender);
        bridge.lockTokens(address(1), amount1, DEST_CHAIN_ID);

        // Wait for window to reset
        vm.warp(block.timestamp + RATE_LIMIT_WINDOW + 1);

        // Second lock should work
        token.mint(sender, amount2);
        vm.prank(sender);
        token.approve(address(bridge), amount2);
        vm.prank(sender);
        bridge.lockTokens(address(1), amount2, DEST_CHAIN_ID);
    }

    // ============ Unlock Tokens Fuzz Tests ============

    /**
     * @notice Fuzz test: Unlock with valid signatures succeeds
     */
    function testFuzz_UnlockTokens_ValidSignaturesSucceed(
        address recipient,
        uint256 amount,
        uint256 nonce
    ) public {
        vm.assume(recipient != address(0) && recipient != address(bridge));
        amount = bound(amount, 1, LARGE_TRANSFER_THRESHOLD - 1); // Below large transfer threshold
        nonce = bound(nonce, 0, type(uint128).max);

        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            DEST_CHAIN_ID, // sourceChain for unlock
            SOURCE_CHAIN_ID, // destChain (this chain)
            nonce
        ));

        bytes[] memory signatures = _createSignatures(transferId, 2);

        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);

        uint256 recipientBalanceAfter = token.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount, "Should receive exact amount");
    }

    /**
     * @notice Fuzz test: Cannot replay processed transfers
     */
    function testFuzz_UnlockTokens_CannotReplay(
        address recipient,
        uint256 amount,
        uint256 nonce
    ) public {
        vm.assume(recipient != address(0) && recipient != address(bridge));
        amount = bound(amount, 1, LARGE_TRANSFER_THRESHOLD - 1);
        nonce = bound(nonce, 0, type(uint128).max);

        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            DEST_CHAIN_ID,
            SOURCE_CHAIN_ID,
            nonce
        ));

        bytes[] memory signatures = _createSignatures(transferId, 2);

        // First unlock succeeds
        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);

        // Replay should fail
        vm.expectRevert(NexusBridge.TransferAlreadyProcessed.selector);
        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);
    }

    /**
     * @notice Fuzz test: Insufficient signatures fail
     */
    function testFuzz_UnlockTokens_InsufficientSignaturesFail(
        address recipient,
        uint256 amount,
        uint256 nonce
    ) public {
        vm.assume(recipient != address(0) && recipient != address(bridge));
        amount = bound(amount, 1, LARGE_TRANSFER_THRESHOLD - 1);
        nonce = bound(nonce, 0, type(uint128).max);

        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            DEST_CHAIN_ID,
            SOURCE_CHAIN_ID,
            nonce
        ));

        // Only 1 signature (threshold is 2)
        bytes[] memory signatures = _createSignatures(transferId, 1);

        vm.expectRevert(NexusBridge.InsufficientSignatures.selector);
        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);
    }

    // ============ Large Transfer Fuzz Tests ============

    /**
     * @notice Fuzz test: Large transfers are queued
     */
    function testFuzz_LargeTransfer_IsQueued(
        address recipient,
        uint256 amount,
        uint256 nonce
    ) public {
        vm.assume(recipient != address(0) && recipient != address(bridge));
        amount = bound(amount, LARGE_TRANSFER_THRESHOLD, DEFAULT_SINGLE_LIMIT);
        nonce = bound(nonce, 0, type(uint128).max);

        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            DEST_CHAIN_ID,
            SOURCE_CHAIN_ID,
            nonce
        ));

        bytes[] memory signatures = _createSignatures(transferId, 2);

        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);

        // Should not have received tokens yet
        uint256 recipientBalanceAfter = token.balanceOf(recipient);
        assertEq(recipientBalanceAfter, recipientBalanceBefore, "Should not receive tokens immediately");

        // Should be pending
        uint256 unlockTime = bridge.pendingLargeTransfers(transferId);
        assertTrue(unlockTime > 0, "Should be pending");
    }

    /**
     * @notice Fuzz test: Large transfer can be executed after delay
     */
    function testFuzz_LargeTransfer_ExecutableAfterDelay(
        address recipient,
        uint256 amount,
        uint256 nonce
    ) public {
        vm.assume(recipient != address(0) && recipient != address(bridge));
        amount = bound(amount, LARGE_TRANSFER_THRESHOLD, DEFAULT_SINGLE_LIMIT);
        nonce = bound(nonce, 0, type(uint128).max);

        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            DEST_CHAIN_ID,
            SOURCE_CHAIN_ID,
            nonce
        ));

        bytes[] memory signatures = _createSignatures(transferId, 2);

        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);

        // Wait for delay
        vm.warp(block.timestamp + 1 hours + 1);

        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        bridge.executeLargeTransfer(transferId, recipient, amount);

        uint256 recipientBalanceAfter = token.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount, "Should receive full amount");
    }

    /**
     * @notice Fuzz test: Large transfer cannot be executed before delay
     */
    function testFuzz_LargeTransfer_NotExecutableBeforeDelay(
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 waitTime
    ) public {
        vm.assume(recipient != address(0) && recipient != address(bridge));
        amount = bound(amount, LARGE_TRANSFER_THRESHOLD, DEFAULT_SINGLE_LIMIT);
        nonce = bound(nonce, 0, type(uint128).max);
        waitTime = bound(waitTime, 0, 1 hours - 1);

        bytes32 transferId = keccak256(abi.encode(
            recipient,
            amount,
            DEST_CHAIN_ID,
            SOURCE_CHAIN_ID,
            nonce
        ));

        bytes[] memory signatures = _createSignatures(transferId, 2);

        bridge.unlockTokens(recipient, amount, DEST_CHAIN_ID, nonce, signatures);

        vm.warp(block.timestamp + waitTime);

        vm.expectRevert(NexusBridge.TransferStillLocked.selector);
        bridge.executeLargeTransfer(transferId, recipient, amount);
    }

    // ============ Chain Support Fuzz Tests ============

    /**
     * @notice Fuzz test: Cannot lock to unsupported chain
     */
    function testFuzz_LockTokens_UnsupportedChainFails(
        address sender,
        uint256 amount,
        uint256 chainId
    ) public {
        vm.assume(sender != address(0) && sender != address(bridge));
        vm.assume(chainId != DEST_CHAIN_ID && chainId != 0);
        amount = bound(amount, 1, DEFAULT_SINGLE_LIMIT);

        token.mint(sender, amount);
        vm.prank(sender);
        token.approve(address(bridge), amount);

        vm.prank(sender);
        vm.expectRevert(NexusBridge.UnsupportedChain.selector);
        bridge.lockTokens(address(1), amount, chainId);
    }

    // ============ Admin Fuzz Tests ============

    /**
     * @notice Fuzz test: Admin can update daily limit
     */
    function testFuzz_UpdateDailyLimit(uint256 newLimit) public {
        newLimit = bound(newLimit, 1, type(uint128).max);

        vm.prank(admin);
        bridge.updateDailyLimit(newLimit);

        (,,,uint256 dailyLimit,) = bridge.getBridgeConfig();
        assertEq(dailyLimit, newLimit, "Daily limit should be updated");
    }

    /**
     * @notice Fuzz test: Admin can update single transfer limit
     */
    function testFuzz_UpdateSingleTransferLimit(uint256 newLimit) public {
        newLimit = bound(newLimit, 1, type(uint128).max);

        vm.prank(admin);
        bridge.updateSingleTransferLimit(newLimit);

        (,,,,uint256 singleLimit) = bridge.getBridgeConfig();
        assertEq(singleLimit, newLimit, "Single limit should be updated");
    }

    // ============ Invariant-style Tests ============

    /**
     * @notice Fuzz test: Nonce always increments
     */
    function testFuzz_Nonce_AlwaysIncrements(
        address sender,
        uint256 numLocks
    ) public {
        vm.assume(sender != address(0) && sender != address(bridge));
        numLocks = bound(numLocks, 1, 10);

        uint256 amount = 1e18;

        for (uint256 i = 0; i < numLocks; i++) {
            uint256 nonceBefore = bridge.outboundNonce();

            token.mint(sender, amount);
            vm.prank(sender);
            token.approve(address(bridge), amount);
            vm.prank(sender);
            bridge.lockTokens(address(1), amount, DEST_CHAIN_ID);

            uint256 nonceAfter = bridge.outboundNonce();
            assertEq(nonceAfter, nonceBefore + 1, "Nonce should increment by 1");
        }
    }
}
