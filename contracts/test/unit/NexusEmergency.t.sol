// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { NexusEmergency } from "../../src/security/NexusEmergency.sol";
import { NexusAccessControl } from "../../src/security/NexusAccessControl.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

/**
 * @title NexusEmergencyTest
 * @notice Unit tests for NexusEmergency contract
 * @dev Tests cover:
 *      - Circuit breakers (contract and global pause)
 *      - Pause/unpause functionality
 *      - Emergency drain with 72-hour timelock (SEC-004)
 *      - User self-rescue after 30-day pause (SEC-004)
 *      - Recovery mode
 *      - Multisig approval
 */
contract NexusEmergencyTest is Test {
    NexusEmergency public emergency;
    NexusAccessControl public accessControl;
    ERC20Mock public token;

    address public admin = address(1);
    address public guardian = address(2);
    address public pauser = address(3);
    address public user1 = address(4);
    address public user2 = address(5);
    address public multisig;

    uint256 public constant USER_RESCUE_DELAY = 30 days;
    uint256 public constant EMERGENCY_DRAIN_DELAY = 72 hours;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1_000_000 ether;

    // Events
    event ContractPaused(address indexed contractAddress, address indexed pauser);
    event ContractUnpaused(address indexed contractAddress, address indexed unpauser);
    event GlobalPauseInitiated(address indexed initiator, uint256 timestamp);
    event GlobalPauseLifted(address indexed lifter);
    event DrainRequested(
        bytes32 indexed requestId,
        address indexed token,
        address indexed targetContract,
        address destination,
        uint256 amount,
        uint256 executeAfter
    );
    event DrainExecuted(bytes32 indexed requestId, address indexed executor);
    event DrainCancelled(bytes32 indexed requestId, address indexed canceller);
    event MultisigApproved(address indexed multisig, address indexed approver);
    event MultisigRevoked(address indexed multisig, address indexed revoker);
    event UserRescueExecuted(
        address indexed user, address indexed token, address indexed sourceContract, uint256 amount
    );
    event RecoveryModeActivated(address indexed activator);
    event RecoveryModeDeactivated(address indexed deactivator);
    event RescueContractRegistered(address indexed contractAddress);

    function setUp() public {
        // Deploy access control
        vm.startPrank(admin);
        accessControl = new NexusAccessControl(admin, block.timestamp + 365 days);

        // Grant roles
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        accessControl.grantRole(accessControl.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        // Deploy emergency contract
        emergency = new NexusEmergency(address(accessControl));

        // Deploy mock token and transfer to emergency contract
        token = new ERC20Mock("Test Token", "TEST", 18);
        token.mint(address(emergency), INITIAL_TOKEN_SUPPLY);

        // Create a multisig (using a contract for testing)
        multisig = address(new MockMultisig());
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(emergency.accessControl(), address(accessControl));
        assertFalse(emergency.globalPause());
        assertEq(emergency.pauseInitiatedAt(), 0);
    }

    function test_Deployment_RevertZeroAddress() public {
        vm.expectRevert(NexusEmergency.ZeroAddress.selector);
        new NexusEmergency(address(0));
    }

    // ============ Contract Pause Tests ============

    function test_PauseContract_ByPauser() public {
        address target = address(0x123);

        vm.prank(pauser);
        vm.expectEmit(true, true, false, false);
        emit ContractPaused(target, pauser);
        emergency.pauseContract(target);

        assertTrue(emergency.contractPaused(target));
    }

    function test_PauseContract_ByGuardian() public {
        address target = address(0x123);

        vm.prank(guardian);
        emergency.pauseContract(target);

        assertTrue(emergency.contractPaused(target));
    }

    function test_PauseContract_RevertAlreadyPaused() public {
        address target = address(0x123);

        vm.prank(pauser);
        emergency.pauseContract(target);

        vm.prank(pauser);
        vm.expectRevert(NexusEmergency.AlreadyPaused.selector);
        emergency.pauseContract(target);
    }

    function test_PauseContract_RevertZeroAddress() public {
        vm.prank(pauser);
        vm.expectRevert(NexusEmergency.ZeroAddress.selector);
        emergency.pauseContract(address(0));
    }

    function test_PauseContract_RevertUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.pauseContract(address(0x123));
    }

    function test_UnpauseContract() public {
        address target = address(0x123);

        vm.prank(pauser);
        emergency.pauseContract(target);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit ContractUnpaused(target, admin);
        emergency.unpauseContract(target);

        assertFalse(emergency.contractPaused(target));
    }

    function test_UnpauseContract_RevertNotPaused() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.NotPaused.selector);
        emergency.unpauseContract(address(0x123));
    }

    function test_UnpauseContract_RevertNotAdmin() public {
        address target = address(0x123);

        vm.prank(pauser);
        emergency.pauseContract(target);

        vm.prank(pauser);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.unpauseContract(target);
    }

    // ============ Global Pause Tests ============

    function test_InitiateGlobalPause() public {
        vm.prank(pauser);
        vm.expectEmit(true, false, false, true);
        emit GlobalPauseInitiated(pauser, block.timestamp);
        emergency.initiateGlobalPause();

        assertTrue(emergency.globalPause());
        assertEq(emergency.pauseInitiatedAt(), block.timestamp);
    }

    function test_InitiateGlobalPause_ByGuardian() public {
        vm.prank(guardian);
        emergency.initiateGlobalPause();

        assertTrue(emergency.globalPause());
    }

    function test_InitiateGlobalPause_RevertAlreadyPaused() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(pauser);
        vm.expectRevert(NexusEmergency.AlreadyPaused.selector);
        emergency.initiateGlobalPause();
    }

    function test_InitiateGlobalPause_RevertUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.initiateGlobalPause();
    }

    function test_LiftGlobalPause() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit GlobalPauseLifted(admin);
        emergency.liftGlobalPause();

        assertFalse(emergency.globalPause());
        assertEq(emergency.pauseInitiatedAt(), 0);
    }

    function test_LiftGlobalPause_RevertNotPaused() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.NotPaused.selector);
        emergency.liftGlobalPause();
    }

    function test_LiftGlobalPause_RevertNotAdmin() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(pauser);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.liftGlobalPause();
    }

    // ============ isPaused View Function Tests ============

    function test_IsPaused_GlobalPause() public {
        address target = address(0x123);

        assertFalse(emergency.isPaused(target));

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        assertTrue(emergency.isPaused(target));
    }

    function test_IsPaused_ContractPause() public {
        address target = address(0x123);

        assertFalse(emergency.isPaused(target));

        vm.prank(pauser);
        emergency.pauseContract(target);

        assertTrue(emergency.isPaused(target));
    }

    function test_IsPaused_Both() public {
        address target = address(0x123);

        vm.startPrank(pauser);
        emergency.pauseContract(target);
        emergency.initiateGlobalPause();
        vm.stopPrank();

        assertTrue(emergency.isPaused(target));
    }

    // ============ Multisig Approval Tests ============

    function test_ApproveMultisig() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit MultisigApproved(multisig, admin);
        emergency.approveMultisig(multisig);

        assertTrue(emergency.approvedMultisigs(multisig));
    }

    function test_ApproveMultisig_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.ZeroAddress.selector);
        emergency.approveMultisig(address(0));
    }

    function test_ApproveMultisig_RevertNotContract() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.InvalidMultisig.selector);
        emergency.approveMultisig(user1); // EOA, not contract
    }

    function test_ApproveMultisig_RevertNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.approveMultisig(multisig);
    }

    function test_RevokeMultisig() public {
        vm.startPrank(admin);
        emergency.approveMultisig(multisig);

        vm.expectEmit(true, true, false, false);
        emit MultisigRevoked(multisig, admin);
        emergency.revokeMultisig(multisig);
        vm.stopPrank();

        assertFalse(emergency.approvedMultisigs(multisig));
    }

    // ============ Emergency Drain Tests (SEC-004) ============

    function test_InitiateDrain() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        uint256 amount = 100 ether;

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, amount);

        NexusEmergency.DrainRequest memory request = emergency.getDrainRequest(requestId);
        assertEq(request.token, address(token));
        assertEq(request.targetContract, address(emergency));
        assertEq(request.destination, multisig);
        assertEq(request.amount, amount);
        assertEq(request.initiatedAt, block.timestamp);
        assertFalse(request.executed);
        assertFalse(request.cancelled);
    }

    function test_InitiateDrain_RevertNotPaused() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.NotPaused.selector);
        emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);
    }

    function test_InitiateDrain_RevertInvalidMultisig() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.InvalidMultisig.selector);
        emergency.initiateDrain(address(token), address(emergency), user1, 100 ether);
    }

    function test_InitiateDrain_RevertInvalidAmount() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.InvalidAmount.selector);
        emergency.initiateDrain(address(token), address(emergency), multisig, 0);
    }

    function test_InitiateDrain_RevertNotAdmin() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(user1);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);
    }

    function test_ExecuteDrain() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        uint256 amount = 100 ether;

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, amount);

        // Fast forward past drain delay
        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY + 1);

        uint256 balanceBefore = token.balanceOf(multisig);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit DrainExecuted(requestId, admin);
        emergency.executeDrain(requestId);

        uint256 balanceAfter = token.balanceOf(multisig);
        assertEq(balanceAfter - balanceBefore, amount);

        NexusEmergency.DrainRequest memory request = emergency.getDrainRequest(requestId);
        assertTrue(request.executed);
    }

    function test_ExecuteDrain_RevertNotReady() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        // Only half the delay
        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY / 2);

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.DrainNotReady.selector);
        emergency.executeDrain(requestId);
    }

    function test_ExecuteDrain_RevertAlreadyExecuted() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY + 1);

        vm.prank(admin);
        emergency.executeDrain(requestId);

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.DrainAlreadyExecuted.selector);
        emergency.executeDrain(requestId);
    }

    function test_ExecuteDrain_RevertCancelled() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        vm.prank(admin);
        emergency.cancelDrain(requestId);

        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY + 1);

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.DrainCancelledOrNotFound.selector);
        emergency.executeDrain(requestId);
    }

    function test_CancelDrain() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit DrainCancelled(requestId, admin);
        emergency.cancelDrain(requestId);

        NexusEmergency.DrainRequest memory request = emergency.getDrainRequest(requestId);
        assertTrue(request.cancelled);
    }

    function test_CancelDrain_RevertNotFound() public {
        bytes32 fakeRequestId = keccak256("fake");

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.DrainCancelledOrNotFound.selector);
        emergency.cancelDrain(fakeRequestId);
    }

    function test_CancelDrain_RevertAlreadyExecuted() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY + 1);

        vm.prank(admin);
        emergency.executeDrain(requestId);

        vm.prank(admin);
        vm.expectRevert(NexusEmergency.DrainAlreadyExecuted.selector);
        emergency.cancelDrain(requestId);
    }

    function test_GetDrainTimeRemaining() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        assertEq(emergency.getDrainTimeRemaining(requestId), EMERGENCY_DRAIN_DELAY);

        vm.warp(block.timestamp + 24 hours);
        assertEq(emergency.getDrainTimeRemaining(requestId), EMERGENCY_DRAIN_DELAY - 24 hours);

        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY);
        assertEq(emergency.getDrainTimeRemaining(requestId), 0);
    }

    function test_GetPendingDrainCount() public {
        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        assertEq(emergency.getPendingDrainCount(), 0);

        vm.prank(admin);
        emergency.initiateDrain(address(token), address(emergency), multisig, 100 ether);

        assertEq(emergency.getPendingDrainCount(), 1);

        vm.prank(admin);
        emergency.initiateDrain(address(token), address(emergency), multisig, 200 ether);

        assertEq(emergency.getPendingDrainCount(), 2);
    }

    // ============ ETH Drain Tests ============

    function test_ExecuteDrain_ETH() public {
        // Send ETH to emergency contract
        vm.deal(address(emergency), 10 ether);

        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        uint256 amount = 5 ether;

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(
            address(0), // address(0) for ETH
            address(emergency),
            multisig,
            amount
        );

        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY + 1);

        uint256 balanceBefore = multisig.balance;

        vm.prank(admin);
        emergency.executeDrain(requestId);

        uint256 balanceAfter = multisig.balance;
        assertEq(balanceAfter - balanceBefore, amount);
    }

    // ============ User Self-Rescue Tests (SEC-004) ============

    function test_RegisterRescueContract() public {
        address rescueContract = address(0x123);

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit RescueContractRegistered(rescueContract);
        emergency.registerRescueContract(rescueContract);

        assertTrue(emergency.rescueEnabledContracts(rescueContract));
    }

    function test_RegisterRescueContract_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.ZeroAddress.selector);
        emergency.registerRescueContract(address(0));
    }

    function test_UserRescue() public {
        address rescueContract = address(0x456);

        vm.prank(admin);
        emergency.registerRescueContract(rescueContract);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        // Fast forward past rescue delay
        vm.warp(block.timestamp + USER_RESCUE_DELAY + 1);

        uint256 amount = 50 ether;

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit UserRescueExecuted(user1, address(token), rescueContract, amount);
        emergency.userRescue(address(token), rescueContract, amount);

        assertEq(emergency.rescuedBalances(user1, address(token)), amount);
    }

    function test_UserRescue_RevertNotPaused() public {
        address rescueContract = address(0x456);

        vm.prank(admin);
        emergency.registerRescueContract(rescueContract);

        vm.prank(user1);
        vm.expectRevert(NexusEmergency.NotPaused.selector);
        emergency.userRescue(address(token), rescueContract, 50 ether);
    }

    function test_UserRescue_RevertContractNotRegistered() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.warp(block.timestamp + USER_RESCUE_DELAY + 1);

        vm.prank(user1);
        vm.expectRevert(NexusEmergency.ContractNotRegistered.selector);
        emergency.userRescue(address(token), address(0x999), 50 ether);
    }

    function test_UserRescue_RevertTooEarly() public {
        address rescueContract = address(0x456);

        vm.prank(admin);
        emergency.registerRescueContract(rescueContract);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        // Only half the delay
        vm.warp(block.timestamp + USER_RESCUE_DELAY / 2);

        vm.prank(user1);
        vm.expectRevert(NexusEmergency.RescueTooEarly.selector);
        emergency.userRescue(address(token), rescueContract, 50 ether);
    }

    function test_UserRescue_RevertInvalidAmount() public {
        address rescueContract = address(0x456);

        vm.prank(admin);
        emergency.registerRescueContract(rescueContract);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.warp(block.timestamp + USER_RESCUE_DELAY + 1);

        vm.prank(user1);
        vm.expectRevert(NexusEmergency.InvalidAmount.selector);
        emergency.userRescue(address(token), rescueContract, 0);
    }

    function test_IsRescueAvailable() public {
        assertFalse(emergency.isRescueAvailable());

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        assertFalse(emergency.isRescueAvailable());

        vm.warp(block.timestamp + USER_RESCUE_DELAY + 1);

        assertTrue(emergency.isRescueAvailable());
    }

    function test_TimeUntilRescue() public {
        // Not paused - returns max uint256
        assertEq(emergency.timeUntilRescue(), type(uint256).max);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        assertEq(emergency.timeUntilRescue(), USER_RESCUE_DELAY);

        vm.warp(block.timestamp + 10 days);

        assertEq(emergency.timeUntilRescue(), USER_RESCUE_DELAY - 10 days);

        vm.warp(block.timestamp + USER_RESCUE_DELAY);

        assertEq(emergency.timeUntilRescue(), 0);
    }

    // ============ Recovery Mode Tests ============

    function test_ActivateRecoveryMode() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit RecoveryModeActivated(admin);
        emergency.activateRecoveryMode();

        assertTrue(emergency.recoveryMode());
    }

    function test_ActivateRecoveryMode_RevertNotPaused() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.NotPaused.selector);
        emergency.activateRecoveryMode();
    }

    function test_ActivateRecoveryMode_RevertNotAdmin() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(user1);
        vm.expectRevert(NexusEmergency.Unauthorized.selector);
        emergency.activateRecoveryMode();
    }

    function test_DeactivateRecoveryMode() public {
        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.startPrank(admin);
        emergency.activateRecoveryMode();

        vm.expectEmit(true, false, false, false);
        emit RecoveryModeDeactivated(admin);
        emergency.deactivateRecoveryMode();
        vm.stopPrank();

        assertFalse(emergency.recoveryMode());
    }

    function test_EnableContractRecovery() public {
        address target = address(0x789);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.startPrank(admin);
        emergency.activateRecoveryMode();
        emergency.enableContractRecovery(target);
        vm.stopPrank();

        assertTrue(emergency.recoveryModeContracts(target));
    }

    function test_EnableContractRecovery_RevertNotInRecoveryMode() public {
        vm.prank(admin);
        vm.expectRevert(NexusEmergency.NotInRecoveryMode.selector);
        emergency.enableContractRecovery(address(0x789));
    }

    // ============ Receive ETH Test ============

    function test_ReceiveETH() public {
        vm.deal(user1, 1 ether);

        vm.prank(user1);
        (bool success,) = address(emergency).call{ value: 1 ether }("");
        assertTrue(success);

        assertEq(address(emergency).balance, 1 ether);
    }

    // ============ Edge Cases ============

    function test_MultipleUserRescues() public {
        address rescueContract = address(0x456);

        vm.prank(admin);
        emergency.registerRescueContract(rescueContract);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.warp(block.timestamp + USER_RESCUE_DELAY + 1);

        // First rescue
        vm.prank(user1);
        emergency.userRescue(address(token), rescueContract, 50 ether);

        // Second rescue adds to balance
        vm.prank(user1);
        emergency.userRescue(address(token), rescueContract, 25 ether);

        assertEq(emergency.rescuedBalances(user1, address(token)), 75 ether);
    }

    function testFuzz_DrainAmount(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_TOKEN_SUPPLY);

        vm.prank(admin);
        emergency.approveMultisig(multisig);

        vm.prank(pauser);
        emergency.initiateGlobalPause();

        vm.prank(admin);
        bytes32 requestId = emergency.initiateDrain(address(token), address(emergency), multisig, amount);

        vm.warp(block.timestamp + EMERGENCY_DRAIN_DELAY + 1);

        vm.prank(admin);
        emergency.executeDrain(requestId);

        assertEq(token.balanceOf(multisig), amount);
    }
}

// ============ Mock Contracts ============

contract MockMultisig {
    receive() external payable { }
}
