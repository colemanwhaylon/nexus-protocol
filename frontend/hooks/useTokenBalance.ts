'use client';

import { useReadContract, useAccount } from 'wagmi';
import { erc20Abi } from 'viem';
import type { Address } from 'viem';

interface UseTokenBalanceOptions {
  tokenAddress?: Address;
  address?: Address;
  enabled?: boolean;
}

export function useTokenBalance({
  tokenAddress,
  address,
  enabled = true,
}: UseTokenBalanceOptions = {}) {
  const { address: connectedAddress } = useAccount();
  const targetAddress = address || connectedAddress;

  const { data: balance, isLoading, error, refetch } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: targetAddress ? [targetAddress] : undefined,
    query: {
      enabled: enabled && !!tokenAddress && !!targetAddress,
    },
  });

  return {
    balance: balance as bigint | undefined,
    isLoading,
    error,
    refetch,
  };
}
