'use client';

import { useEffect } from 'react';
import { toast } from 'sonner';
import type { Hash } from 'viem';

interface UseTransactionToastOptions {
  hash?: Hash;
  isPending?: boolean;
  isConfirming?: boolean;
  isSuccess?: boolean;
  error?: Error | null;
  pendingMessage?: string;
  confirmingMessage?: string;
  successMessage?: string;
  errorMessage?: string;
  chainId?: number;
}

const getExplorerUrl = (hash: Hash, chainId?: number): string | null => {
  switch (chainId) {
    case 1:
      return `https://etherscan.io/tx/${hash}`;
    case 11155111:
      return `https://sepolia.etherscan.io/tx/${hash}`;
    default:
      return null;
  }
};

export function useTransactionToast({
  hash,
  isPending,
  isConfirming,
  isSuccess,
  error,
  pendingMessage = 'Waiting for wallet confirmation...',
  confirmingMessage = 'Transaction submitted. Waiting for confirmation...',
  successMessage = 'Transaction confirmed!',
  errorMessage = 'Transaction failed',
  chainId,
}: UseTransactionToastOptions) {
  // Show pending toast when waiting for wallet
  useEffect(() => {
    if (isPending) {
      toast.loading(pendingMessage, { id: 'tx-pending' });
    } else {
      toast.dismiss('tx-pending');
    }
  }, [isPending, pendingMessage]);

  // Show confirming toast when tx is submitted
  useEffect(() => {
    if (isConfirming && hash) {
      const explorerUrl = getExplorerUrl(hash, chainId);
      toast.loading(confirmingMessage, {
        id: 'tx-confirming',
        description: explorerUrl || `Hash: ${hash.slice(0, 10)}...`,
      });
    }
  }, [isConfirming, hash, confirmingMessage, chainId]);

  // Show success toast when confirmed
  useEffect(() => {
    if (isSuccess && hash) {
      toast.dismiss('tx-confirming');
      const explorerUrl = getExplorerUrl(hash, chainId);
      toast.success(successMessage, {
        id: 'tx-success',
        description: explorerUrl || undefined,
      });
    }
  }, [isSuccess, hash, successMessage, chainId]);

  // Show error toast on failure
  useEffect(() => {
    if (error) {
      toast.dismiss('tx-pending');
      toast.dismiss('tx-confirming');
      toast.error(errorMessage, {
        id: 'tx-error',
        description: error.message.slice(0, 100),
      });
    }
  }, [error, errorMessage]);
}

// Utility functions for manual toasts
export const txToast = {
  pending: (message: string) => toast.loading(message, { id: 'tx-manual' }),
  success: (message: string, hash?: Hash, chainId?: number) => {
    toast.dismiss('tx-manual');
    const explorerUrl = hash ? getExplorerUrl(hash, chainId) : null;
    toast.success(message, {
      description: explorerUrl || undefined,
    });
  },
  error: (message: string, error?: Error) => {
    toast.dismiss('tx-manual');
    toast.error(message, {
      description: error?.message.slice(0, 100),
    });
  },
};
