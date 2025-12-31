'use client';

import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { erc20Abi } from 'viem';
import type { Address } from 'viem';

interface UseTokenTransferOptions {
  tokenAddress?: Address;
}

export function useTokenTransfer({ tokenAddress }: UseTokenTransferOptions = {}) {
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

  const transfer = async (to: Address, amount: bigint) => {
    if (!tokenAddress) throw new Error('Token address not set');

    writeContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'transfer',
      args: [to, amount],
    });
  };

  return {
    transfer,
    hash,
    isWritePending,
    isConfirming,
    isConfirmed,
    isPending: isWritePending || isConfirming,
    error: writeError || confirmError,
    reset,
  };
}
