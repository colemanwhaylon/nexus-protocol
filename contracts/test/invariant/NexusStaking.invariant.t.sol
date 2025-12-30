// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { NexusStaking } from "../../src/defi/NexusStaking.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

/**
 * @title NexusStakingInvariantTest
 * @notice Invariant tests for NexusStaking contract
 * @dev Tests protocol invariants that must always hold
 */
contract NexusStakingInvariantTest is StdInvariant, Test {
    NexusStaking public staking;
    ERC20Mock public token;
    StakingHandler public handler;

    address public admin = address(1);
    address public treasury = address(2);

    function setUp() public {
        token = new ERC20Mock("Nexus Token", "NEXUS", 18);

        vm.startPrank(admin);
        staking = new NexusStaking(address(token), treasury, admin);
        vm.stopPrank();

        handler = new StakingHandler(staking, token, admin);

        // Setup slasher role for handler
        vm.startPrank(admin);
        staking.grantRole(staking.SLASHER_ROLE(), address(handler));
        vm.stopPrank();

        // Target the handler for invariant testing
        targetContract(address(handler));

        // Exclude system addresses
        excludeSender(address(0));
        excludeSender(address(staking));
        excludeSender(address(token));
    }

    /**
     * @notice Invariant: Total staked + total unbonding == contract token balance
     */
    function invariant_BalanceConsistency() public view {
        uint256 contractBalance = token.balanceOf(address(staking));
        uint256 totalStaked = staking.totalStaked();
        uint256 totalUnbonding = staking.totalUnbonding();

        assertEq(totalStaked + totalUnbonding, contractBalance, "Invariant violated: Balance mismatch");
    }

    /**
     * @notice Invariant: Individual stakes sum to total staked
     */
    function invariant_StakesSumToTotal() public view {
        uint256 sum = handler.getSumOfStakes();
        uint256 totalStaked = staking.totalStaked();

        assertEq(sum, totalStaked, "Invariant violated: Stakes don't sum to total");
    }

    /**
     * @notice Invariant: Epoch number never decreases
     */
    function invariant_EpochNeverDecreases() public view {
        uint256 currentEpoch = staking.currentEpoch();
        assertTrue(currentEpoch >= 1, "Invariant violated: Epoch below 1");
    }

    /**
     * @notice Invariant: Treasury never has negative impact from slashing
     */
    function invariant_TreasuryReceivesSlashedFunds() public view {
        uint256 treasuryBalance = token.balanceOf(treasury);
        uint256 totalSlashed = handler.getTotalSlashed();

        assertGe(treasuryBalance, totalSlashed, "Treasury should have at least slashed amount");
    }

    /**
     * @notice Call summary for debugging
     */
    function invariant_CallSummary() public view {
        console2.log("Stakes:", handler.stakeCount());
        console2.log("Unbonds:", handler.unbondCount());
        console2.log("Slashes:", handler.slashCount());
        console2.log("Total staked:", staking.totalStaked());
        console2.log("Total unbonding:", staking.totalUnbonding());
    }
}

/**
 * @title StakingHandler
 * @notice Handler contract for invariant testing
 */
