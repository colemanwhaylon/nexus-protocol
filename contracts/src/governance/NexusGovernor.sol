// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovernorTimelockControl } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title NexusGovernor
 * @author Nexus Protocol Team
 * @notice On-chain governance contract for Nexus Protocol using OpenZeppelin Governor
 * @dev Implements OpenZeppelin Governor with the following extensions:
 *      - GovernorSettings: Configurable voting delay, period, and proposal threshold
 *      - GovernorCountingSimple: For, Against, Abstain voting with quorum check
 *      - GovernorVotes: Uses NexusToken for voting power (ERC20Votes compatible)
 *      - GovernorVotesQuorumFraction: Quorum as percentage of total supply
 *      - GovernorTimelockControl: Proposals executed through NexusTimelock
 *
 * Governance Parameters (configurable via proposals):
 *      - Voting Delay: 1 day (7200 blocks @ 12s/block)
 *      - Voting Period: 5 days (36000 blocks @ 12s/block)
 *      - Proposal Threshold: 100,000 tokens (0.01% of max supply)
 *      - Quorum: 4% of total token supply
 *
 * Security Considerations (per SECURITY_REVIEW_BEFORE.md):
 *      - SEC-006: Proposals require sufficient voting power to prevent spam
 *      - SEC-013: All governance actions emit comprehensive events
 *      - Timelock integration prevents flash governance attacks
 *      - Quorum requirement ensures sufficient participation
 *
 * @custom:security-contact security@nexusprotocol.io
 */
