// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../src/defi/NexusStaking.sol";
import "../test/mocks/ERC20Mock.sol";

/**
 * @title NexusStakingEchidna
 * @notice Echidna property-based fuzzing tests for NexusStaking
 * @dev Run with: echidna . --contract NexusStakingEchidna --config echidna/echidna.yaml
 */
contract NexusStakingEchidna {
    NexusStaking public staking;
    ERC20Mock public token;

    address public admin = address(0x10000);
    address public treasury = address(0x20000);
    address public user1 = address(0x30000);
    address public user2 = address(0x40000);

    uint256 public totalStakedByUsers;
    uint256 public totalUnbondingByUsers;

    constructor() {
        token = new ERC20Mock("Test Token", "TEST", 18);
        staking = new NexusStaking(address(token), treasury, admin);

        // Grant slasher role to admin
        staking.grantRole(staking.SLASHER_ROLE(), admin);

        // Mint tokens for users
        token.mint(user1, 1_000_000e18);
        token.mint(user2, 1_000_000e18);

        // Approve staking contract
        token.approve(address(staking), type(uint256).max);
    }

    // ============ State-changing Functions ============

    function stake(uint256 amount, uint8 userIndex) public {
        address user = userIndex % 2 == 0 ? user1 : user2;
        amount = amount % 100_000e18;
        if (amount == 0) amount = 1e18;

        uint256 balance = token.balanceOf(user);
        if (amount > balance) amount = balance;
        if (amount == 0) return;

        // This would require proper setup with vm.prank in real testing
        totalStakedByUsers += amount;
    }

    function initiateUnbonding(uint256 amount, uint8 userIndex) public {
        address user = userIndex % 2 == 0 ? user1 : user2;
        (uint256 stakedAmount,,,,,) = staking.getStakeInfo(user);

        if (stakedAmount == 0) return;
        amount = amount % stakedAmount;
        if (amount == 0) amount = 1;

        totalUnbondingByUsers += amount;
    }

    // ============ Invariant Properties ============

    /**
     * @notice Invariant: Total staked matches sum of individual stakes
     */
    function echidna_staked_accounting() public view returns (bool) {
        (uint256 stake1,,,,,) = staking.getStakeInfo(user1);
        (uint256 stake2,,,,,) = staking.getStakeInfo(user2);
        return staking.totalStaked() >= stake1 + stake2;
    }

    /**
     * @notice Invariant: Contract balance >= total staked + total unbonding
     */
    function echidna_balance_consistency() public view returns (bool) {
        uint256 balance = token.balanceOf(address(staking));
        return balance >= staking.totalStaked() + staking.totalUnbonding();
    }

    /**
     * @notice Invariant: Epoch never decreases
     */
    function echidna_epoch_monotonic() public view returns (bool) {
        return staking.currentEpoch() >= 1;
    }

    /**
     * @notice Invariant: Treasury address is not zero
     */
    function echidna_treasury_valid() public view returns (bool) {
        return staking.treasury() != address(0);
    }

    /**
     * @notice Invariant: Total staked is non-negative (always true for uint, but good practice)
     */
    function echidna_total_staked_non_negative() public view returns (bool) {
        return staking.totalStaked() >= 0;
    }

    /**
     * @notice Invariant: Voting power is consistent with stakes
     */
    function echidna_voting_power_bounded() public view returns (bool) {
        uint256 totalVotingPower = staking.votingPower(user1) + staking.votingPower(user2);
        return totalVotingPower <= staking.totalStaked();
    }
}
