'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { erc20Abi } from 'viem';
import type { Address } from 'viem';

interface UseTokenApprovalOptions {
  tokenAddress?: Address;
  spender?: Address;
}

export function useTokenApproval({
  tokenAddress,
  spender,
}: UseTokenApprovalOptions = {}) {
  const { address } = useAccount();

  const { data: allowance, isLoading: isLoadingAllowance, refetch } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && spender ? [address, spender] : undefined,
    query: {
      enabled: !!tokenAddress && !!address && !!spender,
    },
  });

  const {
    writeContract,
    data: hash,
    isPending: isWritePending,
    error: writeError,
    reset,
  } = useWriteContract();

  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash,
  });

  const approve = async (approveSpender: Address, amount: bigint) => {
    if (!tokenAddress) throw new Error('Token address not set');

    writeContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'approve',
      args: [approveSpender, amount],
    });
  };

  return {
    allowance: allowance as bigint | undefined,
    isLoadingAllowance,
    approve,
    hash,
    isWritePending,
    isConfirming,
    isConfirmed,
    isPending: isWritePending || isConfirming,
    error: writeError || confirmError,
    reset,
    refetch,
  };
}