contract NexusGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // ============ Constants ============

    /// @notice Default voting delay in blocks (~1 day at 12s/block)
    uint48 public constant DEFAULT_VOTING_DELAY = 7200;

    /// @notice Default voting period in blocks (~5 days at 12s/block)
    uint32 public constant DEFAULT_VOTING_PERIOD = 36_000;

    /// @notice Default proposal threshold (100,000 tokens = 0.01% of 1B max supply)
    uint256 public constant DEFAULT_PROPOSAL_THRESHOLD = 100_000 * 10 ** 18;

    /// @notice Default quorum percentage (4% of total supply)
    uint256 public constant DEFAULT_QUORUM_PERCENTAGE = 4;

    // ============ Events ============

    /// @notice Emitted when the governor is initialized
    event GovernorInitialized(
        address indexed token,
        address indexed timelock,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    );

    /// @notice Emitted when a proposal is created with extended details
    event ProposalCreatedWithDetails(
        uint256 indexed proposalId, address indexed proposer, uint256 votingPower, uint256 startBlock, uint256 endBlock
    );

    /// @notice Emitted when voting settings are updated
    event VotingSettingsUpdated(
        uint256 oldVotingDelay,
        uint256 newVotingDelay,
        uint256 oldVotingPeriod,
        uint256 newVotingPeriod,
        uint256 oldProposalThreshold,
        uint256 newProposalThreshold
    );

    // ============ Errors ============

    /// @notice Thrown when token address is zero
    error InvalidToken();

    /// @notice Thrown when timelock address is zero
    error InvalidTimelock();

    /// @notice Thrown when quorum percentage is invalid
    error InvalidQuorumPercentage(uint256 percentage);

    // ============ Constructor ============

    /**
     * @notice Initializes the NexusGovernor with token and timelock
     * @dev Sets up the governor with default parameters:
     *      - 1 day voting delay
     *      - 5 day voting period
     *      - 100,000 token proposal threshold
     *      - 4% quorum
     *
     * @param token_ The NexusToken contract (must implement IVotes)
     * @param timelock_ The NexusTimelock contract for execution
     */
    constructor(
        IVotes token_,
        TimelockController timelock_
    )
        Governor("NexusGovernor")
        GovernorSettings(DEFAULT_VOTING_DELAY, DEFAULT_VOTING_PERIOD, DEFAULT_PROPOSAL_THRESHOLD)
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(DEFAULT_QUORUM_PERCENTAGE)
        GovernorTimelockControl(timelock_)
    {
        if (address(token_) == address(0)) revert InvalidToken();
        if (address(timelock_) == address(0)) revert InvalidTimelock();

        emit GovernorInitialized(
            address(token_),
            address(timelock_),
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_PERCENTAGE
        );
    }

    // ============ External Functions ============

    /**
     * @notice Creates a proposal with extended event emission
     * @dev Override to emit ProposalCreatedWithDetails for better off-chain indexing
     * @param targets Target addresses for proposal calls
     * @param values ETH values for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description Proposal description
     * @return proposalId The ID of the created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        virtual
        override(Governor)
        returns (uint256 proposalId)
    {
        proposalId = super.propose(targets, values, calldatas, description);

        emit ProposalCreatedWithDetails(
            proposalId,
            _msgSender(),
            getVotes(_msgSender(), block.number - 1),
            proposalSnapshot(proposalId),
            proposalDeadline(proposalId)
        );

        return proposalId;
    }

    // ============ View Functions ============

    /**
     * @notice Returns the governance token address
     * @return The token contract address
     */
    function governanceToken() external view returns (address) {
        return address(token());
    }

    /**
     * @notice Returns complete proposal details
     * @param proposalId The proposal ID to query
     * @return snapshot Block number for vote weight snapshot
     * @return deadline Block number when voting ends
     * @return forVotes Total votes in favor
     * @return againstVotes Total votes against
     * @return abstainVotes Total abstaining votes
     * @return executed Whether proposal has been executed
     */
    function getProposalDetails(uint256 proposalId)
        external
        view
        returns (
            uint256 snapshot,
            uint256 deadline,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool executed
        )
    {
        snapshot = proposalSnapshot(proposalId);
        deadline = proposalDeadline(proposalId);
        (againstVotes, forVotes, abstainVotes) = proposalVotes(proposalId);
        executed = state(proposalId) == ProposalState.Executed;
    }

    /**
     * @notice Returns complete governance configuration
     * @return _votingDelay Current voting delay in blocks
     * @return _votingPeriod Current voting period in blocks
     * @return _proposalThreshold Current proposal threshold in tokens
     * @return _quorumNumerator Current quorum percentage
     * @return _timelock Timelock controller address
     */
    function getGovernanceConfig()
        external
        view
        returns (
            uint256 _votingDelay,
            uint256 _votingPeriod,
            uint256 _proposalThreshold,
            uint256 _quorumNumerator,
            address _timelock
        )
    {
        _votingDelay = votingDelay();
        _votingPeriod = votingPeriod();
        _proposalThreshold = proposalThreshold();
        _quorumNumerator = quorumNumerator();
        _timelock = timelock();
    }

    // ============ Required Overrides ============

    /**
     * @notice Returns the voting delay in blocks
     * @dev Override required due to multiple inheritance
     */
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @notice Returns the voting period in blocks
     * @dev Override required due to multiple inheritance
     */
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @notice Returns the quorum for a specific block
     * @dev Override required due to multiple inheritance
     * @param blockNumber The block number to check quorum for
     */
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    /**
     * @notice Returns the state of a proposal
     * @dev Override required due to GovernorTimelockControl
     * @param proposalId The proposal ID to check
     */
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /**
     * @notice Checks if a proposal needs queuing
     * @dev Override required due to GovernorTimelockControl
     * @param proposalId The proposal ID to check
     */
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /**
     * @notice Returns the proposal threshold
     * @dev Override required due to multiple inheritance
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /**
     * @notice Internal function to queue operations
     * @dev Override required due to GovernorTimelockControl
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint48)
    {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Internal function to execute operations
     * @dev Override required due to GovernorTimelockControl
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Internal function to cancel operations
     * @dev Override required due to GovernorTimelockControl
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Returns the executor address
     * @dev Override required due to GovernorTimelockControl
     */
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
