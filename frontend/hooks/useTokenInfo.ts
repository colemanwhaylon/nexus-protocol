'use client';

import { useReadContracts } from 'wagmi';
import { erc20Abi } from 'viem';
import type { Address } from 'viem';

interface UseTokenInfoOptions {
  tokenAddress?: Address;
  enabled?: boolean;
}

export function useTokenInfo({
  tokenAddress,
  enabled = true,
}: UseTokenInfoOptions = {}) {
  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      {
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'name',
      },
      {
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'symbol',
      },
      {
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'decimals',
      },
      {
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'totalSupply',
      },
    ],
    query: {
      enabled: enabled && !!tokenAddress,
    },
  });

  const name = data?.[0]?.result as string | undefined;
  const symbol = data?.[1]?.result as string | undefined;
  const decimals = data?.[2]?.result as number | undefined;
  const totalSupply = data?.[3]?.result as bigint | undefined;

  return {
    name,
    symbol,
    decimals,
    totalSupply,
    isLoading,
    error,
    refetch,
  };
}
