// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { NexusToken } from "../../src/core/NexusToken.sol";

/**
 * @title NexusTokenInvariantTest
 * @notice Invariant tests for NexusToken contract
 * @dev Tests token invariants that must always hold
 */
contract NexusTokenInvariantTest is StdInvariant, Test {
    NexusToken public token;
    TokenHandler public handler;

    address public admin = address(1);

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    function setUp() public {
        vm.prank(admin);
        token = new NexusToken(admin);

        handler = new TokenHandler(token, admin);

        targetContract(address(handler));

        excludeSender(address(0));
        excludeSender(address(token));
    }

    /**
     * @notice Invariant: Total supply never exceeds MAX_SUPPLY
     */
    function invariant_SupplyNeverExceedsMax() public view {
        assertLe(token.totalSupply(), MAX_SUPPLY, "Supply exceeds max");
    }

    /**
     * @notice Invariant: Sum of balances equals total supply
     */
    function invariant_BalancesSumToTotalSupply() public view {
        uint256 sumOfBalances = handler.getSumOfBalances();
        assertEq(sumOfBalances, token.totalSupply(), "Balances don't sum to total supply");
    }

    /**
     * @notice Invariant: Snapshot IDs are sequential
     */
    function invariant_SnapshotIdsAreSequential() public view {
        uint256 currentId = token.getCurrentSnapshotId();
        assertEq(currentId, handler.expectedSnapshotId(), "Snapshot IDs not sequential");
    }

    /**
     * @notice Invariant: Votes are conserved (total votes <= total supply)
     */
    function invariant_VotesConserved() public view {
        uint256 totalVotes = handler.getSumOfVotes();
        assertLe(totalVotes, token.totalSupply(), "Votes exceed supply");
    }

    /**
     * @notice Call summary
     */
    function invariant_CallSummary() public view {
        console2.log("Mints:", handler.mintCount());
        console2.log("Burns:", handler.burnCount());
        console2.log("Transfers:", handler.transferCount());
        console2.log("Snapshots:", handler.snapshotCount());
        console2.log("Total supply:", token.totalSupply());
    }
}

/**
 * @title TokenHandler
 * @notice Handler contract for token invariant testing
 */
contract TokenHandler is Test {
    NexusToken public token;
    address public admin;

    address[] public holders;
    mapping(address => bool) public isHolder;

    uint256 public mintCount;
    uint256 public burnCount;
    uint256 public transferCount;
    uint256 public snapshotCount;

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    constructor(NexusToken _token, address _admin) {
        token = _token;
        admin = _admin;
    }

    /**
     * @notice Mint tokens
     */
    function mint(address to, uint256 amount) external {
        if (to == address(0) || to == address(token)) return;

        uint256 remaining = MAX_SUPPLY - token.totalSupply();
        if (remaining == 0) return;

        amount = bound(amount, 1, remaining);

        _addHolder(to);

        vm.prank(admin);
        token.mint(to, amount);
        mintCount++;
    }

    /**
     * @notice Burn tokens
     */
    function burn(uint256 holderIndex, uint256 amount) external {
        if (holders.length == 0) return;

        holderIndex = bound(holderIndex, 0, holders.length - 1);
        address holder = holders[holderIndex];

        uint256 balance = token.balanceOf(holder);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(holder);
        token.burn(amount);
        burnCount++;
    }

    /**
     * @notice Transfer tokens
     */
    function transfer(uint256 fromIndex, address to, uint256 amount) external {
        if (holders.length == 0) return;
        if (to == address(0) || to == address(token)) return;

        fromIndex = bound(fromIndex, 0, holders.length - 1);
        address from = holders[fromIndex];

        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        _addHolder(to);

        vm.prank(from);
        token.transfer(to, amount);
        transferCount++;
    }

    /**
     * @notice Take a snapshot
     */
    function snapshot() external {
        vm.roll(block.number + 1);
        vm.prank(admin);
        token.snapshot();
        snapshotCount++;
    }

    /**
     * @notice Delegate votes
     */
    function delegate(uint256 holderIndex, address delegatee) external {
        if (holders.length == 0) return;
        if (delegatee == address(0)) return;

        holderIndex = bound(holderIndex, 0, holders.length - 1);
        address holder = holders[holderIndex];

        _addHolder(delegatee);

        vm.prank(holder);
        token.delegate(delegatee);
    }

    /**
     * @notice Add holder to tracking
     */
    function _addHolder(address holder) internal {
        if (!isHolder[holder]) {
            holders.push(holder);
            isHolder[holder] = true;
        }
    }

    /**
     * @notice Get sum of all balances
     */
    function getSumOfBalances() external view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < holders.length; i++) {
            sum += token.balanceOf(holders[i]);
        }
        return sum;
    }

    /**
     * @notice Get sum of all votes
     */
    function getSumOfVotes() external view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < holders.length; i++) {
            sum += token.getVotes(holders[i]);
        }
        return sum;
    }

    /**
     * @notice Get expected snapshot ID
     */
    function expectedSnapshotId() external view returns (uint256) {
        return snapshotCount;
    }
}
