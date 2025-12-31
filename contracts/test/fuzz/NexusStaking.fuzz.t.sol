// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { NexusStaking } from "../../src/defi/NexusStaking.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

/**
 * @title NexusStakingFuzzTest
 * @notice Fuzz tests for NexusStaking contract
 * @dev Tests mathematical invariants, bounds, and edge cases
 */
contract NexusStakingFuzzTest is Test {
    NexusStaking public staking;
    ERC20Mock public token;

    address public admin = address(1);
    address public treasury = address(2);
    address public slasher = address(3);

    uint256 public constant INITIAL_BALANCE = 1_000_000_000e18;
    uint256 public constant MIN_STAKE_FOR_SLASHING = 1000e18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_SLASH_BPS = 5000;
    uint256 public constant EARLY_EXIT_PENALTY_BPS = 500;
    uint256 public constant MIN_STAKE_DURATION = 24 hours;
    uint256 public constant DEFAULT_UNBONDING_PERIOD = 7 days;
    uint256 public constant SLASHING_COOLDOWN = 30 days;

    function setUp() public {
        token = new ERC20Mock("Nexus Token", "NEXUS", 18);
        staking = new NexusStaking(address(token), treasury, admin);

        vm.startPrank(admin);
        staking.grantRole(staking.SLASHER_ROLE(), slasher);
        // Set daily withdrawal limit to 50% for easier testing
        staking.setDailyWithdrawalLimit(5000);
        vm.stopPrank();

        // Seed with initial stake to increase totalStaked for daily limit calculations
        address seeder = address(999);
        token.mint(seeder, 100_000_000e18);
        vm.prank(seeder);
        token.approve(address(staking), 100_000_000e18);
        vm.prank(seeder);
        staking.stake(100_000_000e18);
    }

    // ============ Staking Fuzz Tests ============

    /**
     * @notice Fuzz test: Staking should always increase total staked by exact amount
     */
    function testFuzz_Stake_IncreasesTotalStaked(address staker, uint256 amount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        amount = bound(amount, 1, INITIAL_BALANCE);

        token.mint(staker, amount);
        vm.startPrank(staker);
        token.approve(address(staking), amount);

        uint256 totalBefore = staking.totalStaked();

        staking.stake(amount);

        uint256 totalAfter = staking.totalStaked();
        assertEq(totalAfter - totalBefore, amount, "Total staked should increase by exact amount");
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Staker balance should match staked amount
     */
    function testFuzz_Stake_BalanceMatchesStake(address staker, uint256 amount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        amount = bound(amount, 1, INITIAL_BALANCE);

        token.mint(staker, amount);
        vm.startPrank(staker);
        token.approve(address(staking), amount);

        staking.stake(amount);

        (uint256 stakedAmount,,,,,) = staking.getStakeInfo(staker);
        assertEq(stakedAmount, amount, "Stake info should match staked amount");
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Multiple stakes should accumulate correctly
     */
    function testFuzz_MultipleStakes_Accumulate(address staker, uint256 stake1, uint256 stake2) public {
        vm.assume(staker != address(0) && staker != address(staking));
        stake1 = bound(stake1, 1, INITIAL_BALANCE / 2);
        stake2 = bound(stake2, 1, INITIAL_BALANCE / 2);

        token.mint(staker, stake1 + stake2);
        vm.startPrank(staker);
        token.approve(address(staking), stake1 + stake2);

        staking.stake(stake1);
        staking.stake(stake2);

        (uint256 stakedAmount,,,,,) = staking.getStakeInfo(staker);
        assertEq(stakedAmount, stake1 + stake2, "Stakes should accumulate");
        vm.stopPrank();
    }

    // ============ Unbonding Fuzz Tests ============

    /**
     * @notice Fuzz test: Unbonding should not exceed staked amount
     */
    function testFuzz_Unbonding_CannotExceedStake(address staker, uint256 stakeAmount, uint256 unbondAmount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        stakeAmount = bound(stakeAmount, MIN_STAKE_DURATION, INITIAL_BALANCE / 2);
        unbondAmount = bound(unbondAmount, stakeAmount + 1, INITIAL_BALANCE);

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Wait for minimum stake duration
        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        vm.expectRevert(NexusStaking.InsufficientStake.selector);
        staking.initiateUnbonding(unbondAmount);
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Unbonding decreases stake correctly
     */
    function testFuzz_Unbonding_DecreasesStake(address staker, uint256 stakeAmount, uint256 unbondPercent) public {
        vm.assume(staker != address(0) && staker != address(staking));
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_BALANCE / 10);
        unbondPercent = bound(unbondPercent, 1, 100);

        uint256 unbondAmount = (stakeAmount * unbondPercent) / 100;
        if (unbondAmount == 0) unbondAmount = 1;

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Wait for minimum stake duration
        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        staking.initiateUnbonding(unbondAmount);

        (uint256 remainingStake,,,,,) = staking.getStakeInfo(staker);
        assertEq(remainingStake, stakeAmount - unbondAmount, "Remaining stake should be correct");
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Complete unbonding returns correct amount
     */
    function testFuzz_CompleteUnbonding_ReturnsCorrectAmount(address staker, uint256 stakeAmount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_BALANCE / 10);

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Wait for minimum stake duration + unbonding period (to avoid early exit penalty)
        vm.warp(block.timestamp + DEFAULT_UNBONDING_PERIOD + 1);

        staking.initiateUnbonding(stakeAmount);

        // Wait for unbonding to complete
        vm.warp(block.timestamp + DEFAULT_UNBONDING_PERIOD + 1);

        uint256 balanceBefore = token.balanceOf(staker);
        staking.completeUnbonding(0);
        uint256 balanceAfter = token.balanceOf(staker);

        // No early exit penalty since we waited
        assertEq(balanceAfter - balanceBefore, stakeAmount, "Should receive full amount");
        vm.stopPrank();
    }

    // ============ Slashing Fuzz Tests ============

    /**
     * @notice Fuzz test: Slashing should not exceed maximum percentage
     */
    function testFuzz_Slash_RespectsBounds(address staker, uint256 slashBps) public {
        vm.assume(staker != address(0) && staker != address(staking) && staker != slasher);
        slashBps = bound(slashBps, 1, MAX_SLASH_BPS);

        uint256 stakeAmount = MIN_STAKE_FOR_SLASHING * 2;
        token.mint(staker, stakeAmount);
        vm.prank(staker);
        token.approve(address(staking), stakeAmount);
        vm.prank(staker);
        staking.stake(stakeAmount);

        uint256 expectedSlash = (stakeAmount * slashBps) / BPS_DENOMINATOR;

        vm.prank(slasher);
        staking.slash(staker, slashBps, "Test slash");

        (uint256 remainingStake,,,,,) = staking.getStakeInfo(staker);
        assertEq(remainingStake, stakeAmount - expectedSlash, "Slash amount should be correct");
    }

    /**
     * @notice Fuzz test: Cannot slash above maximum BPS
     */
    function testFuzz_Slash_CannotExceedMax(address staker, uint256 slashBps) public {
        vm.assume(staker != address(0) && staker != address(staking) && staker != slasher);
        slashBps = bound(slashBps, MAX_SLASH_BPS + 1, BPS_DENOMINATOR);

        uint256 stakeAmount = MIN_STAKE_FOR_SLASHING * 2;
        token.mint(staker, stakeAmount);
        vm.prank(staker);
        token.approve(address(staking), stakeAmount);
        vm.prank(staker);
        staking.stake(stakeAmount);

        vm.prank(slasher);
        vm.expectRevert(NexusStaking.SlashAmountExceedsMax.selector);
        staking.slash(staker, slashBps, "Test slash");
    }

    /**
     * @notice Fuzz test: Cannot slash below minimum threshold
     */
    function testFuzz_Slash_RequiresMinimumStake(address staker, uint256 stakeAmount) public {
        vm.assume(staker != address(0) && staker != address(staking) && staker != slasher);
        stakeAmount = bound(stakeAmount, 1, MIN_STAKE_FOR_SLASHING - 1);

        token.mint(staker, stakeAmount);
        vm.prank(staker);
        token.approve(address(staking), stakeAmount);
        vm.prank(staker);
        staking.stake(stakeAmount);

        vm.prank(slasher);
        vm.expectRevert(NexusStaking.StakeBelowSlashingThreshold.selector);
        staking.slash(staker, 1000, "Test slash");
    }

    // ============ Delegation Fuzz Tests ============

    /**
     * @notice Fuzz test: Delegation updates voting power correctly
     */
    function testFuzz_Delegation_UpdatesVotingPower(address staker, address delegatee, uint256 stakeAmount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        vm.assume(delegatee != address(0) && delegatee != staker);
        // Exclude seeder address to avoid interference
        vm.assume(staker != address(999) && delegatee != address(999));
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_BALANCE / 10);

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Get delegatee voting power before delegation (should be 0 or from their own stake)
        (uint256 delegateeStakeBefore,,,,,) = staking.getStakeInfo(delegatee);

        staking.delegate(delegatee);
        vm.stopPrank();

        uint256 delegateeVotingPower = staking.getVotingPower(delegatee);
        // Delegatee voting power = their own stake (if any) + staker's delegated amount
        assertEq(delegateeVotingPower, delegateeStakeBefore + stakeAmount, "Delegatee should have voting power");

        uint256 stakerVotingPower = staking.getVotingPower(staker);
        assertEq(stakerVotingPower, 0, "Delegator should have no voting power");
    }

    /**
     * @notice Fuzz test: Cannot delegate to self
     */
    function testFuzz_Delegation_CannotDelegateToSelf(address staker, uint256 stakeAmount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_BALANCE / 10);

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        vm.expectRevert(NexusStaking.CannotDelegateToSelf.selector);
        staking.delegate(staker);
        vm.stopPrank();
    }

    // ============ Rate Limiting Fuzz Tests ============

    /**
     * @notice Fuzz test: Rate limit resets after window
     */
    function testFuzz_RateLimit_ResetsAfterWindow(address staker, uint256 stakeAmount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        vm.assume(staker != address(999)); // Exclude seeder
        // Use smaller amounts relative to total staked (100M from seeder)
        // Daily limit is 50% of total = 50M, so we can safely unbond smaller amounts
        stakeAmount = bound(stakeAmount, 1e18, 1_000_000e18);

        uint256 perUnbond = stakeAmount / 5; // Divide into 5 parts to have room for test

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Wait for minimum stake duration
        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        // Use up rate limit (3 operations)
        staking.initiateUnbonding(perUnbond);
        staking.initiateUnbonding(perUnbond);
        staking.initiateUnbonding(perUnbond);

        // Should fail on 4th (rate limit is 3 per hour)
        vm.expectRevert(NexusStaking.RateLimitExceeded_Error.selector);
        staking.initiateUnbonding(perUnbond);

        // Wait for rate limit window to reset (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        // Should work now (still have perUnbond left to unbond)
        staking.initiateUnbonding(1);
        vm.stopPrank();
    }

    // ============ Invariant-style Fuzz Tests ============

    /**
     * @notice Fuzz test: Total staked + total unbonding should equal contract balance
     */
    function testFuzz_Invariant_BalanceConsistency(address[5] memory stakers, uint256[5] memory amounts) public {
        uint256 totalDeposited = 0;

        for (uint256 i = 0; i < 5; i++) {
            address staker = stakers[i];
            if (staker == address(0) || staker == address(staking)) continue;

            uint256 amount = bound(amounts[i], 1e18, INITIAL_BALANCE / 20);
            totalDeposited += amount;

            token.mint(staker, amount);
            vm.prank(staker);
            token.approve(address(staking), amount);
            vm.prank(staker);
            staking.stake(amount);
        }

        uint256 contractBalance = token.balanceOf(address(staking));
        uint256 totalStaked = staking.totalStaked();
        uint256 totalUnbonding = staking.totalUnbonding();

        assertEq(totalStaked + totalUnbonding, contractBalance, "Balance invariant violated");
    }

    /**
     * @notice Fuzz test: Early exit penalty is calculated correctly
     */
    function testFuzz_EarlyExitPenalty_Calculation(address staker, uint256 stakeAmount) public {
        vm.assume(staker != address(0) && staker != address(staking));
        // Exclude special addresses: admin, treasury, slasher, seeder
        vm.assume(staker != admin && staker != treasury && staker != slasher && staker != address(999));
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_BALANCE / 10);

        token.mint(staker, stakeAmount);
        vm.startPrank(staker);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Wait only for minimum stake duration (but not unbonding period)
        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        staking.initiateUnbonding(stakeAmount);

        // Check that penalty flag is set
        (,,,, bool processed, bool penaltyApplied) = staking.getUnbondingRequest(staker, 0);
        assertFalse(processed, "Should not be processed yet");
        assertTrue(penaltyApplied, "Early exit penalty should apply");

        // Complete unbonding
        vm.warp(block.timestamp + DEFAULT_UNBONDING_PERIOD + 1);

        uint256 balanceBefore = token.balanceOf(staker);
        staking.completeUnbonding(0);
        uint256 balanceAfter = token.balanceOf(staker);

        uint256 expectedPenalty = (stakeAmount * EARLY_EXIT_PENALTY_BPS) / BPS_DENOMINATOR;
        uint256 expectedReceived = stakeAmount - expectedPenalty;

        assertEq(balanceAfter - balanceBefore, expectedReceived, "Should receive amount minus penalty");
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test: Slashing cooldown prevents restaking
     */
    function testFuzz_SlashingCooldown_PreventsRestake(address staker, uint256 waitTime) public {
        vm.assume(staker != address(0) && staker != address(staking) && staker != slasher);
        waitTime = bound(waitTime, 1, SLASHING_COOLDOWN - 1);

        uint256 stakeAmount = MIN_STAKE_FOR_SLASHING * 2;
        token.mint(staker, stakeAmount * 2);
        vm.prank(staker);
        token.approve(address(staking), stakeAmount * 2);
        vm.prank(staker);
        staking.stake(stakeAmount);

        // Slash the staker
        vm.prank(slasher);
        staking.slash(staker, 1000, "Test slash");

        // Try to stake again within cooldown
        vm.warp(block.timestamp + waitTime);

        vm.prank(staker);
        vm.expectRevert(NexusStaking.InSlashingCooldown.selector);
        staking.stake(stakeAmount);
    }

    /**
     * @notice Fuzz test: Slashing cooldown allows restaking after period
     */
    function testFuzz_SlashingCooldown_AllowsRestakeAfterPeriod(address staker) public {
        vm.assume(staker != address(0) && staker != address(staking) && staker != slasher);

        uint256 stakeAmount = MIN_STAKE_FOR_SLASHING * 2;
        token.mint(staker, stakeAmount * 2);
        vm.prank(staker);
        token.approve(address(staking), stakeAmount * 2);
        vm.prank(staker);
        staking.stake(stakeAmount);

        // Slash the staker
        vm.prank(slasher);
        staking.slash(staker, 1000, "Test slash");

        // Wait for cooldown to pass
        vm.warp(block.timestamp + SLASHING_COOLDOWN + 1);

        // Should be able to stake now
        vm.prank(staker);
        staking.stake(stakeAmount);

        (uint256 newStake,,,,,) = staking.getStakeInfo(staker);
        assertTrue(newStake > 0, "Should have stake after cooldown");
    }
}
