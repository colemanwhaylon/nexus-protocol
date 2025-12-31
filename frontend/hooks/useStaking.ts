'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';

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

export function useStaking(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const stakingAddress = addresses.nexusStaking as Address;

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Get stake info (returns tuple: amount, stakedAt, delegatee, delegatedToMe, lastSlashedAt, totalSlashed)
  const { data: stakeInfo, refetch: refetchStakeInfo } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'getStakeInfo',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: totalStaked } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'totalStaked',
  });

  const { data: votingPower, refetch: refetchVotingPower } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'getVotingPower',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
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
    stake,
    unstake,
    delegate,
    stakedBalance,
    currentDelegatee: currentDelegatee as Address | undefined,
    votingPower: votingPower as bigint | undefined,
    totalStaked: totalStaked as bigint | undefined,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
    refetch: () => {
      refetchStakeInfo();
      refetchVotingPower();
    },
  };
}
