// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { NexusGovernor } from "../../src/governance/NexusGovernor.sol";
import { NexusTimelock } from "../../src/governance/NexusTimelock.sol";
import { NexusToken } from "../../src/core/NexusToken.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title NexusGovernorTest
 * @notice Comprehensive unit tests for NexusGovernor contract
 * @dev Tests cover:
 *      - Deployment and initialization
 *      - Proposal creation and validation
 *      - Voting mechanics (For, Against, Abstain)
 *      - Quorum requirements
 *      - Proposal execution through timelock
 *      - Configuration queries
 *      - Edge cases and error conditions
 */
contract NexusGovernorTest is Test {
    NexusGovernor public governor;
    NexusTimelock public timelock;
    NexusToken public token;

    address public admin = address(1);
    address public proposer = address(2);
    address public voter1 = address(3);
    address public voter2 = address(4);
    address public voter3 = address(5);
    address public nonVoter = address(6);

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18; // 100M tokens
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 * 1e18; // 100K tokens
    uint256 public constant VOTER_BALANCE = 10_000_000 * 1e18; // 10M tokens each
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4%
    uint48 public constant VOTING_DELAY = 7200; // ~1 day
    uint32 public constant VOTING_PERIOD = 36_000; // ~5 days
    uint256 public constant TIMELOCK_DELAY = 48 hours;

    // Events
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalCreatedWithDetails(
        uint256 indexed proposalId, address indexed proposer, uint256 votingPower, uint256 startBlock, uint256 endBlock
    );
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalExecuted(uint256 proposalId);
    event GovernorInitialized(
        address indexed token,
        address indexed timelock,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    );

    function setUp() public {
        vm.startPrank(admin);

        // Deploy token
        token = new NexusToken(admin);

        // Mint initial supply
        token.mint(admin, INITIAL_SUPPLY);

        // Set up timelock proposers and executors arrays
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(1); // Placeholder, will be updated
        executors[0] = address(0); // Open execution

        // Deploy timelock with 48 hour delay
        timelock = new NexusTimelock(TIMELOCK_DELAY, proposers, executors, admin);

        // Deploy governor
        governor = new NexusGovernor(IVotes(address(token)), timelock);

        // Grant proposer role to governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));

        // Grant executor role to governor (for execution through governor)
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        // Distribute tokens to voters
        token.transfer(proposer, PROPOSAL_THRESHOLD * 2); // Enough to propose
        token.transfer(voter1, VOTER_BALANCE);
        token.transfer(voter2, VOTER_BALANCE);
        token.transfer(voter3, VOTER_BALANCE);

        vm.stopPrank();

        // Voters delegate to themselves for voting power
        vm.prank(proposer);
        token.delegate(proposer);

        vm.prank(voter1);
        token.delegate(voter1);

        vm.prank(voter2);
        token.delegate(voter2);

        vm.prank(voter3);
        token.delegate(voter3);

        // Move forward one block to ensure delegation is active
        vm.roll(block.number + 1);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(governor.name(), "NexusGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governor.quorumNumerator(), QUORUM_PERCENTAGE);
        assertEq(governor.timelock(), address(timelock));
        assertEq(governor.governanceToken(), address(token));
    }

    function test_Deployment_RevertInvalidToken() public {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(governor);
        executors[0] = address(0);

        NexusTimelock newTimelock = new NexusTimelock(TIMELOCK_DELAY, proposers, executors, admin);

        vm.expectRevert(); // OpenZeppelin GovernorVotes reverts before our check
        new NexusGovernor(IVotes(address(0)), newTimelock);
    }

    function test_Deployment_RevertInvalidTimelock() public {
        vm.expectRevert(NexusGovernor.InvalidTimelock.selector);
        new NexusGovernor(IVotes(address(token)), TimelockController(payable(address(0))));
    }

    // ============ Proposal Creation Tests ============

    function test_Propose() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertGt(proposalId, 0);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_Propose_EmitsEvents() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Verify proposal was created by checking state
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_Propose_RevertInsufficientVotingPower() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        // nonVoter has no tokens
        vm.prank(nonVoter);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, description);
    }

    function test_Propose_MultipleTargets() public {
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory calldatas = new bytes[](3);

        targets[0] = address(token);
        targets[1] = address(token);
        targets[2] = address(timelock);

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;

        calldatas[0] = abi.encodeWithSignature("pause()");
        calldatas[1] = abi.encodeWithSignature("unpause()");
        calldatas[2] = abi.encodeWithSignature("getMinDelay()");

        string memory description = "Multi-target proposal";

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertGt(proposalId, 0);
    }

    // ============ Voting Tests ============

    function test_CastVote_For() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = For

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, VOTER_BALANCE);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_CastVote_Against() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVote(proposalId, 0); // 0 = Against

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0);
        assertEq(againstVotes, VOTER_BALANCE);
        assertEq(abstainVotes, 0);
    }

    function test_CastVote_Abstain() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVote(proposalId, 2); // 2 = Abstain

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, VOTER_BALANCE);
    }

    function test_CastVote_WithReason() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVoteWithReason(proposalId, 1, "I support this proposal");

        assertTrue(governor.hasVoted(proposalId, voter1));
    }

    function test_CastVote_MultipleVoters() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVote(proposalId, 1); // For

        vm.prank(voter2);
        governor.castVote(proposalId, 0); // Against

        vm.prank(voter3);
        governor.castVote(proposalId, 2); // Abstain

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, VOTER_BALANCE);
        assertEq(againstVotes, VOTER_BALANCE);
        assertEq(abstainVotes, VOTER_BALANCE);
    }

    function test_CastVote_RevertAlreadyVoted() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter1);
        vm.expectRevert();
        governor.castVote(proposalId, 0); // Try to vote again
    }

    function test_CastVote_RevertNotActive() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Try to vote before voting delay
        vm.prank(voter1);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function test_CastVote_ZeroVotingPower() public {
        uint256 proposalId = _createAndActivateProposal();

        // OpenZeppelin Governor allows voting with 0 power, it just doesn't count
        vm.prank(nonVoter);
        governor.castVote(proposalId, 1);

        // Votes should still be 0 since nonVoter has no voting power
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    // ============ Quorum Tests ============

    function test_Quorum_Calculation() public view {
        // Quorum should be 4% of total supply
        uint256 expectedQuorum = (INITIAL_SUPPLY * QUORUM_PERCENTAGE) / 100;
        assertEq(governor.quorum(block.number - 1), expectedQuorum);
    }

    function test_Quorum_Reached() public {
        uint256 proposalId = _createAndActivateProposal();

        // All three voters vote For - should exceed quorum (30M > 4M required)
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.prank(voter3);
        governor.castVote(proposalId, 1);

        // Fast forward past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Should be succeeded (quorum met and majority For)
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
    }

    function test_Quorum_NotReached() public {
        // Create a fresh setup with lower voter balance
        vm.startPrank(admin);

        // Deploy new token and governor with specific balances
        NexusToken newToken = new NexusToken(admin);
        newToken.mint(admin, INITIAL_SUPPLY);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = admin;
        executors[0] = address(0);

        NexusTimelock newTimelock = new NexusTimelock(TIMELOCK_DELAY, proposers, executors, admin);

        NexusGovernor newGovernor = new NexusGovernor(IVotes(address(newToken)), newTimelock);
        newTimelock.grantRole(newTimelock.PROPOSER_ROLE(), address(newGovernor));
        newTimelock.grantRole(newTimelock.EXECUTOR_ROLE(), address(newGovernor));

        // Give proposer just enough to propose
        newToken.transfer(proposer, PROPOSAL_THRESHOLD * 2);

        // Give voter only a small amount (less than quorum)
        uint256 smallAmount = 1_000_000 * 1e18; // 1M tokens (< 4M quorum)
        newToken.transfer(voter1, smallAmount);

        vm.stopPrank();

        vm.prank(proposer);
        newToken.delegate(proposer);

        vm.prank(voter1);
        newToken.delegate(voter1);

        vm.roll(block.number + 1);

        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(newToken);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("name()");

        vm.prank(proposer);
        uint256 proposalId = newGovernor.propose(targets, values, calldatas, "Low quorum test");

        // Move past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // Vote with insufficient amount
        vm.prank(voter1);
        newGovernor.castVote(proposalId, 1);

        // Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Should be defeated (quorum not met)
        assertEq(uint256(newGovernor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    // ============ Proposal State Tests ============

    function test_ProposalState_Pending() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_ProposalState_Active() public {
        uint256 proposalId = _createAndActivateProposal();
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
    }

    function test_ProposalState_Defeated_NoVotes() public {
        uint256 proposalId = _createAndActivateProposal();

        // Fast forward past voting period without any votes
        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_ProposalState_Defeated_MajorityAgainst() public {
        uint256 proposalId = _createAndActivateProposal();

        // All voters vote against
        vm.prank(voter1);
        governor.castVote(proposalId, 0); // Against

        vm.prank(voter2);
        governor.castVote(proposalId, 0); // Against

        vm.prank(voter3);
        governor.castVote(proposalId, 0); // Against

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_ProposalState_Succeeded() public {
        uint256 proposalId = _createAndActivateProposal();

        // Majority votes for
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.prank(voter3);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
    }

    // ============ Queue and Execute Tests ============

    function test_Queue_AfterSucceeded() public {
        uint256 proposalId = _createSucceededProposal();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(voter1);
        governor.queue(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
    }

    function test_Queue_RevertNotSucceeded() public {
        uint256 proposalId = _createAndActivateProposal();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        bytes32 descriptionHash = keccak256(bytes(description));

        // Try to queue while still active
        vm.prank(voter1);
        vm.expectRevert();
        governor.queue(targets, values, calldatas, descriptionHash);
    }

    function test_Execute_AfterTimelock() public {
        // Create and pass a proposal
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Move past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // Vote to pass
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.prank(voter3);
        governor.castVote(proposalId, 1);

        // Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Move past timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }

    function test_Execute_RevertBeforeTimelock() public {
        // Create and pass a proposal
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        // Store proposalId before voting to avoid prank consumption by hashProposal
        bytes32 descriptionHash = keccak256(bytes(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.prank(voter3);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(targets, values, calldatas, descriptionHash);

        // Try to execute before timelock delay
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    // ============ Cancel Tests ============

    function test_Cancel_ByProposer() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        bytes32 descriptionHash = keccak256(bytes(description));

        // Proposer can cancel their own proposal
        vm.prank(proposer);
        governor.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    // ============ View Function Tests ============

    function test_GetProposalDetails() public {
        uint256 proposalId = _createAndActivateProposal();

        vm.prank(voter1);
        governor.castVote(proposalId, 1); // For

        vm.prank(voter2);
        governor.castVote(proposalId, 0); // Against

        (
            uint256 snapshot,
            uint256 deadline,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool executed
        ) = governor.getProposalDetails(proposalId);

        assertGt(snapshot, 0);
        assertGt(deadline, snapshot);
        assertEq(forVotes, VOTER_BALANCE);
        assertEq(againstVotes, VOTER_BALANCE);
        assertEq(abstainVotes, 0);
        assertFalse(executed);
    }

    function test_GetGovernanceConfig() public view {
        (
            uint256 _votingDelay,
            uint256 _votingPeriod,
            uint256 _proposalThreshold,
            uint256 _quorumNumerator,
            address _timelock
        ) = governor.getGovernanceConfig();

        assertEq(_votingDelay, VOTING_DELAY);
        assertEq(_votingPeriod, VOTING_PERIOD);
        assertEq(_proposalThreshold, PROPOSAL_THRESHOLD);
        assertEq(_quorumNumerator, QUORUM_PERCENTAGE);
        assertEq(_timelock, address(timelock));
    }

    function test_HasVoted() public {
        uint256 proposalId = _createAndActivateProposal();

        assertFalse(governor.hasVoted(proposalId, voter1));

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        assertTrue(governor.hasVoted(proposalId, voter1));
        assertFalse(governor.hasVoted(proposalId, voter2));
    }

    function test_ProposalSnapshot() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        uint256 blockBefore = block.number;

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Snapshot should be current block + voting delay
        assertEq(governor.proposalSnapshot(proposalId), blockBefore + VOTING_DELAY);
    }

    function test_ProposalDeadline() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        uint256 blockBefore = block.number;

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Deadline should be current block + voting delay + voting period
        assertEq(governor.proposalDeadline(proposalId), blockBefore + VOTING_DELAY + VOTING_PERIOD);
    }

    // ============ Edge Cases ============

    function test_VotingPowerAtSnapshot() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        uint256 snapshot = governor.proposalSnapshot(proposalId);

        // Transfer tokens after proposal creation but before snapshot
        vm.roll(block.number + 1);

        vm.prank(voter1);
        token.transfer(nonVoter, VOTER_BALANCE / 2);

        // Move past voting delay to snapshot point
        vm.roll(snapshot + 1);

        // nonVoter can vote, but with 0 weight because tokens weren't delegated at snapshot
        vm.prank(nonVoter);
        governor.castVote(proposalId, 1);

        // Verify the vote counted as 0
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0); // nonVoter had no voting power at snapshot
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testFuzz_ProposeWithDifferentThresholds(uint256 tokenAmount) public {
        tokenAmount = bound(tokenAmount, PROPOSAL_THRESHOLD, VOTER_BALANCE);

        // Create new voter with specific amount
        address newProposer = address(0x999);
        vm.prank(admin);
        token.transfer(newProposer, tokenAmount);

        vm.prank(newProposer);
        token.delegate(newProposer);

        vm.roll(block.number + 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(newProposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertGt(proposalId, 0);
    }

    // ============ Helper Functions ============

    function _createSimpleProposal()
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("name()");
        description = "Test Proposal #1";

        return (targets, values, calldatas, description);
    }

    function _createAndActivateProposal() internal returns (uint256 proposalId) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _createSimpleProposal();

        vm.prank(proposer);
        proposalId = governor.propose(targets, values, calldatas, description);

        // Move past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        return proposalId;
    }

    function _createSucceededProposal() internal returns (uint256 proposalId) {
        proposalId = _createAndActivateProposal();

        // Vote to pass
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.prank(voter3);
        governor.castVote(proposalId, 1);

        // Move past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        return proposalId;
    }
}
