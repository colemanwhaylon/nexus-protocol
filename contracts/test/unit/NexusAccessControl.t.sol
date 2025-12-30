// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { NexusAccessControl } from "../../src/security/NexusAccessControl.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title NexusAccessControlTest
 * @notice Unit tests for NexusAccessControl contract
 * @dev Tests cover:
 *      - Role management (grant, revoke, renounce)
 *      - Role hierarchy and admin roles
 *      - Access checks and modifiers
 *      - Guardian activation/deactivation (SEC-010)
 *      - Two-step admin transfer (SEC-006)
 *      - Pause functionality
 */
contract NexusAccessControlTest is Test {
    NexusAccessControl public accessControl;

    address public admin = address(1);
    address public operator = address(2);
    address public compliance = address(3);
    address public pauser = address(4);
    address public guardian = address(5);
    address public upgrader = address(6);
    address public user1 = address(7);
    address public user2 = address(8);

    uint256 public constant GUARDIAN_ACTIVATION_DURATION = 7 days;
    uint256 public constant GUARDIAN_COOLDOWN = 30 days;
    uint256 public constant ADMIN_TRANSFER_DELAY = 48 hours;

    // Events
    event GuardianActivated(address indexed activator, uint256 activeUntil);
    event GuardianDeactivated(address indexed deactivator);
    event GuardianSunsetSet(uint256 sunsetTimestamp);
    event AdminTransferProposed(address indexed currentAdmin, address indexed pendingAdmin, uint256 proposedAt);
    event AdminTransferAccepted(address indexed oldAdmin, address indexed newAdmin);
    event AdminTransferCancelled(address indexed canceller, address indexed pendingAdmin);
    event ProtocolPaused(address indexed pauser, string reason);
    event ProtocolUnpaused(address indexed unpauser);

    function setUp() public {
        vm.startPrank(admin);
        // Deploy with 1 year guardian sunset
        accessControl = new NexusAccessControl(admin, block.timestamp + 365 days);
        vm.stopPrank();
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(accessControl.hasRole(accessControl.ADMIN_ROLE(), admin));
        assertTrue(accessControl.hasRole(accessControl.PAUSER_ROLE(), admin));
    }

    function test_Deployment_RevertZeroAddress() public {
        vm.expectRevert(NexusAccessControl.ZeroAddress.selector);
        new NexusAccessControl(address(0), block.timestamp + 365 days);
    }

    function test_Deployment_RevertPastSunset() public {
        // Warp forward so block.timestamp - 1 is non-zero
        vm.warp(1000);
        vm.expectRevert(NexusAccessControl.InvalidSunset.selector);
        new NexusAccessControl(admin, block.timestamp - 1);
    }

    function test_Deployment_NoSunset() public {
        NexusAccessControl noSunset = new NexusAccessControl(admin, 0);
        assertEq(noSunset.guardianSunset(), 0);
    }

    function test_RoleConstants() public view {
        assertEq(accessControl.ADMIN_ROLE(), keccak256("ADMIN_ROLE"));
        assertEq(accessControl.OPERATOR_ROLE(), keccak256("OPERATOR_ROLE"));
        assertEq(accessControl.COMPLIANCE_ROLE(), keccak256("COMPLIANCE_ROLE"));
        assertEq(accessControl.PAUSER_ROLE(), keccak256("PAUSER_ROLE"));
        assertEq(accessControl.GUARDIAN_ROLE(), keccak256("GUARDIAN_ROLE"));
        assertEq(accessControl.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"));
        assertEq(accessControl.SLASHER_ROLE(), keccak256("SLASHER_ROLE"));
    }

    // ============ Role Hierarchy Tests ============

    function test_RoleHierarchy_DefaultAdminIsAdmin() public view {
        // DEFAULT_ADMIN_ROLE is admin for ADMIN_ROLE
        assertEq(accessControl.getRoleAdmin(accessControl.ADMIN_ROLE()), accessControl.DEFAULT_ADMIN_ROLE());
    }

    function test_RoleHierarchy_AdminIsOperatorAdmin() public view {
        // ADMIN_ROLE is admin for OPERATOR_ROLE
        assertEq(accessControl.getRoleAdmin(accessControl.OPERATOR_ROLE()), accessControl.ADMIN_ROLE());
    }

    function test_RoleHierarchy_AdminIsComplianceAdmin() public view {
        assertEq(accessControl.getRoleAdmin(accessControl.COMPLIANCE_ROLE()), accessControl.ADMIN_ROLE());
    }

    function test_RoleHierarchy_AdminIsPauserAdmin() public view {
        assertEq(accessControl.getRoleAdmin(accessControl.PAUSER_ROLE()), accessControl.ADMIN_ROLE());
    }

    function test_RoleHierarchy_DefaultAdminIsGuardianAdmin() public view {
        assertEq(accessControl.getRoleAdmin(accessControl.GUARDIAN_ROLE()), accessControl.DEFAULT_ADMIN_ROLE());
    }

    function test_RoleHierarchy_DefaultAdminIsUpgraderAdmin() public view {
        assertEq(accessControl.getRoleAdmin(accessControl.UPGRADER_ROLE()), accessControl.DEFAULT_ADMIN_ROLE());
    }

    function test_RoleHierarchy_AdminIsSlasherAdmin() public view {
        assertEq(accessControl.getRoleAdmin(accessControl.SLASHER_ROLE()), accessControl.ADMIN_ROLE());
    }

    // ============ Role Grant Tests ============

    function test_GrantRole_OperatorByAdmin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(accessControl.OPERATOR_ROLE(), operator));
    }

    function test_GrantRole_ComplianceByAdmin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.COMPLIANCE_ROLE(), compliance);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(accessControl.COMPLIANCE_ROLE(), compliance));
    }

    function test_GrantRole_PauserByAdmin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(accessControl.PAUSER_ROLE(), pauser));
    }

    function test_GrantRole_GuardianByDefaultAdmin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(accessControl.GUARDIAN_ROLE(), guardian));
    }

    function test_GrantRole_UpgraderByDefaultAdmin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.UPGRADER_ROLE(), upgrader);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(accessControl.UPGRADER_ROLE(), upgrader));
    }

    function test_GrantRole_RevertUnauthorized() public {
        bytes32 role = accessControl.OPERATOR_ROLE();
        vm.prank(user1);
        vm.expectRevert();
        accessControl.grantRole(role, operator);
    }

    function test_GrantRole_RevertOperatorCantGrantOperator() public {
        // First grant OPERATOR_ROLE to operator
        bytes32 role = accessControl.OPERATOR_ROLE();
        vm.startPrank(admin);
        accessControl.grantRole(role, operator);
        vm.stopPrank();

        // Operator should not be able to grant OPERATOR_ROLE to others
        vm.prank(operator);
        vm.expectRevert();
        accessControl.grantRole(role, user1);
    }

    // ============ Role Revoke Tests ============

    function test_RevokeRole() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), operator);
        assertTrue(accessControl.hasRole(accessControl.OPERATOR_ROLE(), operator));

        accessControl.revokeRole(accessControl.OPERATOR_ROLE(), operator);
        assertFalse(accessControl.hasRole(accessControl.OPERATOR_ROLE(), operator));
        vm.stopPrank();
    }

    function test_RevokeRole_RevertUnauthorized() public {
        bytes32 role = accessControl.OPERATOR_ROLE();
        vm.startPrank(admin);
        accessControl.grantRole(role, operator);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        accessControl.revokeRole(role, operator);
    }

    // ============ Role Renounce Tests ============

    function test_RenounceRole() public {
        bytes32 role = accessControl.OPERATOR_ROLE();
        vm.startPrank(admin);
        accessControl.grantRole(role, operator);
        vm.stopPrank();

        vm.prank(operator);
        accessControl.renounceRole(role, operator);

        assertFalse(accessControl.hasRole(role, operator));
    }

    function test_RenounceRole_RevertWrongAccount() public {
        bytes32 role = accessControl.OPERATOR_ROLE();
        vm.startPrank(admin);
        accessControl.grantRole(role, operator);
        vm.stopPrank();

        // user1 cannot renounce operator's role
        vm.prank(user1);
        vm.expectRevert();
        accessControl.renounceRole(role, operator);
    }

    // ============ Role Enumeration Tests ============

    function test_GetRoleMember() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), operator);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), user1);
        vm.stopPrank();

        assertEq(accessControl.getRoleMemberCount(accessControl.OPERATOR_ROLE()), 2);
        assertEq(accessControl.getRoleMember(accessControl.OPERATOR_ROLE(), 0), operator);
        assertEq(accessControl.getRoleMember(accessControl.OPERATOR_ROLE(), 1), user1);
    }

    // ============ Guardian Activation Tests (SEC-010) ============

    function test_ActivateGuardian() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        vm.expectEmit(true, false, false, true);
        emit GuardianActivated(guardian, block.timestamp + GUARDIAN_ACTIVATION_DURATION);
        accessControl.activateGuardian();

        assertTrue(accessControl.isGuardianActive());
        assertEq(accessControl.guardianActiveUntil(), block.timestamp + GUARDIAN_ACTIVATION_DURATION);
    }

    function test_ActivateGuardian_RevertNotGuardian() public {
        vm.prank(user1);
        vm.expectRevert();
        accessControl.activateGuardian();
    }

    function test_ActivateGuardian_RevertAlreadyActive() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.startPrank(guardian);
        accessControl.activateGuardian();

        // Note: Cooldown check (30 days) comes before already-active check (7 days)
        // So when still in active period, we hit cooldown first
        vm.expectRevert(NexusAccessControl.GuardianInCooldown.selector);
        accessControl.activateGuardian();
        vm.stopPrank();
    }

    function test_ActivateGuardian_RevertInCooldown() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        // Fast forward past activation but still in cooldown
        vm.warp(block.timestamp + GUARDIAN_ACTIVATION_DURATION + 1);

        vm.prank(guardian);
        vm.expectRevert(NexusAccessControl.GuardianInCooldown.selector);
        accessControl.activateGuardian();
    }

    function test_ActivateGuardian_RevertAfterSunset() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        // Fast forward past sunset
        vm.warp(block.timestamp + 366 days);

        vm.prank(guardian);
        vm.expectRevert(NexusAccessControl.GuardianSunsetReached.selector);
        accessControl.activateGuardian();
    }

    function test_ActivateGuardian_AfterCooldown() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        // Fast forward past cooldown
        vm.warp(block.timestamp + GUARDIAN_COOLDOWN + 1);

        vm.prank(guardian);
        accessControl.activateGuardian();

        assertTrue(accessControl.isGuardianActive());
    }

    // ============ Guardian Deactivation Tests ============

    function test_DeactivateGuardian_ByGuardian() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();
        assertTrue(accessControl.isGuardianActive());

        vm.prank(guardian);
        vm.expectEmit(true, false, false, false);
        emit GuardianDeactivated(guardian);
        accessControl.deactivateGuardian();

        assertFalse(accessControl.isGuardianActive());
    }

    function test_DeactivateGuardian_ByAdmin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        vm.prank(admin);
        accessControl.deactivateGuardian();

        assertFalse(accessControl.isGuardianActive());
    }

    function test_DeactivateGuardian_RevertUnauthorized() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        vm.prank(user1);
        vm.expectRevert();
        accessControl.deactivateGuardian();
    }

    // ============ Guardian Sunset Tests ============

    function test_SetGuardianSunset() public {
        uint256 newSunset = block.timestamp + 180 days;

        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit GuardianSunsetSet(newSunset);
        accessControl.setGuardianSunset(newSunset);

        assertEq(accessControl.guardianSunset(), newSunset);
    }

    function test_SetGuardianSunset_RevertPast() public {
        vm.prank(admin);
        vm.expectRevert(NexusAccessControl.InvalidSunset.selector);
        accessControl.setGuardianSunset(block.timestamp - 1);
    }

    function test_SetGuardianSunset_RevertExtension() public {
        // Current sunset is block.timestamp + 365 days
        // Cannot extend it
        uint256 extended = block.timestamp + 400 days;

        vm.prank(admin);
        vm.expectRevert(NexusAccessControl.InvalidSunset.selector);
        accessControl.setGuardianSunset(extended);
    }

    function test_SetGuardianSunset_CanShorten() public {
        uint256 shorter = block.timestamp + 180 days;

        vm.prank(admin);
        accessControl.setGuardianSunset(shorter);

        assertEq(accessControl.guardianSunset(), shorter);
    }

    function test_SetGuardianSunset_RevertNotDefaultAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        accessControl.setGuardianSunset(block.timestamp + 100 days);
    }

    // ============ Guardian View Function Tests ============

    function test_IsGuardianActive_False_NotActivated() public view {
        assertFalse(accessControl.isGuardianActive());
    }

    function test_IsGuardianActive_False_AfterExpiry() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        vm.warp(block.timestamp + GUARDIAN_ACTIVATION_DURATION + 1);

        assertFalse(accessControl.isGuardianActive());
    }

    function test_IsGuardianActive_False_AfterSunset() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        // Warp to after sunset
        vm.warp(block.timestamp + 366 days);

        assertFalse(accessControl.isGuardianActive());
    }

    function test_GuardianTimeRemaining() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        assertEq(accessControl.guardianTimeRemaining(), GUARDIAN_ACTIVATION_DURATION);

        vm.warp(block.timestamp + 1 days);

        assertEq(accessControl.guardianTimeRemaining(), GUARDIAN_ACTIVATION_DURATION - 1 days);
    }

    function test_GuardianTimeRemaining_ZeroWhenNotActive() public view {
        assertEq(accessControl.guardianTimeRemaining(), 0);
    }

    function test_GuardianCooldownRemaining() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        assertEq(accessControl.guardianCooldownRemaining(), GUARDIAN_COOLDOWN);

        vm.warp(block.timestamp + 10 days);

        assertEq(accessControl.guardianCooldownRemaining(), GUARDIAN_COOLDOWN - 10 days);
    }

    function test_GuardianCooldownRemaining_ZeroAfterCooldown() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        vm.warp(block.timestamp + GUARDIAN_COOLDOWN + 1);

        assertEq(accessControl.guardianCooldownRemaining(), 0);
    }

    // ============ Two-Step Admin Transfer Tests (SEC-006) ============

    function test_ProposeAdminTransfer() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit AdminTransferProposed(admin, user1, block.timestamp);
        accessControl.proposeAdminTransfer(user1);

        assertEq(accessControl.pendingAdmin(), user1);
        assertEq(accessControl.pendingAdminProposedAt(), block.timestamp);
    }

    function test_ProposeAdminTransfer_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusAccessControl.ZeroAddress.selector);
        accessControl.proposeAdminTransfer(address(0));
    }

    function test_ProposeAdminTransfer_RevertNotDefaultAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        accessControl.proposeAdminTransfer(user2);
    }

    function test_AcceptAdminTransfer() public {
        vm.prank(admin);
        accessControl.proposeAdminTransfer(user1);

        // Fast forward past delay
        vm.warp(block.timestamp + ADMIN_TRANSFER_DELAY + 1);

        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit AdminTransferAccepted(admin, user1);
        accessControl.acceptAdminTransfer();

        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), user1));
        assertTrue(accessControl.hasRole(accessControl.ADMIN_ROLE(), user1));
        assertFalse(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), admin));
        assertFalse(accessControl.hasRole(accessControl.ADMIN_ROLE(), admin));
    }

    function test_AcceptAdminTransfer_RevertNotPendingAdmin() public {
        vm.prank(admin);
        accessControl.proposeAdminTransfer(user1);

        vm.warp(block.timestamp + ADMIN_TRANSFER_DELAY + 1);

        vm.prank(user2);
        vm.expectRevert(NexusAccessControl.NotPendingAdmin.selector);
        accessControl.acceptAdminTransfer();
    }

    function test_AcceptAdminTransfer_RevertDelayNotPassed() public {
        vm.prank(admin);
        accessControl.proposeAdminTransfer(user1);

        // Only half the delay
        vm.warp(block.timestamp + ADMIN_TRANSFER_DELAY / 2);

        vm.prank(user1);
        vm.expectRevert(NexusAccessControl.AdminTransferDelayNotPassed.selector);
        accessControl.acceptAdminTransfer();
    }

    function test_AcceptAdminTransfer_RevertNoPendingAdmin() public {
        vm.prank(user1);
        vm.expectRevert(NexusAccessControl.NotPendingAdmin.selector);
        accessControl.acceptAdminTransfer();
    }

    function test_CancelAdminTransfer_ByCurrentAdmin() public {
        vm.prank(admin);
        accessControl.proposeAdminTransfer(user1);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit AdminTransferCancelled(admin, user1);
        accessControl.cancelAdminTransfer();

        assertEq(accessControl.pendingAdmin(), address(0));
        assertEq(accessControl.pendingAdminProposedAt(), 0);
    }

    function test_CancelAdminTransfer_ByPendingAdmin() public {
        vm.prank(admin);
        accessControl.proposeAdminTransfer(user1);

        vm.prank(user1);
        accessControl.cancelAdminTransfer();

        assertEq(accessControl.pendingAdmin(), address(0));
    }

    function test_CancelAdminTransfer_RevertUnauthorized() public {
        vm.prank(admin);
        accessControl.proposeAdminTransfer(user1);

        vm.prank(user2);
        vm.expectRevert();
        accessControl.cancelAdminTransfer();
    }

    function test_CancelAdminTransfer_RevertNoPendingAdmin() public {
        vm.prank(admin);
        vm.expectRevert(NexusAccessControl.NoPendingAdmin.selector);
        accessControl.cancelAdminTransfer();
    }

    // ============ Pause Tests ============

    function test_Pause_ByPauser() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ProtocolPaused(admin, "Emergency");
        accessControl.pause("Emergency");

        assertTrue(accessControl.paused());
    }

    function test_Pause_ByActiveGuardian() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        vm.prank(guardian);
        accessControl.activateGuardian();

        vm.prank(guardian);
        accessControl.pause("Guardian emergency");

        assertTrue(accessControl.paused());
    }

    function test_Pause_RevertInactiveGuardian() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.GUARDIAN_ROLE(), guardian);
        vm.stopPrank();

        // Guardian not activated
        vm.prank(guardian);
        vm.expectRevert();
        accessControl.pause("Should fail");
    }

    function test_Pause_RevertUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        accessControl.pause("Should fail");
    }

    function test_Unpause() public {
        vm.startPrank(admin);
        accessControl.pause("Emergency");
        assertTrue(accessControl.paused());

        vm.expectEmit(true, false, false, false);
        emit ProtocolUnpaused(admin);
        accessControl.unpause();
        assertFalse(accessControl.paused());
        vm.stopPrank();
    }

    function test_Unpause_RevertNotAdmin() public {
        vm.prank(admin);
        accessControl.pause("Emergency");

        // Pauser cannot unpause (only admin)
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        // Even though pauser has PAUSER_ROLE, unpause requires ADMIN_ROLE
        // Note: admin also has ADMIN_ROLE, so this test grants pauser role to another account
        vm.prank(user1);
        vm.expectRevert();
        accessControl.unpause();
    }

    // ============ hasPrivilegedRole Tests ============

    function test_HasPrivilegedRole_DefaultAdmin() public view {
        assertTrue(accessControl.hasPrivilegedRole(admin));
    }

    function test_HasPrivilegedRole_Admin() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.ADMIN_ROLE(), user1);
        vm.stopPrank();

        assertTrue(accessControl.hasPrivilegedRole(user1));
    }

    function test_HasPrivilegedRole_Operator() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        assertTrue(accessControl.hasPrivilegedRole(operator));
    }

    function test_HasPrivilegedRole_False_RegularUser() public view {
        assertFalse(accessControl.hasPrivilegedRole(user1));
    }

    function test_HasPrivilegedRole_False_OnlyPauser() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        // Pauser alone is not a privileged role
        assertFalse(accessControl.hasPrivilegedRole(pauser));
    }

    // ============ Edge Cases ============

    function test_MultipleRoles() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), user1);
        accessControl.grantRole(accessControl.COMPLIANCE_ROLE(), user1);
        accessControl.grantRole(accessControl.PAUSER_ROLE(), user1);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(accessControl.OPERATOR_ROLE(), user1));
        assertTrue(accessControl.hasRole(accessControl.COMPLIANCE_ROLE(), user1));
        assertTrue(accessControl.hasRole(accessControl.PAUSER_ROLE(), user1));
    }

    function test_RevokeOneRoleKeepOthers() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.OPERATOR_ROLE(), user1);
        accessControl.grantRole(accessControl.COMPLIANCE_ROLE(), user1);

        accessControl.revokeRole(accessControl.OPERATOR_ROLE(), user1);
        vm.stopPrank();

        assertFalse(accessControl.hasRole(accessControl.OPERATOR_ROLE(), user1));
        assertTrue(accessControl.hasRole(accessControl.COMPLIANCE_ROLE(), user1));
    }

    function testFuzz_GrantRevokeRole(address account, uint256 roleSeed) public {
        vm.assume(account != address(0));
        vm.assume(account != admin);

        // Pick a role based on seed
        bytes32[] memory roles = new bytes32[](4);
        roles[0] = accessControl.OPERATOR_ROLE();
        roles[1] = accessControl.COMPLIANCE_ROLE();
        roles[2] = accessControl.PAUSER_ROLE();
        roles[3] = accessControl.SLASHER_ROLE();

        bytes32 role = roles[roleSeed % roles.length];

        vm.startPrank(admin);
        accessControl.grantRole(role, account);
        assertTrue(accessControl.hasRole(role, account));

        accessControl.revokeRole(role, account);
        assertFalse(accessControl.hasRole(role, account));
        vm.stopPrank();
    }
}
