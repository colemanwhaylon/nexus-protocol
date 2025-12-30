// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { NexusMultiSig } from "../../src/governance/NexusMultiSig.sol";
import { NexusToken } from "../../src/core/NexusToken.sol";

/**
 * @title NexusMultiSigTest
 * @notice Comprehensive unit tests for NexusMultiSig contract
 * @dev Tests cover:
 *      - Deployment and initialization
 *      - Transaction submission (single and batch)
 *      - Confirmation and revocation
 *      - Transaction execution
 *      - Owner management (add/remove)
 *      - Threshold management
 *      - Expiry management
 *      - Edge cases and error conditions
 */
contract NexusMultiSigTest is Test {
    NexusMultiSig public multiSig;
    NexusToken public token;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public owner4 = address(4);
    address public owner5 = address(5);
    address public nonOwner = address(6);
    address public newOwner = address(7);

    uint256 public constant THRESHOLD = 3; // 3-of-5 multisig
    uint256 public constant EXPIRY_PERIOD = 7 days;
    uint256 public constant TOKEN_AMOUNT = 1_000_000 * 1e18;

    // Events
    event WalletInitialized(address[] owners, uint256 threshold, uint256 expiryPeriod);
    event TransactionSubmitted(
        bytes32 indexed txHash,
        address indexed submitter,
        address indexed to,
        uint256 value,
        bytes data,
        uint256 nonce,
        uint256 deadline
    );
    event BatchSubmitted(
        bytes32 indexed batchHash, address indexed submitter, uint256 transactionCount, uint256 nonce, uint256 deadline
    );
    event TransactionConfirmed(bytes32 indexed txHash, address indexed confirmer, uint256 confirmationCount);
    event ConfirmationRevoked(bytes32 indexed txHash, address indexed revoker, uint256 confirmationCount);
    event TransactionExecuted(bytes32 indexed txHash, address indexed executor, bool success, bytes returnData);
    event BatchExecuted(
        bytes32 indexed batchHash, address indexed executor, uint256 successCount, uint256 failureCount
    );
    event OwnerAdded(address indexed owner, address indexed addedBy);
    event OwnerRemoved(address indexed owner, address indexed removedBy);
    event ThresholdChanged(uint256 oldThreshold, uint256 newThreshold);
    event ExpiryPeriodChanged(uint256 oldExpiry, uint256 newExpiry);
    event EtherReceived(address indexed sender, uint256 amount);

    function setUp() public {
        // Create owners array
        address[] memory owners = new address[](5);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        owners[3] = owner4;
        owners[4] = owner5;

        // Deploy multisig
        multiSig = new NexusMultiSig(owners, THRESHOLD, EXPIRY_PERIOD);

        // Deploy token for testing interactions
        token = new NexusToken(address(this));
        token.mint(address(multiSig), TOKEN_AMOUNT);

        // Fund multisig with ETH
        vm.deal(address(multiSig), 100 ether);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(multiSig.threshold(), THRESHOLD);
        assertEq(multiSig.expiryPeriod(), EXPIRY_PERIOD);
        assertEq(multiSig.getOwnerCount(), 5);
        assertEq(multiSig.nonce(), 0);

        assertTrue(multiSig.isOwner(owner1));
        assertTrue(multiSig.isOwner(owner2));
        assertTrue(multiSig.isOwner(owner3));
        assertTrue(multiSig.isOwner(owner4));
        assertTrue(multiSig.isOwner(owner5));
        assertFalse(multiSig.isOwner(nonOwner));
    }

    function test_Deployment_GetOwners() public view {
        address[] memory owners = multiSig.getOwners();
        assertEq(owners.length, 5);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
        assertEq(owners[3], owner4);
        assertEq(owners[4], owner5);
    }

    function test_Deployment_RevertInvalidOwnerCount_TooFew() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        vm.expectRevert(abi.encodeWithSelector(NexusMultiSig.InvalidOwnerCount.selector, 1, 2, 20));
        new NexusMultiSig(owners, 1, EXPIRY_PERIOD);
    }

    function test_Deployment_RevertInvalidThreshold_Zero() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vm.expectRevert(abi.encodeWithSelector(NexusMultiSig.InvalidThreshold.selector, 0, 3));
        new NexusMultiSig(owners, 0, EXPIRY_PERIOD);
    }

    function test_Deployment_RevertInvalidThreshold_ExceedsOwners() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vm.expectRevert(abi.encodeWithSelector(NexusMultiSig.InvalidThreshold.selector, 5, 3));
        new NexusMultiSig(owners, 5, EXPIRY_PERIOD);
    }

    function test_Deployment_RevertInvalidExpiryPeriod_TooShort() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vm.expectRevert(
            abi.encodeWithSelector(NexusMultiSig.InvalidExpiryPeriod.selector, 30 minutes, 1 hours, 30 days)
        );
        new NexusMultiSig(owners, 2, 30 minutes);
    }

    function test_Deployment_RevertInvalidExpiryPeriod_TooLong() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vm.expectRevert(abi.encodeWithSelector(NexusMultiSig.InvalidExpiryPeriod.selector, 60 days, 1 hours, 30 days));
        new NexusMultiSig(owners, 2, 60 days);
    }

    function test_Deployment_RevertZeroAddress() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = address(0);
        owners[2] = owner3;

        vm.expectRevert(NexusMultiSig.ZeroAddress.selector);
        new NexusMultiSig(owners, 2, EXPIRY_PERIOD);
    }

    function test_Deployment_RevertDuplicateOwner() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner1; // Duplicate
        owners[2] = owner3;

        vm.expectRevert(NexusMultiSig.AlreadyOwner.selector);
        new NexusMultiSig(owners, 2, EXPIRY_PERIOD);
    }

    // ============ Transaction Submission Tests ============

    function test_SubmitTransaction() public {
        bytes memory data = abi.encodeWithSignature("name()");

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(token), 0, data);

        assertGt(uint256(txHash), 0);
        assertTrue(multiSig.isSubmitted(txHash));
        assertEq(multiSig.confirmationCount(txHash), 1); // Auto-confirmed by submitter
        assertEq(multiSig.nonce(), 1);
    }

    function test_SubmitTransaction_EmitsEvents() public {
        bytes memory data = abi.encodeWithSignature("name()");

        // Skip checking txHash (first indexed param) since it's computed in contract
        vm.expectEmit(false, true, true, true);
        emit TransactionConfirmed(bytes32(0), owner1, 1); // Hash placeholder, not checked

        vm.prank(owner1);
        multiSig.submitTransaction(address(token), 0, data);
    }

    function test_SubmitTransaction_WithValue() public {
        bytes memory data = "";

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(nonOwner, 1 ether, data);

        NexusMultiSig.TransactionInfo memory info = multiSig.getTransaction(txHash);
        assertEq(info.to, nonOwner);
        assertEq(info.value, 1 ether);
        assertEq(info.data.length, 0);
    }

    function test_SubmitTransaction_RevertNotOwner() public {
        bytes memory data = abi.encodeWithSignature("name()");

        vm.prank(nonOwner);
        vm.expectRevert(NexusMultiSig.NotOwner.selector);
        multiSig.submitTransaction(address(token), 0, data);
    }

    function test_SubmitTransaction_RevertZeroAddress() public {
        bytes memory data = abi.encodeWithSignature("name()");

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ZeroAddress.selector);
        multiSig.submitTransaction(address(0), 0, data);
    }

    // ============ Batch Submission Tests ============

    function test_SubmitBatch() public {
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory data = new bytes[](3);

        targets[0] = address(token);
        targets[1] = address(token);
        targets[2] = nonOwner;

        values[0] = 0;
        values[1] = 0;
        values[2] = 1 ether;

        data[0] = abi.encodeWithSignature("name()");
        data[1] = abi.encodeWithSignature("symbol()");
        data[2] = "";

        vm.prank(owner1);
        bytes32 batchHash = multiSig.submitBatch(targets, values, data);

        assertGt(uint256(batchHash), 0);
        assertTrue(multiSig.isSubmitted(batchHash));
        assertEq(multiSig.confirmationCount(batchHash), 1);
    }

    function test_SubmitBatch_RevertEmptyBatch() public {
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory data = new bytes[](0);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.EmptyBatch.selector);
        multiSig.submitBatch(targets, values, data);
    }

    function test_SubmitBatch_RevertArrayLengthMismatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](3); // Mismatch
        bytes[] memory data = new bytes[](2);

        targets[0] = address(token);
        targets[1] = address(token);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ArrayLengthMismatch.selector);
        multiSig.submitBatch(targets, values, data);
    }

    function test_SubmitBatch_RevertZeroAddressInBatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = address(token);
        targets[1] = address(0); // Invalid

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ZeroAddress.selector);
        multiSig.submitBatch(targets, values, data);
    }

    // ============ Confirmation Tests ============

    function test_ConfirmTransaction() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        assertEq(multiSig.confirmationCount(txHash), 2);
        assertTrue(multiSig.confirmations(txHash, owner1));
        assertTrue(multiSig.confirmations(txHash, owner2));
    }

    function test_ConfirmTransaction_EmitsEvent() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.expectEmit(true, true, false, true);
        emit TransactionConfirmed(txHash, owner2, 2);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);
    }

    function test_ConfirmTransaction_MultipleConfirmers() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        assertEq(multiSig.confirmationCount(txHash), 3);
    }

    function test_ConfirmTransaction_RevertNotOwner() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(nonOwner);
        vm.expectRevert(NexusMultiSig.NotOwner.selector);
        multiSig.confirmTransaction(txHash);
    }

    function test_ConfirmTransaction_RevertNotSubmitted() public {
        bytes32 fakeTxHash = keccak256("fake");

        vm.prank(owner2);
        vm.expectRevert(NexusMultiSig.TransactionNotSubmitted.selector);
        multiSig.confirmTransaction(fakeTxHash);
    }

    function test_ConfirmTransaction_RevertAlreadyConfirmed() public {
        bytes32 txHash = _submitSimpleTransaction();

        // owner1 already confirmed during submission
        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.AlreadyConfirmed.selector);
        multiSig.confirmTransaction(txHash);
    }

    function test_ConfirmTransaction_RevertExpired() public {
        bytes32 txHash = _submitSimpleTransaction();

        // Fast forward past expiry
        vm.warp(block.timestamp + EXPIRY_PERIOD + 1);

        vm.prank(owner2);
        vm.expectRevert(NexusMultiSig.TransactionExpired.selector);
        multiSig.confirmTransaction(txHash);
    }

    // ============ Revocation Tests ============

    function test_RevokeConfirmation() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        assertEq(multiSig.confirmationCount(txHash), 2);

        vm.prank(owner2);
        multiSig.revokeConfirmation(txHash);

        assertEq(multiSig.confirmationCount(txHash), 1);
        assertFalse(multiSig.confirmations(txHash, owner2));
    }

    function test_RevokeConfirmation_EmitsEvent() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.expectEmit(true, true, false, true);
        emit ConfirmationRevoked(txHash, owner2, 1);

        vm.prank(owner2);
        multiSig.revokeConfirmation(txHash);
    }

    function test_RevokeConfirmation_RevertNotConfirmed() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        vm.expectRevert(NexusMultiSig.NotConfirmed.selector);
        multiSig.revokeConfirmation(txHash);
    }

    // ============ Execution Tests ============

    function test_ExecuteTransaction() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        uint256 balanceBefore = nonOwner.balance;

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        uint256 balanceAfter = nonOwner.balance;
        assertEq(balanceAfter, balanceBefore + 1 ether);

        NexusMultiSig.TransactionInfo memory info = multiSig.getTransaction(txHash);
        assertTrue(info.executed);
    }

    function test_ExecuteTransaction_EmitsEvent() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        vm.expectEmit(true, true, false, false);
        emit TransactionExecuted(txHash, owner1, true, "");

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);
    }

    function test_ExecuteTransaction_CallWithData() public {
        // Submit a transaction that calls token.name()
        bytes memory data = abi.encodeWithSignature("name()");

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(token), 0, data);

        // Get confirmations
        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        // Execute
        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        NexusMultiSig.TransactionInfo memory info = multiSig.getTransaction(txHash);
        assertTrue(info.executed);
    }

    function test_ExecuteTransaction_RevertInsufficientConfirmations() public {
        bytes32 txHash = _submitSimpleTransaction();

        // Only 1 confirmation (submitter)
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(NexusMultiSig.InsufficientConfirmations.selector, 1, 3));
        multiSig.executeTransaction(txHash);
    }

    function test_ExecuteTransaction_RevertAlreadyExecuted() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.TransactionAlreadyExecuted.selector);
        multiSig.executeTransaction(txHash);
    }

    function test_ExecuteTransaction_RevertExpired() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        // Fast forward past expiry
        vm.warp(block.timestamp + EXPIRY_PERIOD + 1);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.TransactionExpired.selector);
        multiSig.executeTransaction(txHash);
    }

    function test_ExecuteTransaction_RevertNotOwner() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        vm.prank(nonOwner);
        vm.expectRevert(NexusMultiSig.NotOwner.selector);
        multiSig.executeTransaction(txHash);
    }

    // ============ Batch Execution Tests ============

    function test_ExecuteBatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = nonOwner;
        targets[1] = owner1;

        values[0] = 1 ether;
        values[1] = 2 ether;

        data[0] = "";
        data[1] = "";

        vm.prank(owner1);
        bytes32 batchHash = multiSig.submitBatch(targets, values, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(batchHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(batchHash);

        uint256 nonOwnerBalanceBefore = nonOwner.balance;
        uint256 owner1BalanceBefore = owner1.balance;

        vm.prank(owner1);
        multiSig.executeBatch(batchHash);

        assertEq(nonOwner.balance, nonOwnerBalanceBefore + 1 ether);
        assertEq(owner1.balance, owner1BalanceBefore + 2 ether);
    }

    function test_ExecuteBatch_EmitsEvent() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = nonOwner;
        targets[1] = owner1;

        values[0] = 1 ether;
        values[1] = 2 ether;

        data[0] = "";
        data[1] = "";

        vm.prank(owner1);
        bytes32 batchHash = multiSig.submitBatch(targets, values, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(batchHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(batchHash);

        vm.expectEmit(true, true, false, true);
        emit BatchExecuted(batchHash, owner1, 2, 0);

        vm.prank(owner1);
        multiSig.executeBatch(batchHash);
    }

    // ============ Owner Management Tests ============

    function test_AddOwner() public {
        // Create transaction to add new owner
        bytes memory data = abi.encodeWithSignature("addOwner(address)", newOwner);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        assertTrue(multiSig.isOwner(newOwner));
        assertEq(multiSig.getOwnerCount(), 6);
    }

    function test_AddOwner_RevertNotSelf() public {
        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.NotOwner.selector);
        multiSig.addOwner(newOwner);
    }

    function test_AddOwner_RevertAlreadyOwner() public {
        bytes memory data = abi.encodeWithSignature("addOwner(address)", owner1); // Already owner

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ExecutionFailed.selector);
        multiSig.executeTransaction(txHash);
    }

    function test_RemoveOwner() public {
        bytes memory data = abi.encodeWithSignature("removeOwner(address)", owner5);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        assertFalse(multiSig.isOwner(owner5));
        assertEq(multiSig.getOwnerCount(), 4);
    }

    function test_RemoveOwner_RevertNotAnOwner() public {
        bytes memory data = abi.encodeWithSignature("removeOwner(address)", nonOwner);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ExecutionFailed.selector);
        multiSig.executeTransaction(txHash);
    }

    // ============ Threshold Management Tests ============

    function test_ChangeThreshold() public {
        bytes memory data = abi.encodeWithSignature("changeThreshold(uint256)", 2);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        assertEq(multiSig.threshold(), 2);
    }

    function test_ChangeThreshold_RevertInvalid_Zero() public {
        bytes memory data = abi.encodeWithSignature("changeThreshold(uint256)", 0);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ExecutionFailed.selector);
        multiSig.executeTransaction(txHash);
    }

    function test_ChangeThreshold_RevertInvalid_ExceedsOwners() public {
        bytes memory data = abi.encodeWithSignature("changeThreshold(uint256)", 10);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        vm.expectRevert(NexusMultiSig.ExecutionFailed.selector);
        multiSig.executeTransaction(txHash);
    }

    // ============ Expiry Period Management Tests ============

    function test_ChangeExpiryPeriod() public {
        uint256 newExpiry = 14 days;
        bytes memory data = abi.encodeWithSignature("changeExpiryPeriod(uint256)", newExpiry);

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(multiSig), 0, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        assertEq(multiSig.expiryPeriod(), newExpiry);
    }

    // ============ View Function Tests ============

    function test_GetTransaction() public {
        bytes memory data = abi.encodeWithSignature("name()");

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(address(token), 1 ether, data);

        NexusMultiSig.TransactionInfo memory info = multiSig.getTransaction(txHash);

        assertEq(info.to, address(token));
        assertEq(info.value, 1 ether);
        assertEq(keccak256(info.data), keccak256(data));
        assertEq(info.txNonce, 0);
        assertGt(info.deadline, block.timestamp);
        assertFalse(info.executed);
        assertEq(info.confirmCount, 1);
    }

    function test_GetBatchTransaction() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = address(token);
        targets[1] = nonOwner;
        values[0] = 0;
        values[1] = 1 ether;
        data[0] = "";
        data[1] = "";

        vm.prank(owner1);
        bytes32 batchHash = multiSig.submitBatch(targets, values, data);

        NexusMultiSig.BatchInfo memory info = multiSig.getBatchTransaction(batchHash);

        assertEq(info.targets.length, 2);
        assertEq(info.targets[0], address(token));
        assertEq(info.targets[1], nonOwner);
        assertEq(info.values[0], 0);
        assertEq(info.values[1], 1 ether);
        assertFalse(info.executed);
        assertEq(info.confirmCount, 1);
    }

    function test_IsReadyToExecute_True() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        (bool ready, string memory reason) = multiSig.isReadyToExecute(txHash);

        assertTrue(ready);
        assertEq(reason, "Ready");
    }

    function test_IsReadyToExecute_NotSubmitted() public {
        bytes32 fakeTxHash = keccak256("fake");

        (bool ready, string memory reason) = multiSig.isReadyToExecute(fakeTxHash);

        assertFalse(ready);
        assertEq(reason, "Not submitted");
    }

    function test_IsReadyToExecute_InsufficientConfirmations() public {
        bytes32 txHash = _submitSimpleTransaction();

        (bool ready, string memory reason) = multiSig.isReadyToExecute(txHash);

        assertFalse(ready);
        assertEq(reason, "Insufficient confirmations");
    }

    function test_IsReadyToExecute_Expired() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        vm.warp(block.timestamp + EXPIRY_PERIOD + 1);

        (bool ready, string memory reason) = multiSig.isReadyToExecute(txHash);

        assertFalse(ready);
        assertEq(reason, "Expired");
    }

    function test_IsReadyToExecute_AlreadyExecuted() public {
        bytes32 txHash = _submitAndFullyConfirmTransaction();

        vm.prank(owner1);
        multiSig.executeTransaction(txHash);

        (bool ready, string memory reason) = multiSig.isReadyToExecute(txHash);

        assertFalse(ready);
        assertEq(reason, "Already executed");
    }

    function test_GetConfirmers() public {
        bytes32 txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        address[] memory confirmers = multiSig.getConfirmers(txHash);

        assertEq(confirmers.length, 3);
        assertTrue(_contains(confirmers, owner1));
        assertTrue(_contains(confirmers, owner2));
        assertTrue(_contains(confirmers, owner3));
    }

    // ============ Receive ETH Tests ============

    function test_ReceiveEther() public {
        uint256 balanceBefore = address(multiSig).balance;

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, false, false, true);
        emit EtherReceived(address(this), 5 ether);

        (bool success,) = address(multiSig).call{ value: 5 ether }("");
        assertTrue(success);

        assertEq(address(multiSig).balance, balanceBefore + 5 ether);
    }

    // ============ Fuzz Tests ============

    function testFuzz_SubmitAndConfirm(uint256 value) public {
        value = bound(value, 0, 10 ether);

        bytes memory data = "";

        vm.prank(owner1);
        bytes32 txHash = multiSig.submitTransaction(nonOwner, value, data);

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        assertEq(multiSig.confirmationCount(txHash), 2);
    }

    function testFuzz_ExpectedThreshold(uint256 numOwners, uint256 threshold_) public {
        numOwners = bound(numOwners, 2, 20);
        threshold_ = bound(threshold_, 1, numOwners);

        address[] memory owners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            owners[i] = address(uint160(100 + i));
        }

        NexusMultiSig newMultiSig = new NexusMultiSig(owners, threshold_, EXPIRY_PERIOD);

        assertEq(newMultiSig.threshold(), threshold_);
        assertEq(newMultiSig.getOwnerCount(), numOwners);
    }

    // ============ Helper Functions ============

    function _submitSimpleTransaction() internal returns (bytes32 txHash) {
        bytes memory data = "";

        vm.prank(owner1);
        txHash = multiSig.submitTransaction(nonOwner, 1 ether, data);

        return txHash;
    }

    function _submitAndFullyConfirmTransaction() internal returns (bytes32 txHash) {
        txHash = _submitSimpleTransaction();

        vm.prank(owner2);
        multiSig.confirmTransaction(txHash);

        vm.prank(owner3);
        multiSig.confirmTransaction(txHash);

        return txHash;
    }

    function _contains(address[] memory arr, address target) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == target) {
                return true;
            }
        }
        return false;
    }
}

/**
 * @title RevertingReceiver
 * @notice Helper contract for testing failed calls
 */
contract RevertingReceiver {
    receive() external payable {
        revert("I always revert");
    }
}
