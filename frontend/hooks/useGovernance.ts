'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';

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
] as const;

type HexString = ;

export function useGovernance(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const governorAddress = addresses.nexusGovernor as Address;

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data: proposalThreshold } = useReadContract({
    address: governorAddress,
    abi: governorAbi,
    functionName: 'proposalThreshold',
  });

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

  const castVote = (proposalId: bigint, support: number) => {
    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'castVote',
      args: [proposalId, support],
    });
  };

  const castVoteWithReason = (proposalId: bigint, support: number, reason: string) => {
    writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'castVoteWithReason',
      args: [proposalId, support, reason],
    });
  };

  return {
    propose,
    castVote,
    castVoteWithReason,
    proposalThreshold: proposalThreshold as bigint | undefined,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
  };
}