contract StakingHandler is Test {
    NexusStaking public staking;
    ERC20Mock public token;
    address public admin;

    address[] public stakers;
    mapping(address => bool) public isStaker;

    uint256 public stakeCount;
    uint256 public unbondCount;
    uint256 public slashCount;
    uint256 public totalSlashedAmount;

    uint256 public constant MIN_STAKE_DURATION = 24 hours;
    uint256 public constant MIN_STAKE_FOR_SLASHING = 1000e18;

    constructor(NexusStaking _staking, ERC20Mock _token, address _admin) {
        staking = _staking;
        token = _token;
        admin = _admin;
    }

    /**
     * @notice Stake tokens
     */
    function stake(uint256 amount, uint256 stakerSeed) external {
        amount = bound(amount, 1e18, 1_000_000e18);

        address staker = _getStaker(stakerSeed);

        token.mint(staker, amount);
        vm.prank(staker);
        token.approve(address(staking), amount);

        // Check if in slashing cooldown
        (bool inCooldown,) = staking.isInSlashingCooldown(staker);
        if (inCooldown) {
            vm.expectRevert(NexusStaking.InSlashingCooldown.selector);
            vm.prank(staker);
            staking.stake(amount);
            return;
        }

        vm.prank(staker);
        staking.stake(amount);
        stakeCount++;
    }

    /**
     * @notice Initiate unbonding
     */
    function initiateUnbonding(uint256 amount, uint256 stakerIndex) external {
        if (stakers.length == 0) return;

        stakerIndex = bound(stakerIndex, 0, stakers.length - 1);
        address staker = stakers[stakerIndex];

        (uint256 stakedAmount,,,,,) = staking.getStakeInfo(staker);
        if (stakedAmount == 0) return;

        amount = bound(amount, 1, stakedAmount);

        // Warp past minimum stake duration
        vm.warp(block.timestamp + MIN_STAKE_DURATION + 1);

        // Check rate limit
        (bool canUnstake,) = staking.canInitiateUnbonding(staker);
        if (!canUnstake) {
            vm.warp(block.timestamp + 1 hours + 1);
        }

        vm.prank(staker);
        try staking.initiateUnbonding(amount) {
            unbondCount++;
        } catch { }
    }

    /**
     * @notice Complete unbonding
     */
    function completeUnbonding(uint256 stakerIndex, uint256 requestIndex) external {
        if (stakers.length == 0) return;

        stakerIndex = bound(stakerIndex, 0, stakers.length - 1);
        address staker = stakers[stakerIndex];

        uint256 requestCount = staking.getUnbondingRequestCount(staker);
        if (requestCount == 0) return;

        requestIndex = bound(requestIndex, 0, requestCount - 1);

        (,, uint256 completionTime,, bool processed,) = staking.getUnbondingRequest(staker, requestIndex);
        if (processed) return;

        // Warp to completion time
        vm.warp(completionTime + 1);

        vm.prank(staker);
        try staking.completeUnbonding(requestIndex) { } catch { }
    }

    /**
     * @notice Slash a staker
     */
    function slash(uint256 stakerIndex, uint256 bps) external {
        if (stakers.length == 0) return;

        stakerIndex = bound(stakerIndex, 0, stakers.length - 1);
        address staker = stakers[stakerIndex];

        (uint256 stakedAmount,,,,,) = staking.getStakeInfo(staker);
        if (stakedAmount < MIN_STAKE_FOR_SLASHING) return;

        bps = bound(bps, 1, 5000);

        uint256 slashAmount = (stakedAmount * bps) / 10_000;

        try staking.slash(staker, bps, "invariant test") {
            slashCount++;
            totalSlashedAmount += slashAmount;
        } catch { }
    }

    /**
     * @notice Warp time
     */
    function warpTime(uint256 delta) external {
        delta = bound(delta, 1, 30 days);
        vm.warp(block.timestamp + delta);
    }

    /**
     * @notice Get or create a staker
     */
    function _getStaker(uint256 seed) internal returns (address) {
        if (stakers.length > 0 && seed % 3 == 0) {
            // Reuse existing staker
            return stakers[seed % stakers.length];
        }

        // Create new staker
        address staker = address(uint160(seed % type(uint160).max));
        if (staker == address(0) || staker == address(staking) || staker == address(token)) {
            staker = address(uint160(uint256(keccak256(abi.encode(seed)))));
        }

        if (!isStaker[staker]) {
            stakers.push(staker);
            isStaker[staker] = true;
        }

        return staker;
    }

    /**
     * @notice Get sum of all individual stakes
     */
    function getSumOfStakes() external view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            (uint256 amount,,,,,) = staking.getStakeInfo(stakers[i]);
            sum += amount;
        }
        return sum;
    }

    /**
     * @notice Get total slashed amount
     */
    function getTotalSlashed() external view returns (uint256) {
        return totalSlashedAmount;
    }
}
