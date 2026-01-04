'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { keccak256, toBytes } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { useNotifications } from '@/hooks/useNotifications';

/**
 * Proposal state enum matching OpenZeppelin Governor.ProposalState
 */
export enum ProposalState {
  Pending = 0,
  Active = 1,
  Canceled = 2,
  Defeated = 3,
  Succeeded = 4,
  Queued = 5,
  Expired = 6,
  Executed = 7,
}

/**
 * Vote support values
 */
export enum VoteSupport {
  Against = 0,
  For = 1,
  Abstain = 2,
}

const governorAbi = [
  {
    name: 'propose',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'description', type: 'string' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'castVote',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'castVoteWithReason',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
      { name: 'reason', type: 'string' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'queue',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'execute',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'cancel',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'state',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [{ type: 'uint8' }],
  },
  {
    name: 'proposalVotes',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [
      { name: 'againstVotes', type: 'uint256' },
      { name: 'forVotes', type: 'uint256' },
      { name: 'abstainVotes', type: 'uint256' },
    ],
  },
  {
    name: 'hasVoted',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'proposalThreshold',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getVotes',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'timepoint', type: 'uint256' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'quorum',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'blockNumber', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'votingDelay',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'votingPeriod',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'proposalSnapshot',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'proposalDeadline',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

type HexString = `0x${string}`;

/**
 * Parameters for creating a proposal
 */
export interface CreateProposalParams {
  title: string;
  description: string;
  targets: Address[];
  values: bigint[];
  calldatas: HexString[];
}

/**
 * Parameters for queue/execute/cancel operations that need full proposal data
 */
export interface ProposalOperationParams {
  targets: Address[];
  values: bigint[];
  calldatas: HexString[];
  description: string;
}

/**
 * Helper function to get proposal state as human-readable string
 */
export function getProposalStateLabel(state: ProposalState): string {
  const labels: Record<ProposalState, string> = {
    [ProposalState.Pending]: 'Pending',
    [ProposalState.Active]: 'Active',
    [ProposalState.Canceled]: 'Canceled',
    [ProposalState.Defeated]: 'Defeated',
    [ProposalState.Succeeded]: 'Succeeded',
    [ProposalState.Queued]: 'Queued',
    [ProposalState.Expired]: 'Expired',
    [ProposalState.Executed]: 'Executed',
  };
  return labels[state] || 'Unknown';
}

/**
 * Helper function to get vote support as human-readable string
 */
export function getVoteSupportLabel(support: VoteSupport): 'for' | 'against' | 'abstain' {
  const labels: Record<VoteSupport, 'for' | 'against' | 'abstain'> = {
    [VoteSupport.Against]: 'against',
    [VoteSupport.For]: 'for',
    [VoteSupport.Abstain]: 'abstain',
  };
  return labels[support] || 'abstain';
}

/**
 * Hook for interacting with the NexusGovernor contract
 * @param chainId - Optional chain ID to use specific contract addresses
 */
export function useGovernance(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const governorAddress = addresses.nexusGovernor as Address;
  const { notifyProposalCreated, notifyVoteCast, notifySuccess, notifyError } = useNotifications();

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ============ Read Functions ============

  const { data: proposalThreshold } = useReadContract({
    address: governorAddress,
    abi: governorAbi,
    functionName: 'proposalThreshold',
  });

  const { data: votingDelay } = useReadContract({
    address: governorAddress,
    abi: governorAbi,
    functionName: 'votingDelay',
  });

  const { data: votingPeriod } = useReadContract({
    address: governorAddress,
    abi: governorAbi,
    functionName: 'votingPeriod',
  });

  // ============ Write Functions ============

  /**
   * Create a new proposal with title and description
   * @param params - Proposal parameters including title, description, targets, values, calldatas
   */
  const createProposal = (params: CreateProposalParams) => {
    const { title, description, targets, values, calldatas } = params;
    // Format description with title for better display
    const fullDescription = `# ${title}\n\n${description}`;

    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, fullDescription],
    });
  };

  /**
   * Submit a proposal (low-level function)
   * @deprecated Use createProposal for a friendlier API
   */
  const propose = (
    targets: Address[],
    values: bigint[],
    calldatas: HexString[],
    description: string
  ) => {
    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
    });
  };

  /**
   * Cast a vote on a proposal
   * @param proposalId - The ID of the proposal to vote on
   * @param support - Vote type: 0=Against, 1=For, 2=Abstain (use VoteSupport enum)
   */
  const castVote = (proposalId: bigint, support: VoteSupport | number) => {
    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'castVote',
      args: [proposalId, support],
    });
  };

  /**
   * Cast a vote on a proposal with a reason
   * @param proposalId - The ID of the proposal to vote on
   * @param support - Vote type: 0=Against, 1=For, 2=Abstain (use VoteSupport enum)
   * @param reason - The reason for the vote
   */
  const castVoteWithReason = (proposalId: bigint, support: VoteSupport | number, reason: string) => {
    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'castVoteWithReason',
      args: [proposalId, support, reason],
    });
  };

  /**
   * Queue a succeeded proposal for execution
   * @param params - Proposal operation parameters
   */
  const queue = (params: ProposalOperationParams) => {
    const { targets, values, calldatas, description } = params;
    const descriptionHash = keccak256(toBytes(description));

    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'queue',
      args: [targets, values, calldatas, descriptionHash],
    });
  };

  /**
   * Execute a queued proposal
   * @param params - Proposal operation parameters
   */
  const execute = (params: ProposalOperationParams) => {
    const { targets, values, calldatas, description } = params;
    const descriptionHash = keccak256(toBytes(description));

    // Calculate total ETH value needed for execution
    const totalValue = values.reduce((sum, val) => sum + val, BigInt(0));

    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'execute',
      args: [targets, values, calldatas, descriptionHash],
      value: totalValue,
    });
  };

  /**
   * Cancel a proposal
   * @param params - Proposal operation parameters
   */
  const cancel = (params: ProposalOperationParams) => {
    const { targets, values, calldatas, description } = params;
    const descriptionHash = keccak256(toBytes(description));

    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'cancel',
      args: [targets, values, calldatas, descriptionHash],
    });
  };

  // ============ Query Hooks for Specific Proposals ============

  /**
   * Hook to get the state of a specific proposal
   * @param proposalId - The proposal ID to check
   */
  const useProposalState = (proposalId: bigint | undefined) => {
    const { data, refetch, isLoading } = useReadContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'state',
      args: proposalId !== undefined ? [proposalId] : undefined,
      query: { enabled: proposalId !== undefined },
    });

    return {
      state: data as ProposalState | undefined,
      stateLabel: data !== undefined ? getProposalStateLabel(data as ProposalState) : undefined,
      refetch,
      isLoading,
    };
  };

  /**
   * Hook to get votes for a specific proposal
   * @param proposalId - The proposal ID to check
   */
  const useProposalVotes = (proposalId: bigint | undefined) => {
    const { data, refetch, isLoading } = useReadContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'proposalVotes',
      args: proposalId !== undefined ? [proposalId] : undefined,
      query: { enabled: proposalId !== undefined },
    });

    const votes = data as readonly [bigint, bigint, bigint] | undefined;

    return {
      againstVotes: votes?.[0],
      forVotes: votes?.[1],
      abstainVotes: votes?.[2],
      refetch,
      isLoading,
    };
  };

  /**
   * Hook to check if an account has voted on a proposal
   * @param proposalId - The proposal ID to check
   * @param account - The account address to check (defaults to connected wallet)
   */
  const useHasVoted = (proposalId: bigint | undefined, account?: Address) => {
    const targetAccount = account || address;

    const { data, refetch, isLoading } = useReadContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'hasVoted',
      args: proposalId !== undefined && targetAccount ? [proposalId, targetAccount] : undefined,
      query: { enabled: proposalId !== undefined && !!targetAccount },
    });

    return {
      hasVoted: data as boolean | undefined,
      refetch,
      isLoading,
    };
  };

  /**
   * Hook to get voting power for an account at a specific timepoint
   * @param account - The account address to check (defaults to connected wallet)
   * @param timepoint - The block number to check voting power at
   */
  const useVotingPower = (account?: Address, timepoint?: bigint) => {
    const targetAccount = account || address;

    const { data, refetch, isLoading } = useReadContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'getVotes',
      args: targetAccount && timepoint !== undefined ? [targetAccount, timepoint] : undefined,
      query: { enabled: !!targetAccount && timepoint !== undefined },
    });

    return {
      votingPower: data as bigint | undefined,
      refetch,
      isLoading,
    };
  };

  /**
   * Hook to get proposal snapshot and deadline
   * @param proposalId - The proposal ID to check
   */
  const useProposalTimeline = (proposalId: bigint | undefined) => {
    const { data: snapshot } = useReadContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'proposalSnapshot',
      args: proposalId !== undefined ? [proposalId] : undefined,
      query: { enabled: proposalId !== undefined },
    });

    const { data: deadline } = useReadContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'proposalDeadline',
      args: proposalId !== undefined ? [proposalId] : undefined,
      query: { enabled: proposalId !== undefined },
    });

    return {
      snapshot: snapshot as bigint | undefined,
      deadline: deadline as bigint | undefined,
    };
  };

  // ============ Convenience Functions with Notifications ============

  /**
   * Create a proposal with automatic notification
   */
  const createProposalWithNotification = (params: CreateProposalParams) => {
    createProposal(params);
    // Note: Success notification should be triggered after transaction confirmation
    // This would typically be handled by watching isSuccess in the component
  };

  /**
   * Cast a vote with automatic notification
   */
  const castVoteWithNotification = (proposalId: bigint, support: VoteSupport | number) => {
    castVote(proposalId, support);
    // Note: Success notification should be triggered after transaction confirmation
  };

  // ============ Return Values ============

  return {
    // Write functions
    createProposal,
    propose,
    castVote,
    castVoteWithReason,
    queue,
    execute,
    cancel,

    // Convenience write functions with notifications
    createProposalWithNotification,
    castVoteWithNotification,

    // Query hooks (must be called at component level)
    useProposalState,
    useProposalVotes,
    useHasVoted,
    useVotingPower,
    useProposalTimeline,

    // Static read data
    proposalThreshold: proposalThreshold as bigint | undefined,
    votingDelay: votingDelay as bigint | undefined,
    votingPeriod: votingPeriod as bigint | undefined,

    // Transaction state
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,

    // Helper functions and enums
    getProposalStateLabel,
    getVoteSupportLabel,
    ProposalState,
    VoteSupport,

    // Notification helpers
    notifyProposalCreated,
    notifyVoteCast,
    notifySuccess,
    notifyError,
  };
}
