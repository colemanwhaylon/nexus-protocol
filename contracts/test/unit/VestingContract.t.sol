// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {VestingContract} from "../../src/defi/VestingContract.sol";
import {NexusToken} from "../../src/core/NexusToken.sol";

/**
 * @title VestingContractTest
 * @notice Unit tests for VestingContract
 * @dev Tests cover:
 *      - Schedule creation (linear, cliff)
 *      - Grant creation and management
 *      - Token release/claiming
 *      - Revocation mechanics
 *      - Access control
 *      - Beneficiary management
 */
contract VestingContractTest is Test {
    VestingContract public vesting;
    NexusToken public token;

    address public admin = address(1);
    address public grantManager = address(2);
    address public treasury = address(3);
    address public beneficiary1 = address(4);
    address public beneficiary2 = address(5);
    address public beneficiary3 = address(6);

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant GRANT_AMOUNT = 1_000_000 * 1e18;
    uint256 public constant MIN_VESTING_DURATION = 30 days;
    uint256 public constant MAX_VESTING_DURATION = 3650 days;
    uint256 public constant MAX_CLIFF_DURATION = 730 days;

    // Default schedule IDs (created in constructor)
    uint256 public constant SCHEDULE_1_YEAR_LINEAR = 1;
    uint256 public constant SCHEDULE_2_YEAR_6M_CLIFF = 2;
    uint256 public constant SCHEDULE_4_YEAR_1Y_CLIFF = 3;
    uint256 public constant SCHEDULE_6_MONTH_NON_REVOCABLE = 4;

    // Events
    event GrantCreated(
        uint256 indexed grantId,
        address indexed beneficiary,
        address indexed token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TokensClaimed(
        uint256 indexed grantId,
        address indexed beneficiary,
        uint256 amount,
        uint256 totalClaimed
    );

    event GrantRevoked(
        uint256 indexed grantId,
        address indexed beneficiary,
        uint256 vestedAmount,
        uint256 unvestedAmount,
        address revokedBy
    );

    event GrantCompleted(
        uint256 indexed grantId,
        address indexed beneficiary,
        uint256 totalAmount
    );

    event ScheduleCreated(
        uint256 indexed scheduleId,
        string name,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TreasuryUpdated(
        address indexed oldTreasury,
        address indexed newTreasury
    );

    event BeneficiaryChanged(
        uint256 indexed grantId,
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );

    function setUp() public {
        vm.startPrank(admin);

        // Deploy token
        token = new NexusToken(admin);
        token.mint(admin, INITIAL_SUPPLY);

        // Deploy vesting contract
        vesting = new VestingContract(treasury, admin);

        // Grant manager role
        vesting.grantRole(vesting.GRANT_MANAGER_ROLE(), grantManager);

        // Transfer tokens to grant manager for creating grants
        token.transfer(grantManager, GRANT_AMOUNT * 20);

        vm.stopPrank();

        // Grant manager approves vesting contract
        vm.prank(grantManager);
        token.approve(address(vesting), type(uint256).max);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(vesting.treasury(), treasury);
        assertEq(vesting.nextGrantId(), 1);
        assertEq(vesting.nextScheduleId(), 5); // 4 default schedules created
        assertTrue(vesting.hasRole(vesting.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vesting.hasRole(vesting.ADMIN_ROLE(), admin));
        assertTrue(vesting.hasRole(vesting.GRANT_MANAGER_ROLE(), admin));
    }

    function test_Deployment_RevertZeroTreasury() public {
        vm.expectRevert(VestingContract.ZeroAddress.selector);
        new VestingContract(address(0), admin);
    }

    function test_Deployment_RevertZeroAdmin() public {
        vm.expectRevert(VestingContract.ZeroAddress.selector);
        new VestingContract(treasury, address(0));
    }

    function test_DefaultSchedulesCreated() public view {
        // Schedule 1: 1 Year Linear
        (uint256 cliff1, uint256 duration1, bool revocable1, string memory name1) =
            vesting.getSchedule(SCHEDULE_1_YEAR_LINEAR);
        assertEq(cliff1, 0);
        assertEq(duration1, 365 days);
        assertTrue(revocable1);
        assertEq(name1, "1 Year Linear");

        // Schedule 2: 2 Year with 6 Month Cliff
        (uint256 cliff2, uint256 duration2, bool revocable2, string memory name2) =
            vesting.getSchedule(SCHEDULE_2_YEAR_6M_CLIFF);
        assertEq(cliff2, 180 days);
        assertEq(duration2, 730 days);
        assertTrue(revocable2);
        assertEq(name2, "2 Year with 6 Month Cliff");

        // Schedule 3: 4 Year with 1 Year Cliff
        (uint256 cliff3, uint256 duration3, bool revocable3, string memory name3) =
            vesting.getSchedule(SCHEDULE_4_YEAR_1Y_CLIFF);
        assertEq(cliff3, 365 days);
        assertEq(duration3, 1460 days);
        assertTrue(revocable3);
        assertEq(name3, "4 Year with 1 Year Cliff");

        // Schedule 4: 6 Month Non-Revocable
        (uint256 cliff4, uint256 duration4, bool revocable4, string memory name4) =
            vesting.getSchedule(SCHEDULE_6_MONTH_NON_REVOCABLE);
        assertEq(cliff4, 0);
        assertEq(duration4, 180 days);
        assertFalse(revocable4);
        assertEq(name4, "6 Month Non-Revocable");
    }

    // ============ Schedule Creation Tests ============

    function test_CreateSchedule() public {
        uint256 cliffDuration = 90 days;
        uint256 vestingDuration = 365 days;

        vm.prank(admin);
        uint256 scheduleId = vesting.createSchedule(
            cliffDuration,
            vestingDuration,
            true,
            "Custom Schedule"
        );

        assertEq(scheduleId, 5);

        (uint256 cliff, uint256 duration, bool revocable, string memory name) =
            vesting.getSchedule(scheduleId);

        assertEq(cliff, cliffDuration);
        assertEq(duration, vestingDuration);
        assertTrue(revocable);
        assertEq(name, "Custom Schedule");
    }

    function test_CreateSchedule_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ScheduleCreated(5, "Test Schedule", 90 days, 365 days, true);
        vesting.createSchedule(90 days, 365 days, true, "Test Schedule");
    }

    function test_CreateSchedule_RevertDurationTooShort() public {
        vm.prank(admin);
        vm.expectRevert(VestingContract.InvalidDuration.selector);
        vesting.createSchedule(0, 20 days, true, "Too Short"); // Less than MIN_VESTING_DURATION
    }

    function test_CreateSchedule_RevertDurationTooLong() public {
        vm.prank(admin);
        vm.expectRevert(VestingContract.InvalidDuration.selector);
        vesting.createSchedule(0, 4000 days, true, "Too Long"); // More than MAX_VESTING_DURATION
    }

    function test_CreateSchedule_RevertCliffTooLong() public {
        vm.prank(admin);
        vm.expectRevert(VestingContract.InvalidDuration.selector);
        vesting.createSchedule(800 days, 1000 days, true, "Cliff Too Long"); // Cliff > MAX_CLIFF_DURATION
    }

    function test_CreateSchedule_RevertCliffExceedsDuration() public {
        vm.prank(admin);
        vm.expectRevert(VestingContract.InvalidDuration.selector);
        vesting.createSchedule(400 days, 365 days, true, "Cliff > Duration");
    }

    function test_CreateSchedule_RevertUnauthorized() public {
        vm.prank(beneficiary1);
        vm.expectRevert();
        vesting.createSchedule(0, 365 days, true, "Unauthorized");
    }

    // ============ Grant Creation Tests ============

    function test_CreateGrant() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 cliffDuration = 180 days;
        uint256 vestingDuration = 730 days;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            cliffDuration,
            vestingDuration,
            true
        );

        assertEq(grantId, 1);

        (
            address beneficiary,
            address tokenAddr,
            uint256 totalAmount,
            uint256 claimedAmount,
            uint256 storedStartTime,
            uint256 cliffEnd,
            uint256 vestingEnd,
            VestingContract.GrantStatus status
        ) = vesting.getGrant(grantId);

        assertEq(beneficiary, beneficiary1);
        assertEq(tokenAddr, address(token));
        assertEq(totalAmount, GRANT_AMOUNT);
        assertEq(claimedAmount, 0);
        assertEq(storedStartTime, startTime);
        assertEq(cliffEnd, startTime + cliffDuration);
        assertEq(vestingEnd, startTime + vestingDuration);
        assertEq(uint8(status), uint8(VestingContract.GrantStatus.Active));
    }

    function test_CreateGrant_EmitsEvent() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        vm.expectEmit(true, true, true, true);
        emit GrantCreated(
            1,
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            180 days,
            730 days,
            true
        );
        vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            180 days,
            730 days,
            true
        );
    }

    function test_CreateGrant_TransfersTokens() public {
        uint256 startTime = block.timestamp + 1 hours;

        uint256 vestingBalanceBefore = token.balanceOf(address(vesting));

        vm.prank(grantManager);
        vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            180 days,
            730 days,
            true
        );

        uint256 vestingBalanceAfter = token.balanceOf(address(vesting));

        assertEq(vestingBalanceAfter - vestingBalanceBefore, GRANT_AMOUNT);
    }

    function test_CreateGrant_RevertZeroBeneficiary() public {
        vm.prank(grantManager);
        vm.expectRevert(VestingContract.ZeroAddress.selector);
        vesting.createGrant(
            address(0),
            address(token),
            GRANT_AMOUNT,
            block.timestamp + 1 hours,
            180 days,
            730 days,
            true
        );
    }

    function test_CreateGrant_RevertZeroToken() public {
        vm.prank(grantManager);
        vm.expectRevert(VestingContract.ZeroAddress.selector);
        vesting.createGrant(
            beneficiary1,
            address(0),
            GRANT_AMOUNT,
            block.timestamp + 1 hours,
            180 days,
            730 days,
            true
        );
    }

    function test_CreateGrant_RevertZeroAmount() public {
        vm.prank(grantManager);
        vm.expectRevert(VestingContract.ZeroAmount.selector);
        vesting.createGrant(
            beneficiary1,
            address(token),
            0,
            block.timestamp + 1 hours,
            180 days,
            730 days,
            true
        );
    }

    function test_CreateGrant_RevertPastStartTime() public {
        vm.prank(grantManager);
        vm.expectRevert(VestingContract.InvalidStartTime.selector);
        vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            block.timestamp - 1,
            180 days,
            730 days,
            true
        );
    }

    function test_CreateGrant_RevertUnauthorized() public {
        vm.prank(beneficiary1);
        vm.expectRevert();
        vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            block.timestamp + 1 hours,
            180 days,
            730 days,
            true
        );
    }

    // ============ Grant From Schedule Tests ============

    function test_CreateGrantFromSchedule() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_2_YEAR_6M_CLIFF
        );

        (
            address beneficiary,
            address tokenAddr,
            uint256 totalAmount,
            ,
            uint256 storedStartTime,
            uint256 cliffEnd,
            uint256 vestingEnd,
        ) = vesting.getGrant(grantId);

        assertEq(beneficiary, beneficiary1);
        assertEq(tokenAddr, address(token));
        assertEq(totalAmount, GRANT_AMOUNT);
        assertEq(storedStartTime, startTime);
        assertEq(cliffEnd, startTime + 180 days);
        assertEq(vestingEnd, startTime + 730 days);
    }

    function test_CreateGrantFromSchedule_RevertScheduleNotFound() public {
        vm.prank(grantManager);
        vm.expectRevert(VestingContract.ScheduleNotFound.selector);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            block.timestamp + 1 hours,
            999 // Non-existent schedule
        );
    }

    // ============ Batch Grant Creation Tests ============

    function test_CreateGrantsBatch() public {
        uint256 startTime = block.timestamp + 1 hours;

        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;
        beneficiaries[2] = beneficiary3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100_000 * 1e18;
        amounts[1] = 200_000 * 1e18;
        amounts[2] = 300_000 * 1e18;

        vm.prank(grantManager);
        uint256[] memory grantIds = vesting.createGrantsBatch(
            beneficiaries,
            address(token),
            amounts,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        assertEq(grantIds.length, 3);
        assertEq(grantIds[0], 1);
        assertEq(grantIds[1], 2);
        assertEq(grantIds[2], 3);

        // Verify each grant
        for (uint256 i = 0; i < 3; i++) {
            (address beneficiary,, uint256 totalAmount,,,,, ) = vesting.getGrant(grantIds[i]);
            assertEq(beneficiary, beneficiaries[i]);
            assertEq(totalAmount, amounts[i]);
        }
    }

    function test_CreateGrantsBatch_RevertMismatchedArrays() public {
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100_000 * 1e18;
        amounts[1] = 200_000 * 1e18;
        amounts[2] = 300_000 * 1e18;

        vm.prank(grantManager);
        vm.expectRevert(VestingContract.ZeroAmount.selector);
        vesting.createGrantsBatch(
            beneficiaries,
            address(token),
            amounts,
            block.timestamp + 1 hours,
            SCHEDULE_1_YEAR_LINEAR
        );
    }

    // ============ Claiming Tests - Linear Vesting ============

    function test_Claim_LinearVesting() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR // No cliff, 1 year linear
        );

        // Warp to halfway through vesting
        vm.warp(startTime + 182.5 days);

        uint256 balanceBefore = token.balanceOf(beneficiary1);

        vm.prank(beneficiary1);
        uint256 claimed = vesting.claim(grantId);

        uint256 balanceAfter = token.balanceOf(beneficiary1);

        // Should claim approximately half
        assertApproxEqRel(claimed, GRANT_AMOUNT / 2, 0.01e18);
        assertEq(balanceAfter - balanceBefore, claimed);
    }

    function test_Claim_AfterFullVesting() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        // Warp past end of vesting
        vm.warp(startTime + 400 days);

        vm.prank(beneficiary1);
        uint256 claimed = vesting.claim(grantId);

        assertEq(claimed, GRANT_AMOUNT);

        // Verify grant is completed
        (,,,,,,,VestingContract.GrantStatus status) = vesting.getGrant(grantId);
        assertEq(uint8(status), uint8(VestingContract.GrantStatus.Completed));
    }

    function test_Claim_MultipleClaims() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        uint256 totalClaimed = 0;

        // Claim at 25%
        vm.warp(startTime + 91.25 days);
        vm.prank(beneficiary1);
        totalClaimed += vesting.claim(grantId);

        // Claim at 50%
        vm.warp(startTime + 182.5 days);
        vm.prank(beneficiary1);
        totalClaimed += vesting.claim(grantId);

        // Claim at 100%
        vm.warp(startTime + 365 days);
        vm.prank(beneficiary1);
        totalClaimed += vesting.claim(grantId);

        assertApproxEqRel(totalClaimed, GRANT_AMOUNT, 0.001e18);
    }

    function test_Claim_EmitsEvent() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.warp(startTime + 365 days);

        vm.prank(beneficiary1);
        vm.expectEmit(true, true, false, true);
        emit TokensClaimed(grantId, beneficiary1, GRANT_AMOUNT, GRANT_AMOUNT);
        vesting.claim(grantId);
    }

    // ============ Claiming Tests - Cliff Vesting ============

    function test_Claim_WithCliff() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_2_YEAR_6M_CLIFF // 6 month cliff, 2 year total
        );

        // Warp to just after cliff
        vm.warp(startTime + 181 days);

        uint256 claimable = vesting.getClaimableAmount(grantId);
        assertTrue(claimable > 0);

        vm.prank(beneficiary1);
        uint256 claimed = vesting.claim(grantId);

        // Should claim approximately 6 months worth (181/730 = ~24.8%)
        assertApproxEqRel(claimed, (GRANT_AMOUNT * 181) / 730, 0.01e18);
    }

    function test_Claim_RevertBeforeCliff() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_2_YEAR_6M_CLIFF
        );

        // Warp to before cliff
        vm.warp(startTime + 90 days);

        vm.prank(beneficiary1);
        vm.expectRevert(VestingContract.CliffNotReached.selector);
        vesting.claim(grantId);
    }

    function test_GetClaimableAmount_BeforeCliff() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_2_YEAR_6M_CLIFF
        );

        vm.warp(startTime + 90 days);

        uint256 claimable = vesting.getClaimableAmount(grantId);
        assertEq(claimable, 0);
    }

    // ============ Claim All Tests ============

    function test_ClaimAll() public {
        uint256 startTime = block.timestamp + 1 hours;

        // Create multiple grants for beneficiary1
        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            100_000 * 1e18,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            200_000 * 1e18,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        // Warp to end of vesting
        vm.warp(startTime + 365 days);

        vm.prank(beneficiary1);
        uint256 totalClaimed = vesting.claimAll();

        assertEq(totalClaimed, 300_000 * 1e18);
    }

    function test_ClaimAll_SkipsInactiveGrants() public {
        uint256 startTime = block.timestamp + 1 hours;

        // Create grant
        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        // Revoke it
        vm.warp(startTime + 180 days);
        vm.prank(admin);
        vesting.revokeGrant(grantId);

        // Create another grant (must use future start time)
        uint256 newStartTime = block.timestamp + 1 hours;
        vm.prank(grantManager);
        vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            newStartTime,
            0,
            365 days,
            true
        );

        vm.warp(newStartTime + 365 days);

        vm.prank(beneficiary1);
        uint256 totalClaimed = vesting.claimAll();

        // Should only claim from the second grant
        assertEq(totalClaimed, GRANT_AMOUNT);
    }

    function test_ClaimAll_RevertNothingToClaim() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_2_YEAR_6M_CLIFF
        );

        // Before cliff
        vm.warp(startTime + 90 days);

        vm.prank(beneficiary1);
        vm.expectRevert(VestingContract.NothingToClaim.selector);
        vesting.claimAll();
    }

    // ============ Claim Error Tests ============

    function test_Claim_RevertGrantNotFound() public {
        vm.prank(beneficiary1);
        vm.expectRevert(VestingContract.GrantNotFound.selector);
        vesting.claim(999);
    }

    function test_Claim_RevertNotBeneficiary() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.warp(startTime + 365 days);

        vm.prank(beneficiary2); // Wrong beneficiary
        vm.expectRevert(VestingContract.NotBeneficiary.selector);
        vesting.claim(grantId);
    }

    function test_Claim_RevertNothingToClaim() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        // Claim everything
        vm.warp(startTime + 365 days);
        vm.prank(beneficiary1);
        vesting.claim(grantId);

        // Try to claim again - grant becomes inactive after fully claimed
        vm.prank(beneficiary1);
        vm.expectRevert(VestingContract.GrantNotActive.selector);
        vesting.claim(grantId);
    }

    function test_Claim_RevertWhenPaused() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.warp(startTime + 365 days);

        vm.prank(admin);
        vesting.pause();

        vm.prank(beneficiary1);
        vm.expectRevert();
        vesting.claim(grantId);
    }

    // ============ Revocation Tests ============

    function test_RevokeGrant() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true // Revocable
        );

        // Warp to halfway
        vm.warp(startTime + 182.5 days);

        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary1);
        uint256 treasuryBalanceBefore = token.balanceOf(treasury);

        vm.prank(admin);
        vesting.revokeGrant(grantId);

        uint256 beneficiaryBalanceAfter = token.balanceOf(beneficiary1);
        uint256 treasuryBalanceAfter = token.balanceOf(treasury);

        // Beneficiary should receive vested amount (~50%)
        assertApproxEqRel(
            beneficiaryBalanceAfter - beneficiaryBalanceBefore,
            GRANT_AMOUNT / 2,
            0.01e18
        );

        // Treasury should receive unvested amount (~50%)
        assertApproxEqRel(
            treasuryBalanceAfter - treasuryBalanceBefore,
            GRANT_AMOUNT / 2,
            0.01e18
        );

        // Grant should be revoked
        (,,,,,,,VestingContract.GrantStatus status) = vesting.getGrant(grantId);
        assertEq(uint8(status), uint8(VestingContract.GrantStatus.Revoked));
    }

    function test_RevokeGrant_EmitsEvent() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        vm.warp(startTime + 182.5 days);

        uint256 expectedVested = (GRANT_AMOUNT * 182.5 days) / 365 days;
        uint256 expectedUnvested = GRANT_AMOUNT - expectedVested;

        vm.prank(admin);
        vm.expectEmit(true, true, false, false); // Don't check exact amounts due to rounding
        emit GrantRevoked(grantId, beneficiary1, expectedVested, expectedUnvested, admin);
        vesting.revokeGrant(grantId);
    }

    function test_RevokeGrant_BeforeStart() public {
        uint256 startTime = block.timestamp + 1 days;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        // Revoke before start - all should go to treasury
        vm.prank(admin);
        vesting.revokeGrant(grantId);

        assertEq(token.balanceOf(treasury), GRANT_AMOUNT);
        assertEq(token.balanceOf(beneficiary1), 0);
    }

    function test_RevokeGrant_AfterClaim() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        // Claim at 25%
        vm.warp(startTime + 91.25 days);
        vm.prank(beneficiary1);
        uint256 claimed = vesting.claim(grantId);

        // Revoke at 50%
        vm.warp(startTime + 182.5 days);
        vm.prank(admin);
        vesting.revokeGrant(grantId);

        // Beneficiary should have claimed + additional vested
        assertApproxEqRel(token.balanceOf(beneficiary1), GRANT_AMOUNT / 2, 0.01e18);

        // Treasury should have unvested
        assertApproxEqRel(token.balanceOf(treasury), GRANT_AMOUNT / 2, 0.01e18);
    }

    function test_RevokeGrant_RevertNonRevocable() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_6_MONTH_NON_REVOCABLE // Non-revocable
        );

        vm.warp(startTime + 90 days);

        vm.prank(admin);
        vm.expectRevert(VestingContract.GrantNotRevocable.selector);
        vesting.revokeGrant(grantId);
    }

    function test_RevokeGrant_RevertNotActive() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        vm.warp(startTime + 180 days);

        // Revoke first time
        vm.prank(admin);
        vesting.revokeGrant(grantId);

        // Try to revoke again
        vm.prank(admin);
        vm.expectRevert(VestingContract.GrantNotActive.selector);
        vesting.revokeGrant(grantId);
    }

    function test_RevokeGrant_RevertUnauthorized() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        vm.prank(beneficiary1); // Not admin
        vm.expectRevert();
        vesting.revokeGrant(grantId);
    }

    // ============ Beneficiary Management Tests ============

    function test_ChangeBeneficiary() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        vm.prank(beneficiary1);
        vm.expectEmit(true, true, true, false);
        emit BeneficiaryChanged(grantId, beneficiary1, beneficiary2);
        vesting.changeBeneficiary(grantId, beneficiary2);

        (address newBeneficiary,,,,,,,) = vesting.getGrant(grantId);
        assertEq(newBeneficiary, beneficiary2);

        // New beneficiary can claim
        vm.warp(startTime + 365 days);
        vm.prank(beneficiary2);
        uint256 claimed = vesting.claim(grantId);
        assertEq(claimed, GRANT_AMOUNT);
    }

    function test_ChangeBeneficiary_RevertNotBeneficiary() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        vm.prank(beneficiary2); // Not the beneficiary
        vm.expectRevert(VestingContract.NotBeneficiary.selector);
        vesting.changeBeneficiary(grantId, beneficiary3);
    }

    function test_ChangeBeneficiary_RevertZeroAddress() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            365 days,
            true
        );

        vm.prank(beneficiary1);
        vm.expectRevert(VestingContract.ZeroAddress.selector);
        vesting.changeBeneficiary(grantId, address(0));
    }

    // ============ Admin Functions Tests ============

    function test_SetTreasury() public {
        address newTreasury = address(100);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit TreasuryUpdated(treasury, newTreasury);
        vesting.setTreasury(newTreasury);

        assertEq(vesting.treasury(), newTreasury);
    }

    function test_SetTreasury_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(VestingContract.ZeroAddress.selector);
        vesting.setTreasury(address(0));
    }

    function test_SetTreasury_RevertUnauthorized() public {
        vm.prank(beneficiary1);
        vm.expectRevert();
        vesting.setTreasury(address(100));
    }

    function test_Pause() public {
        vm.prank(admin);
        vesting.pause();

        assertTrue(vesting.paused());
    }

    function test_Unpause() public {
        vm.prank(admin);
        vesting.pause();

        vm.prank(admin);
        vesting.unpause();

        assertFalse(vesting.paused());
    }

    // ============ View Functions Tests ============

    function test_GetVestedAmount() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        // Before start
        assertEq(vesting.getVestedAmount(grantId), 0);

        // At 50%
        vm.warp(startTime + 182.5 days);
        assertApproxEqRel(vesting.getVestedAmount(grantId), GRANT_AMOUNT / 2, 0.01e18);

        // At 100%
        vm.warp(startTime + 365 days);
        assertEq(vesting.getVestedAmount(grantId), GRANT_AMOUNT);

        // After 100%
        vm.warp(startTime + 500 days);
        assertEq(vesting.getVestedAmount(grantId), GRANT_AMOUNT);
    }

    function test_GetUnvestedAmount() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        // Before start
        assertEq(vesting.getUnvestedAmount(grantId), GRANT_AMOUNT);

        // At 50%
        vm.warp(startTime + 182.5 days);
        assertApproxEqRel(vesting.getUnvestedAmount(grantId), GRANT_AMOUNT / 2, 0.01e18);

        // At 100%
        vm.warp(startTime + 365 days);
        assertEq(vesting.getUnvestedAmount(grantId), 0);
    }

    function test_GetBeneficiaryGrants() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            100_000 * 1e18,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            200_000 * 1e18,
            startTime,
            SCHEDULE_2_YEAR_6M_CLIFF
        );

        uint256[] memory grantIds = vesting.getBeneficiaryGrants(beneficiary1);

        assertEq(grantIds.length, 2);
        assertEq(grantIds[0], 1);
        assertEq(grantIds[1], 2);
    }

    function test_GetTotalClaimable() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            100_000 * 1e18,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.prank(grantManager);
        vesting.createGrantFromSchedule(
            beneficiary1,
            address(token),
            200_000 * 1e18,
            startTime,
            SCHEDULE_1_YEAR_LINEAR
        );

        vm.warp(startTime + 365 days);

        uint256 totalClaimable = vesting.getTotalClaimable(beneficiary1);
        assertEq(totalClaimable, 300_000 * 1e18);
    }

    function test_GetActiveGrantCount() public {
        uint256 startTime = block.timestamp + 1 hours;

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(grantManager);
            vesting.createGrantFromSchedule(
                beneficiary1,
                address(token),
                10_000 * 1e18,
                startTime,
                SCHEDULE_1_YEAR_LINEAR
            );
        }

        assertEq(vesting.getActiveGrantCount(), 5);
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateGrant(uint256 amount, uint256 vestingDuration) public {
        amount = bound(amount, 1e18, GRANT_AMOUNT);
        vestingDuration = bound(vestingDuration, MIN_VESTING_DURATION, MAX_VESTING_DURATION);

        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            amount,
            startTime,
            0,
            vestingDuration,
            true
        );

        (,, uint256 totalAmount,,,,, ) = vesting.getGrant(grantId);
        assertEq(totalAmount, amount);
    }

    function testFuzz_LinearVesting(uint256 timeElapsed) public {
        uint256 vestingDuration = 365 days;
        timeElapsed = bound(timeElapsed, 0, vestingDuration * 2);

        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            0,
            vestingDuration,
            true
        );

        vm.warp(startTime + timeElapsed);

        uint256 vested = vesting.getVestedAmount(grantId);

        if (timeElapsed >= vestingDuration) {
            assertEq(vested, GRANT_AMOUNT);
        } else {
            uint256 expectedVested = (GRANT_AMOUNT * timeElapsed) / vestingDuration;
            assertApproxEqAbs(vested, expectedVested, 1);
        }
    }

    function testFuzz_CliffVesting(uint256 cliffDuration, uint256 timeElapsed) public {
        uint256 vestingDuration = 730 days;
        cliffDuration = bound(cliffDuration, 0, MAX_CLIFF_DURATION);
        // Ensure cliff is less than vesting duration
        if (cliffDuration >= vestingDuration) {
            cliffDuration = vestingDuration - 1 days;
        }
        timeElapsed = bound(timeElapsed, 0, vestingDuration * 2);

        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(grantManager);
        uint256 grantId = vesting.createGrant(
            beneficiary1,
            address(token),
            GRANT_AMOUNT,
            startTime,
            cliffDuration,
            vestingDuration,
            true
        );

        vm.warp(startTime + timeElapsed);

        uint256 claimable = vesting.getClaimableAmount(grantId);

        if (timeElapsed < cliffDuration) {
            assertEq(claimable, 0, "Nothing claimable before cliff");
        } else if (timeElapsed >= vestingDuration) {
            assertEq(claimable, GRANT_AMOUNT, "Full amount claimable after vesting");
        } else if (timeElapsed == 0) {
            // At exactly startTime (t=0), no time has elapsed for linear vesting
            assertEq(claimable, 0, "Nothing claimable at exactly start time");
        } else {
            assertTrue(claimable > 0, "Some amount claimable after cliff");
            assertTrue(claimable <= GRANT_AMOUNT, "Claimable should not exceed total");
        }
    }
}
