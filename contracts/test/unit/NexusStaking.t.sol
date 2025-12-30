// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { NexusStaking } from "../../src/defi/NexusStaking.sol";
import { NexusToken } from "../../src/core/NexusToken.sol";

/**
 * @title NexusStakingTest
 * @notice Unit tests for NexusStaking contract
 * @dev Tests cover:
 *      - Staking and unbonding
 *      - Unbonding periods (SEC-002)
 *      - Slashing mechanics (SEC-008)
 *      - Delegation
 *      - Rate limiting (SEC-011)
 */
contract NexusStakingTest is Test {
    NexusStaking public staking;
    NexusToken public token;

    address public admin = address(1);
    address public slasher = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public treasury = address(5);

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant STAKE_AMOUNT = 10_000 * 1e18;
    uint256 public constant MIN_STAKE_DURATION = 24 hours;
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint256 public constant MAX_DAILY_WITHDRAWAL_BPS = 1000; // 10%

    function setUp() public {
        vm.startPrank(admin);

        // Deploy token
        token = new NexusToken(admin);

        // Mint initial supply to admin (NexusToken doesn't mint on construction)
        token.mint(admin, INITIAL_SUPPLY);

        // Deploy staking (constructor takes 3 args: token, treasury, admin)
        staking = new NexusStaking(address(token), treasury, admin);

        // Grant slasher role
        staking.grantRole(staking.SLASHER_ROLE(), slasher);

        // Transfer tokens to users
        token.transfer(user1, STAKE_AMOUNT * 10);
        token.transfer(user2, STAKE_AMOUNT * 10);

        vm.stopPrank();

        // Approve staking contract
        vm.prank(user1);
        token.approve(address(staking), type(uint256).max);

        vm.prank(user2);
        token.approve(address(staking), type(uint256).max);
    }

    // ============ Staking Tests ============

    function test_Stake() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        assertEq(staking.totalStaked(), STAKE_AMOUNT);
        (uint256 amount,,,,,,) = staking.stakes(user1);
        assertEq(amount, STAKE_AMOUNT);
    }

    function test_Stake_Multiple() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        (uint256 amount,,,,,,) = staking.stakes(user1);
        assertEq(amount, STAKE_AMOUNT * 2);
    }

    function test_Stake_RevertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        staking.stake(0);
    }

    function testFuzz_Stake(uint256 amount) public {
        amount = bound(amount, 1, STAKE_AMOUNT * 10);

        vm.prank(user1);
        staking.stake(amount);

        (uint256 stakedAmount,,,,,,) = staking.stakes(user1);
        assertEq(stakedAmount, amount);
    }

    // ============ Unbonding Tests ============

    function test_InitiateUnbonding_AfterMinDuration() public {
        // Stake a large amount so daily limit allows for withdrawal
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT * 10); // 100,000 tokens

        // Fast forward past minimum stake duration
        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        // Unbond small amount (within 10% daily limit = 10,000)
        vm.prank(user1);
        staking.initiateUnbonding(STAKE_AMOUNT); // 10,000 tokens = exactly 10% limit

        (uint256 amount,,,,,,) = staking.stakes(user1);
        assertEq(amount, STAKE_AMOUNT * 9); // 90,000 remaining
    }

    function test_InitiateUnbonding_RevertBeforeMinDuration() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        // Try to unbond before minimum duration (should revert)
        vm.prank(user1);
        vm.expectRevert();
        staking.initiateUnbonding(STAKE_AMOUNT);
    }

    function test_InitiateUnbonding_RevertInsufficientBalance() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        vm.prank(user1);
        vm.expectRevert();
        staking.initiateUnbonding(STAKE_AMOUNT * 2);
    }

    // ============ Complete Unbonding Tests - SEC-002 ============

    function test_CompleteUnbonding_AfterPeriod() public {
        // Stake large amount so daily limit allows for withdrawal
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT * 10); // 100,000 tokens

        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        // Unbond within daily limit
        vm.prank(user1);
        staking.initiateUnbonding(STAKE_AMOUNT);

        // Cannot complete before unbonding period
        vm.prank(user1);
        vm.expectRevert();
        staking.completeUnbonding(0);

        // Fast forward past unbonding period
        vm.warp(block.timestamp + UNBONDING_PERIOD + 1);

        // Now can complete unbonding
        uint256 balanceBefore = token.balanceOf(user1);
        vm.prank(user1);
        staking.completeUnbonding(0);
        uint256 balanceAfter = token.balanceOf(user1);

        assertGt(balanceAfter, balanceBefore);
    }

    // ============ Delegation Tests ============

    function test_Delegate() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user1);
        staking.delegate(user2);

        (,,, address delegatee,,,) = staking.stakes(user1);
        assertEq(delegatee, user2);
    }

    function test_Delegate_UpdateVotingPower() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user1);
        staking.delegate(user2);

        assertEq(staking.getVotingPower(user2), STAKE_AMOUNT);
    }

    function test_Delegate_Redelegate() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user1);
        staking.delegate(user2);

        vm.prank(user1);
        staking.delegate(admin);

        assertEq(staking.getVotingPower(user2), 0);
        assertEq(staking.getVotingPower(admin), STAKE_AMOUNT);
    }

    // ============ Slashing Tests - SEC-008 ============

    function test_Slash() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        uint256 slashBps = 1000; // 10%

        vm.prank(slasher);
        staking.slash(user1, slashBps, "Protocol violation");

        (uint256 amount,,,,,,) = staking.stakes(user1);
        uint256 expectedAmount = STAKE_AMOUNT - (STAKE_AMOUNT * slashBps / 10_000);
        assertEq(amount, expectedAmount);
    }

    function test_Slash_OnlySlasherRole() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user2);
        vm.expectRevert();
        staking.slash(user1, 1000, "Unauthorized attempt");
    }

    function test_Slash_MaxSlashLimit() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        // Try to slash more than max (50%)
        vm.prank(slasher);
        vm.expectRevert();
        staking.slash(user1, 6000, "Excessive slash"); // 60%
    }

    function test_Slash_CooldownPreventsStaking() public {
        // Test that slashing cooldown prevents the staker from staking again
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(slasher);
        staking.slash(user1, 1000, "First slash");

        // Staker cannot stake during cooldown
        vm.prank(user1);
        vm.expectRevert();
        staking.stake(STAKE_AMOUNT);

        // Fast forward past cooldown (30 days)
        vm.warp(block.timestamp + 30 days + 1);

        // Now staker can stake again
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);
    }

    // ============ Rate Limiting Tests - SEC-011 ============

    function test_RateLimit_MaxUnbondingOperations() public {
        // Stake very large amount so daily limit is high
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT * 10); // 100,000 tokens - daily limit is 10,000

        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        // Should be able to unbond up to MAX_UNSTAKE_OPS_PER_WINDOW times (3)
        // Each unbond must be within daily limit, so use smaller amounts
        uint256 unbondAmount = STAKE_AMOUNT / 4; // 2,500 tokens per unbond
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(user1);
            staking.initiateUnbonding(unbondAmount);
        }

        // Fourth unbonding in same window should fail (rate limit)
        vm.prank(user1);
        vm.expectRevert();
        staking.initiateUnbonding(unbondAmount);
    }

    function test_RateLimit_WindowReset() public {
        // Stake very large amount
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT * 10); // 100,000 tokens

        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        // Use up rate limit (3 operations)
        uint256 unbondAmount = STAKE_AMOUNT / 4; // 2,500 tokens
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(user1);
            staking.initiateUnbonding(unbondAmount);
        }

        // Fast forward past rate limit window (1 hour) AND daily limit reset (1 day)
        vm.warp(block.timestamp + 1 days + 1);

        // Should be able to unbond again (rate limit reset + daily limit reset)
        vm.prank(user1);
        staking.initiateUnbonding(unbondAmount);
    }

    // ============ View Functions ============

    function test_GetStakeInfo() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        (
            uint256 amount,
            uint256 stakedAt,
            uint256 lastStakeTime,
            address delegatee,
            uint256 delegatedToMe,
            uint256 lastSlashedAt,
            uint256 totalSlashed
        ) = staking.stakes(user1);

        assertEq(amount, STAKE_AMOUNT);
        assertEq(stakedAt, block.timestamp);
        assertEq(lastStakeTime, block.timestamp);
        assertEq(delegatee, address(0));
        assertEq(delegatedToMe, 0);
        assertEq(lastSlashedAt, 0);
        assertEq(totalSlashed, 0);
    }

    function test_GetTotalStaked() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user2);
        staking.stake(STAKE_AMOUNT * 2);

        assertEq(staking.totalStaked(), STAKE_AMOUNT * 3);
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        vm.prank(admin);
        staking.pause();

        vm.prank(user1);
        vm.expectRevert();
        staking.stake(STAKE_AMOUNT);
    }

    function test_Unpause() public {
        vm.prank(admin);
        staking.pause();

        vm.prank(admin);
        staking.unpause();

        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        (uint256 amount,,,,,,) = staking.stakes(user1);
        assertEq(amount, STAKE_AMOUNT);
    }

    // ============ Admin Configuration Tests ============

    function test_SetDailyWithdrawalLimit() public {
        uint256 newLimit = 2000; // 20%

        vm.prank(admin);
        staking.setDailyWithdrawalLimit(newLimit);

        assertEq(staking.dailyWithdrawalLimitBps(), newLimit);
    }

    function test_SetDailyWithdrawalLimit_RevertBelowMin() public {
        // Try to set below MIN_DAILY_WITHDRAWAL_BPS (1%)
        vm.prank(admin);
        vm.expectRevert();
        staking.setDailyWithdrawalLimit(50); // 0.5%
    }

    function test_SetDailyWithdrawalLimit_RevertAboveMax() public {
        // Try to set above MAX_CONFIGURABLE_DAILY_BPS (50%)
        vm.prank(admin);
        vm.expectRevert();
        staking.setDailyWithdrawalLimit(6000); // 60%
    }

    function test_SetDailyWithdrawalLimit_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        staking.setDailyWithdrawalLimit(2000);
    }

    // ============ Edge Cases ============

    function test_StakeAndUnbondSameBlock() public {
        vm.startPrank(user1);
        staking.stake(STAKE_AMOUNT);

        // Cannot unbond in same block (min stake duration not met)
        vm.expectRevert();
        staking.initiateUnbonding(STAKE_AMOUNT);
        vm.stopPrank();
    }

    function test_MultipleUsersStaking() public {
        vm.prank(user1);
        staking.stake(STAKE_AMOUNT);

        vm.prank(user2);
        staking.stake(STAKE_AMOUNT * 2);

        assertEq(staking.totalStaked(), STAKE_AMOUNT * 3);

        (uint256 amount1,,,,,,) = staking.stakes(user1);
        (uint256 amount2,,,,,,) = staking.stakes(user2);

        assertEq(amount1, STAKE_AMOUNT);
        assertEq(amount2, STAKE_AMOUNT * 2);
    }
}
