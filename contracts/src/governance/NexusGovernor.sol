// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title NexusGovernor
 * @author Nexus Protocol Team
 * @notice Decentralized governance contract for the Nexus Protocol ecosystem
 * @dev Implements OpenZeppelin Governor pattern with the following extensions:
 *      - GovernorSettings: Configurable voting delay, period, and proposal threshold
 *      - GovernorCountingSimple: Standard For/Against/Abstain voting
 *      - GovernorVotes: Integration with ERC20Votes (NexusToken)
 *      - GovernorVotesQuorumFraction: Quorum as percentage of total supply
 *      - GovernorTimelockControl: Timelock for proposal execution
 *
 * Governance Parameters:
 *      - Voting Delay: 1 day (7200 blocks at 12s/block)
 *      - Voting Period: 7 days (50400 blocks at 12s/block)
 *      - Proposal Threshold: 100,000 tokens
 *      - Quorum: 4% of total supply
 *
 * Security Considerations (per SECURITY_REVIEW_BEFORE.md):
 *      - SEC-013: Comprehensive event emissions for all governance actions
 *      - All governance parameters are updatable only through governance proposals
 *      - Timelock integration ensures delay before execution
 *      - Proposal cancellation restricted to proposer only
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

    /// @notice Version string for EIP-712 domain separator
    string private constant GOVERNOR_VERSION = "1";

    /// @notice Default voting delay in blocks (~1 day at 12s/block)
    uint48 public constant DEFAULT_VOTING_DELAY = 7200;

    /// @notice Default voting period in blocks (~7 days at 12s/block)
    uint32 public constant DEFAULT_VOTING_PERIOD = 50400;

    /// @notice Default proposal threshold (100,000 tokens with 18 decimals)
    uint256 public constant DEFAULT_PROPOSAL_THRESHOLD = 100_000 * 10 ** 18;

    /// @notice Default quorum numerator (4% of total supply)
    uint256 public constant DEFAULT_QUORUM_NUMERATOR = 4;

    // ============ Admin Override State (Testnet Only) ============

    /// @notice Flag indicating if this contract is deployed on testnet
    /// @dev When true, admin can override governance parameters directly
    bool public immutable isTestnet;

    /// @notice Admin address that can override parameters (testnet only)
    address public immutable admin;

    // ============ Events - SEC-013 ============

    /// @notice Emitted when governance parameters are initialized
    /// @param votingDelay Initial voting delay in blocks
    /// @param votingPeriod Initial voting period in blocks
    /// @param proposalThreshold Initial proposal threshold in tokens
    /// @param quorumNumerator Initial quorum percentage
    event GovernorInitialized(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumNumerator
    );

    /// @notice Emitted when a proposal is created with extended details
    /// @param proposalId The unique identifier for the proposal
    /// @param proposer Address that created the proposal
    /// @param targets Target addresses for the proposal calls
    /// @param values ETH values for the proposal calls
    /// @param signatures Function signatures (empty for Governor pattern)
    /// @param calldatas Encoded function call data
    /// @param voteStart Block number when voting starts
    /// @param voteEnd Block number when voting ends
    /// @param description Human-readable proposal description
    event ProposalCreatedExtended(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    /// @notice Emitted when a proposal is canceled (with canceler info)
    /// @param proposalId The unique identifier for the proposal
    /// @param canceler Address that canceled the proposal
    event ProposalCanceledBy(uint256 indexed proposalId, address indexed canceler);

    /// @notice Emitted when a vote is cast with detailed information
    /// @param voter Address of the voter
    /// @param proposalId The proposal being voted on
    /// @param support Vote direction (0=Against, 1=For, 2=Abstain)
    /// @param weight Voting weight used
    /// @param reason Optional reason string
    event VoteCastWithDetails(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    /// @notice Emitted when admin overrides proposal threshold (testnet only)
    /// @param oldThreshold Previous threshold value
    /// @param newThreshold New threshold value
    event ProposalThresholdUpdatedByAdmin(uint256 oldThreshold, uint256 newThreshold);

    /// @notice Emitted when admin overrides voting delay (testnet only)
    /// @param oldDelay Previous voting delay in blocks
    /// @param newDelay New voting delay in blocks
    event VotingDelayUpdatedByAdmin(uint256 oldDelay, uint256 newDelay);

    /// @notice Emitted when admin overrides voting period (testnet only)
    /// @param oldPeriod Previous voting period in blocks
    /// @param newPeriod New voting period in blocks
    event VotingPeriodUpdatedByAdmin(uint256 oldPeriod, uint256 newPeriod);

    // ============ Errors ============

    /// @notice Thrown when zero address is provided for token
    error InvalidToken();

    /// @notice Thrown when zero address is provided for timelock
    error InvalidTimelock();

    /// @notice Thrown when caller is not the proposer
    error OnlyProposer();

    /// @notice Thrown when proposal is in invalid state for operation
    error InvalidProposalState(uint256 proposalId, ProposalState current, ProposalState required);

    /// @notice Thrown when admin override is attempted on mainnet
    error AdminOverrideNotAllowed();

    /// @notice Thrown when caller is not the admin
    error OnlyAdmin();

    /// @notice Thrown when zero address is provided for admin
    error InvalidAdmin();

    // ============ Constructor ============

    /**
     * @notice Initializes the NexusGovernor with governance parameters
     * @dev Sets up all Governor extensions. On testnet, admin can override parameters.
     *      Default values:
     *      - Voting Delay: 1 day (~7200 blocks) OR custom for testnet
     *      - Voting Period: 7 days (~50400 blocks) OR custom for testnet
     *      - Proposal Threshold: 100,000 NXS tokens OR custom for testnet
     *      - Quorum: 4% of total supply
     *
     * @param token_ The NexusToken (ERC20Votes) contract address
     * @param timelock_ The TimelockController contract address
     * @param admin_ Admin address for testnet parameter overrides (can be zero on mainnet)
     * @param isTestnet_ If true, enables admin override functionality
     * @param initialVotingDelay_ Initial voting delay in blocks (use 0 for default)
     * @param initialVotingPeriod_ Initial voting period in blocks (use 0 for default)
     * @param initialProposalThreshold_ Initial proposal threshold (use 0 for default)
     *
     * Requirements:
     * - token_ must not be zero address
     * - timelock_ must not be zero address
     * - admin_ must not be zero address if isTestnet_ is true
     */
    constructor(
        IVotes token_,
        TimelockController timelock_,
        address admin_,
        bool isTestnet_,
        uint48 initialVotingDelay_,
        uint32 initialVotingPeriod_,
        uint256 initialProposalThreshold_
    )
        Governor("NexusGovernor")
        GovernorSettings(
            initialVotingDelay_ > 0 ? initialVotingDelay_ : DEFAULT_VOTING_DELAY,
            initialVotingPeriod_ > 0 ? initialVotingPeriod_ : DEFAULT_VOTING_PERIOD,
            initialProposalThreshold_ > 0 ? initialProposalThreshold_ : DEFAULT_PROPOSAL_THRESHOLD
        )
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(DEFAULT_QUORUM_NUMERATOR)
        GovernorTimelockControl(timelock_)
    {
        if (address(token_) == address(0)) revert InvalidToken();
        if (address(timelock_) == address(0)) revert InvalidTimelock();
        if (isTestnet_ && admin_ == address(0)) revert InvalidAdmin();

        isTestnet = isTestnet_;
        admin = admin_;

        emit GovernorInitialized(
            initialVotingDelay_ > 0 ? initialVotingDelay_ : DEFAULT_VOTING_DELAY,
            initialVotingPeriod_ > 0 ? initialVotingPeriod_ : DEFAULT_VOTING_PERIOD,
            initialProposalThreshold_ > 0 ? initialProposalThreshold_ : DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );
    }

    // ============ External Functions ============

    /**
     * @notice Creates a new governance proposal
     * @dev Override to emit extended proposal details - SEC-013
     * @param targets Target addresses for proposal calls
     * @param values ETH values to send with each call
     * @param calldatas Encoded function call data for each target
     * @param description Human-readable description of the proposal
     * @return proposalId The unique identifier for the created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override(Governor) returns (uint256) {
        uint256 proposalId = super.propose(targets, values, calldatas, description);

        // Emit extended event with more details - SEC-013
        string[] memory signatures = new string[](targets.length);
        emit ProposalCreatedExtended(
            proposalId,
            _msgSender(),
            targets,
            values,
            signatures,
            calldatas,
            proposalSnapshot(proposalId),
            proposalDeadline(proposalId),
            description
        );

        return proposalId;
    }

    /**
     * @notice Cancels a proposal
     * @dev Only the proposer can cancel their own proposal
     *      Emits ProposalCanceledBy event - SEC-013
     * @param targets Target addresses for proposal calls
     * @param values ETH values to send with each call
     * @param calldatas Encoded function call data for each target
     * @param descriptionHash Keccak256 hash of the proposal description
     * @return proposalId The unique identifier for the canceled proposal
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        // Verify caller is proposer
        if (_msgSender() != proposalProposer(proposalId)) {
            revert OnlyProposer();
        }

        uint256 result = super.cancel(targets, values, calldatas, descriptionHash);

        // Emit cancellation event with canceler info - SEC-013
        emit ProposalCanceledBy(proposalId, _msgSender());

        return result;
    }

    // ============ View Functions ============

    /**
     * @notice Returns the current governance parameters
     * @return _votingDelay Current voting delay in blocks
     * @return _votingPeriod Current voting period in blocks
     * @return _proposalThreshold Current proposal threshold in tokens
     * @return _quorumNumerator Current quorum percentage
     */
    function getGovernanceParameters()
        external
        view
        returns (
            uint256 _votingDelay,
            uint256 _votingPeriod,
            uint256 _proposalThreshold,
            uint256 _quorumNumerator
        )
    {
        return (
            votingDelay(),
            votingPeriod(),
            proposalThreshold(),
            quorumNumerator()
        );
    }

    /**
     * @notice Checks if an account has sufficient voting power to create proposals
     * @param account Address to check
     * @return True if account can create proposals
     */
    function canPropose(address account) external view returns (bool) {
        return getVotes(account, clock() - 1) >= proposalThreshold();
    }

    /**
     * @notice Returns the current quorum requirement in absolute token terms
     * @return Current quorum threshold in tokens
     */
    function currentQuorum() external view returns (uint256) {
        return quorum(clock() - 1);
    }

    // ============ Required Overrides ============

    /**
     * @notice Returns the voting delay in blocks
     * @dev Required override for Governor + GovernorSettings
     */
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    /**
     * @notice Returns the voting period in blocks
     * @dev Required override for Governor + GovernorSettings
     */
    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    /**
     * @notice Returns the quorum for a specific timepoint
     * @dev Required override for Governor + GovernorVotesQuorumFraction
     * @param blockNumber The block number to query quorum for
     */
    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /**
     * @notice Returns the current state of a proposal
     * @dev Required override for Governor + GovernorTimelockControl
     * @param proposalId The unique identifier for the proposal
     */
    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /**
     * @notice Checks if a proposal needs to be queued before execution
     * @dev Required override for Governor + GovernorTimelockControl
     * @param proposalId The unique identifier for the proposal
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
     * @notice Returns the minimum tokens required to create a proposal
     * @dev Required override for Governor + GovernorSettings
     */
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    // ============ Internal Overrides ============

    /**
     * @notice Queues operations to the timelock
     * @dev Required override for Governor + GovernorTimelockControl
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Executes operations through the timelock
     * @dev Required override for Governor + GovernorTimelockControl
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Cancels operations in the timelock
     * @dev Required override for Governor + GovernorTimelockControl
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Returns the executor address (timelock)
     * @dev Required override for Governor + GovernorTimelockControl
     */
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    /**
     * @notice Internal vote casting with extended event emission
     * @dev Overridden to emit VoteCastWithDetails - SEC-013
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual override returns (uint256) {
        uint256 weight = super._castVote(proposalId, account, support, reason, params);

        // Emit detailed vote event - SEC-013
        emit VoteCastWithDetails(account, proposalId, support, weight, reason);

        return weight;
    }

    // ============ Admin Override Functions (Testnet Only) ============

    /**
     * @notice Admin override to set proposal threshold (testnet only)
     * @dev Allows admin to bypass governance for parameter changes on testnet
     * @param newThreshold New proposal threshold in tokens (with decimals)
     *
     * Requirements:
     * - Contract must be deployed on testnet (isTestnet = true)
     * - Caller must be the admin address
     */
    function setProposalThresholdAdmin(uint256 newThreshold) external {
        if (!isTestnet) revert AdminOverrideNotAllowed();
        if (_msgSender() != admin) revert OnlyAdmin();

        uint256 oldThreshold = proposalThreshold();
        _setProposalThreshold(newThreshold);

        emit ProposalThresholdUpdatedByAdmin(oldThreshold, newThreshold);
    }

    /**
     * @notice Admin override to set voting delay (testnet only)
     * @dev Allows admin to bypass governance for parameter changes on testnet
     * @param newVotingDelay New voting delay in blocks
     *
     * Requirements:
     * - Contract must be deployed on testnet (isTestnet = true)
     * - Caller must be the admin address
     */
    function setVotingDelayAdmin(uint48 newVotingDelay) external {
        if (!isTestnet) revert AdminOverrideNotAllowed();
        if (_msgSender() != admin) revert OnlyAdmin();

        uint256 oldDelay = votingDelay();
        _setVotingDelay(newVotingDelay);

        emit VotingDelayUpdatedByAdmin(oldDelay, newVotingDelay);
    }

    /**
     * @notice Admin override to set voting period (testnet only)
     * @dev Allows admin to bypass governance for parameter changes on testnet
     * @param newVotingPeriod New voting period in blocks
     *
     * Requirements:
     * - Contract must be deployed on testnet (isTestnet = true)
     * - Caller must be the admin address
     */
    function setVotingPeriodAdmin(uint32 newVotingPeriod) external {
        if (!isTestnet) revert AdminOverrideNotAllowed();
        if (_msgSender() != admin) revert OnlyAdmin();

        uint256 oldPeriod = votingPeriod();
        _setVotingPeriod(newVotingPeriod);

        emit VotingPeriodUpdatedByAdmin(oldPeriod, newVotingPeriod);
    }
}
