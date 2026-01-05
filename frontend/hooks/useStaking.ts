'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { useContractAddresses } from '@/hooks/useContractAddresses';

const stakingAbi = [
  {
    name: 'stake',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'initiateUnbonding',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'delegate',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'delegatee', type: 'address' }],
    outputs: [],
  },
  {
    name: 'getStakeInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'staker', type: 'address' }],
    outputs: [
      { name: 'amount', type: 'uint256' },
      { name: 'stakedAt', type: 'uint256' },
      { name: 'delegatee', type: 'address' },
      { name: 'delegatedToMe', type: 'uint256' },
      { name: 'lastSlashedAt', type: 'uint256' },
      { name: 'totalSlashed', type: 'uint256' },
    ],
  },
  {
    name: 'totalStaked',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getVotingPower',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export function useStaking() {
  const { address } = useAccount();
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const stakingAddress = addresses.nexusStaking as Address;
  const isReady = hasContract('nexusStaking');

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Get stake info (returns tuple: amount, stakedAt, delegatee, delegatedToMe, lastSlashedAt, totalSlashed)
  const { data: stakeInfo, refetch: refetchStakeInfo } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'getStakeInfo',
    args: address ? [address] : undefined,
    query: {
      enabled: isReady && !!address,
      staleTime: 0, // Always refetch
      gcTime: 0, // Don't cache
    },
  });

  const { data: totalStaked, refetch: refetchTotalStaked } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'totalStaked',
    query: {
      enabled: isReady,
      staleTime: 0,
      gcTime: 0,
    },
  });

  const { data: votingPower, refetch: refetchVotingPower } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'getVotingPower',
    args: address ? [address] : undefined,
    query: {
      enabled: isReady && !!address,
      staleTime: 0,
      gcTime: 0,
    },
  });

  const stake = (amount: bigint) => {
    writeContract({
      address: stakingAddress,
      abi: stakingAbi,
      functionName: 'stake',
      args: [amount],
    });
  };

  const unstake = (amount: bigint) => {
    writeContract({
      address: stakingAddress,
      abi: stakingAbi,
      functionName: 'initiateUnbonding',
      args: [amount],
    });
  };

  const delegate = (delegatee: Address) => {
    writeContract({
      address: stakingAddress,
      abi: stakingAbi,
      functionName: 'delegate',
      args: [delegatee],
    });
  };

  // Extract staked amount from tuple
  const stakedBalance = stakeInfo ? (stakeInfo as readonly [bigint, bigint, string, bigint, bigint, bigint])[0] : undefined;
  const currentDelegatee = stakeInfo ? (stakeInfo as readonly [bigint, bigint, string, bigint, bigint, bigint])[2] : undefined;

  return {
    // Loading state from contract addresses
    isAddressesLoading: addressesLoading,
    isReady,
    // Actions
    stake,
    unstake,
    delegate,
    // Data
    stakedBalance,
    currentDelegatee: currentDelegatee as Address | undefined,
    votingPower: votingPower as bigint | undefined,
    totalStaked: totalStaked as bigint | undefined,
    // Transaction state
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
    refetch: async () => {
      await Promise.all([
        refetchStakeInfo(),
        refetchVotingPower(),
        refetchTotalStaked(),
      ]);
    },
  };
}
