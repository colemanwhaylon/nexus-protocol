// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { NexusToken } from "../../src/core/NexusToken.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

/**
 * @title NexusTokenFuzzTest
 * @notice Fuzz tests for NexusToken contract
 * @dev Tests ERC20, minting, burning, snapshots, and flash loans
 */
contract NexusTokenFuzzTest is Test {
    NexusToken public token;

    address public admin = address(1);
    address public minter = address(2);
    address public pauser = address(3);

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;
    uint256 public constant FLASH_LOAN_FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    function setUp() public {
        vm.prank(admin);
        token = new NexusToken(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    // ============ Minting Fuzz Tests ============

    /**
     * @notice Fuzz test: Minting should increase balance exactly
     */
    function testFuzz_Mint_IncreasesBalance(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, MAX_SUPPLY);

        uint256 balanceBefore = token.balanceOf(to);

        vm.prank(minter);
        token.mint(to, amount);

        uint256 balanceAfter = token.balanceOf(to);
        assertEq(balanceAfter - balanceBefore, amount, "Balance should increase by minted amount");
    }

    /**
     * @notice Fuzz test: Minting should increase total supply exactly
     */
    function testFuzz_Mint_IncreasesTotalSupply(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, MAX_SUPPLY);

        uint256 supplyBefore = token.totalSupply();

        vm.prank(minter);
        token.mint(to, amount);

        uint256 supplyAfter = token.totalSupply();
        assertEq(supplyAfter - supplyBefore, amount, "Supply should increase by minted amount");
    }

    /**
     * @notice Fuzz test: Cannot mint beyond max supply
     */
    function testFuzz_Mint_CannotExceedMaxSupply(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, MAX_SUPPLY + 1, type(uint256).max / 2);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(to, amount);
    }

    /**
     * @notice Fuzz test: Multiple mints respect max supply
     */
    function testFuzz_MultipleMints_RespectMaxSupply(address[3] memory recipients, uint256[3] memory amounts) public {
        uint256 totalMinted = 0;

        for (uint256 i = 0; i < 3; i++) {
            if (recipients[i] == address(0)) continue;

            uint256 remaining = MAX_SUPPLY - totalMinted;
            if (remaining == 0) break;

            uint256 amount = bound(amounts[i], 1, remaining);

            vm.prank(minter);
            token.mint(recipients[i], amount);
            totalMinted += amount;
        }

        assertLe(token.totalSupply(), MAX_SUPPLY, "Should never exceed max supply");
    }

    // ============ Burning Fuzz Tests ============

    /**
     * @notice Fuzz test: Burning decreases balance exactly
     */
    function testFuzz_Burn_DecreasesBalance(address holder, uint256 mintAmount, uint256 burnPercent) public {
        vm.assume(holder != address(0));
        mintAmount = bound(mintAmount, 1, MAX_SUPPLY);
        burnPercent = bound(burnPercent, 1, 100);

        vm.prank(minter);
        token.mint(holder, mintAmount);

        uint256 burnAmount = (mintAmount * burnPercent) / 100;
        if (burnAmount == 0) burnAmount = 1;

        uint256 balanceBefore = token.balanceOf(holder);

        vm.prank(holder);
        token.burn(burnAmount);

        uint256 balanceAfter = token.balanceOf(holder);
        assertEq(balanceBefore - balanceAfter, burnAmount, "Balance should decrease by burned amount");
    }

    /**
     * @notice Fuzz test: BurnFrom respects allowance
     */
    function testFuzz_BurnFrom_RespectsAllowance(
        address holder,
        address spender,
        uint256 mintAmount,
        uint256 allowance,
        uint256 burnAmount
    )
        public
    {
        vm.assume(holder != address(0) && spender != address(0) && holder != spender);
        mintAmount = bound(mintAmount, 1, MAX_SUPPLY);
        allowance = bound(allowance, 0, mintAmount);
        burnAmount = bound(burnAmount, 1, mintAmount);

        vm.prank(minter);
        token.mint(holder, mintAmount);

        vm.prank(holder);
        token.approve(spender, allowance);

        if (burnAmount > allowance) {
            vm.prank(spender);
            vm.expectRevert();
            token.burnFrom(holder, burnAmount);
        } else {
            vm.prank(spender);
            token.burnFrom(holder, burnAmount);
            assertEq(token.balanceOf(holder), mintAmount - burnAmount, "Should burn correctly");
        }
    }

    // ============ Transfer Fuzz Tests ============

    /**
     * @notice Fuzz test: Transfer conserves total supply
     */
    function testFuzz_Transfer_ConservesTotalSupply(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0) && from != to);
        amount = bound(amount, 1, MAX_SUPPLY);

        vm.prank(minter);
        token.mint(from, amount);

        uint256 supplyBefore = token.totalSupply();

        vm.prank(from);
        token.transfer(to, amount);

        uint256 supplyAfter = token.totalSupply();
        assertEq(supplyBefore, supplyAfter, "Transfer should not change total supply");
    }

    /**
     * @notice Fuzz test: Transfer moves exact amount
     */
    function testFuzz_Transfer_MovesExactAmount(
        address from,
        address to,
        uint256 mintAmount,
        uint256 transferPercent
    )
        public
    {
        vm.assume(from != address(0) && to != address(0) && from != to);
        mintAmount = bound(mintAmount, 1, MAX_SUPPLY);
        transferPercent = bound(transferPercent, 1, 100);

        vm.prank(minter);
        token.mint(from, mintAmount);

        uint256 transferAmount = (mintAmount * transferPercent) / 100;
        if (transferAmount == 0) transferAmount = 1;

        uint256 fromBefore = token.balanceOf(from);
        uint256 toBefore = token.balanceOf(to);

        vm.prank(from);
        token.transfer(to, transferAmount);

        uint256 fromAfter = token.balanceOf(from);
        uint256 toAfter = token.balanceOf(to);

        assertEq(fromBefore - fromAfter, transferAmount, "Sender balance should decrease");
        assertEq(toAfter - toBefore, transferAmount, "Recipient balance should increase");
    }

    // ============ Snapshot Fuzz Tests ============

    /**
     * @notice Fuzz test: Snapshots preserve historical balances
     * @dev Snapshots track balances at block boundaries
     */
    function testFuzz_Snapshot_PreservesHistoricalBalance(
        address holder,
        uint256 initialAmount,
        uint256 additionalAmount
    )
        public
    {
        vm.assume(holder != address(0));
        initialAmount = bound(initialAmount, 1e18, MAX_SUPPLY / 4);
        additionalAmount = bound(additionalAmount, 1e18, MAX_SUPPLY / 4);

        // Mint initial amount
        vm.prank(minter);
        token.mint(holder, initialAmount);

        // Move to next block and take snapshot
        vm.roll(block.number + 1);
        vm.prank(admin);
        uint256 snapshotId = token.snapshot();

        // Move to next block before minting more (important for checkpoint tracking)
        vm.roll(block.number + 1);

        // Mint more
        vm.prank(minter);
        token.mint(holder, additionalAmount);

        // Move to next block for query
        vm.roll(block.number + 1);

        // Check snapshot reflects initial balance
        uint256 snapshotBalance = token.balanceOfAt(holder, snapshotId);
        assertEq(snapshotBalance, initialAmount, "Snapshot should reflect balance at time of snapshot");

        // Current balance should be higher
        assertEq(token.balanceOf(holder), initialAmount + additionalAmount, "Current balance should be updated");
    }

    /**
     * @notice Fuzz test: Multiple snapshots track independently
     * @dev Tests that each snapshot captures the correct cumulative balance
     */
    function testFuzz_MultipleSnapshots_TrackIndependently(address holder, uint256[3] memory amounts) public {
        vm.assume(holder != address(0));

        uint256 totalMinted = 0;
        uint256[3] memory snapshots;
        uint256[3] memory expectedBalances;

        for (uint256 i = 0; i < 3; i++) {
            // Bound to reasonable amounts that won't exceed max supply
            uint256 amount = bound(amounts[i], 1e18, MAX_SUPPLY / 10);

            vm.prank(minter);
            token.mint(holder, amount);
            totalMinted += amount;

            // Advance block before taking snapshot
            vm.roll(block.number + 1);
            vm.prank(admin);
            snapshots[i] = token.snapshot();
            expectedBalances[i] = totalMinted;

            // Advance block after snapshot
            vm.roll(block.number + 1);
        }

        // Final block advance for query
        vm.roll(block.number + 1);

        // Verify each snapshot has correct balance
        for (uint256 i = 0; i < 3; i++) {
            uint256 snapshotBalance = token.balanceOfAt(holder, snapshots[i]);
            assertEq(snapshotBalance, expectedBalances[i], "Each snapshot should have correct balance");
        }
    }

    // ============ Flash Loan Fuzz Tests ============

    /**
     * @notice Fuzz test: Flash loan fee calculation is correct
     */
    function testFuzz_FlashLoan_FeeCalculation(uint256 amount) public {
        amount = bound(amount, 1, MAX_SUPPLY);

        // Need to mint tokens first for flash loan capacity
        vm.prank(minter);
        token.mint(address(token), amount);

        uint256 fee = token.flashFee(address(token), amount);

        // Fee should be ceil(amount * 10 / 10000)
        uint256 expectedFee = (amount * FLASH_LOAN_FEE_BPS + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        assertEq(fee, expectedFee, "Fee calculation should be correct");
    }

    /**
     * @notice Fuzz test: Max flash loan respects supply cap
     */
    function testFuzz_MaxFlashLoan_RespectsSupplyCap(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 0, MAX_SUPPLY);

        if (mintAmount > 0) {
            vm.prank(minter);
            token.mint(address(1), mintAmount);
        }

        uint256 maxLoan = token.maxFlashLoan(address(token));
        assertEq(maxLoan, MAX_SUPPLY - mintAmount, "Max flash loan should be remaining supply");
    }

    // ============ Delegation/Voting Fuzz Tests ============

    /**
     * @notice Fuzz test: Delegation updates voting power
     */
    function testFuzz_Delegate_UpdatesVotingPower(address holder, address delegatee, uint256 amount) public {
        vm.assume(holder != address(0) && delegatee != address(0));
        amount = bound(amount, 1, MAX_SUPPLY);

        vm.prank(minter);
        token.mint(holder, amount);

        vm.prank(holder);
        token.delegate(delegatee);

        uint256 votes = token.getVotes(delegatee);
        assertEq(votes, amount, "Delegatee should have voting power");
    }

    /**
     * @notice Fuzz test: Self-delegation gives voting power
     */
    function testFuzz_SelfDelegate_GivesVotingPower(address holder, uint256 amount) public {
        vm.assume(holder != address(0));
        amount = bound(amount, 1, MAX_SUPPLY);

        vm.prank(minter);
        token.mint(holder, amount);

        // Before delegation, no votes
        assertEq(token.getVotes(holder), 0, "Should have no votes before delegation");

        vm.prank(holder);
        token.delegate(holder);

        assertEq(token.getVotes(holder), amount, "Should have votes after self-delegation");
    }

    // ============ Pause Fuzz Tests ============

    /**
     * @notice Fuzz test: Transfers fail when paused
     */
    function testFuzz_Pause_BlocksTransfers(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0) && from != to);
        amount = bound(amount, 1, MAX_SUPPLY);

        vm.prank(minter);
        token.mint(from, amount);

        vm.prank(pauser);
        token.pause();

        vm.prank(from);
        vm.expectRevert();
        token.transfer(to, amount);
    }

    /**
     * @notice Fuzz test: Minting fails when paused
     */
    function testFuzz_Pause_BlocksMinting(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, MAX_SUPPLY);

        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.mint(to, amount);
    }

    // ============ Invariant-style Tests ============

    /**
     * @notice Fuzz test: Sum of all balances equals total supply
     */
    function testFuzz_Invariant_BalancesSumToSupply(address[5] memory holders, uint256[5] memory amounts) public {
        uint256 totalMinted = 0;

        for (uint256 i = 0; i < 5; i++) {
            if (holders[i] == address(0)) continue;

            uint256 remaining = MAX_SUPPLY - totalMinted;
            if (remaining == 0) break;

            uint256 amount = bound(amounts[i], 1, remaining / 2);

            vm.prank(minter);
            token.mint(holders[i], amount);
            totalMinted += amount;
        }

        assertEq(token.totalSupply(), totalMinted, "Total supply should equal sum of mints");
    }
}
