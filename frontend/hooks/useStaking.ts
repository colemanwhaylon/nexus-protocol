'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import { parseUnits } from 'viem';
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
    name: 'unstake',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'claimRewards',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
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
    name: 'stakedBalance',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'pendingRewards',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'totalStaked',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'rewardRate',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export function useStaking(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const stakingAddress = addresses.nexusStaking as Address;

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data: stakedBalance, refetch: refetchBalance } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'stakedBalance',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: pendingRewards, refetch: refetchRewards } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'pendingRewards',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: totalStaked } = useReadContract({
    address: stakingAddress,
    abi: stakingAbi,
    functionName: 'totalStaked',
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
      functionName: 'unstake',
      args: [amount],
    });
  };

  const claimRewards = () => {
    writeContract({
      address: stakingAddress,
      abi: stakingAbi,
      functionName: 'claimRewards',
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

  return {
    stake,
    unstake,
    claimRewards,
    delegate,
    stakedBalance: stakedBalance as bigint | undefined,
    pendingRewards: pendingRewards as bigint | undefined,
    totalStaked: totalStaked as bigint | undefined,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
    refetch: () => {
      refetchBalance();
      refetchRewards();
    },
  };
}
