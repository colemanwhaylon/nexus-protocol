'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { useNotifications } from './useNotifications';
import { useCallback, useEffect, useState } from 'react';

const nftAbi = [
  {
    name: 'publicMint',
    type: 'function',
    stateMutability: 'payable',
    inputs: [{ name: 'quantity', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'totalSupply',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'MAX_SUPPLY',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'mintPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'tokenOfOwnerByIndex',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'index', type: 'uint256' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'tokenURI',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'string' }],
  },
  {
    name: 'ownerOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'salePhase',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    name: 'safeTransferFrom',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'from', type: 'address' },
      { name: 'to', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'setApprovalForAll',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'operator', type: 'address' },
      { name: 'approved', type: 'bool' },
    ],
    outputs: [],
  },
  {
    name: 'getApproved',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'isApprovedForAll',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'operator', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'revealed',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'reveal',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'isTokenSoulbound',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'bool' }],
  },
] as const;

// Token metadata interface
export interface NFTMetadata {
  name?: string;
  description?: string;
  image?: string;
  attributes?: Array<{
    trait_type: string;
    value: string | number;
  }>;
}

export function useNFT(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;
  const { notifyNFTTransfer, notifyNFTReveal, notifyPending, notifyError, notifySuccess } = useNotifications();

  // Track pending operation for notifications
  const [pendingOperation, setPendingOperation] = useState<{
    type: 'transfer' | 'reveal' | 'approve' | 'approvalForAll';
    tokenId?: string;
    to?: string;
    operator?: string;
    approved?: boolean;
  } | null>(null);

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Handle transaction success notifications
  useEffect(() => {
    if (isSuccess && pendingOperation && hash) {
      switch (pendingOperation.type) {
        case 'transfer':
          if (pendingOperation.tokenId && pendingOperation.to) {
            notifyNFTTransfer(pendingOperation.tokenId, pendingOperation.to, hash, true);
          }
          break;
        case 'reveal':
          if (pendingOperation.tokenId) {
            notifyNFTReveal(pendingOperation.tokenId, true);
          }
          break;
        case 'approve':
          if (pendingOperation.tokenId && pendingOperation.to) {
            notifySuccess(
              'Approval Successful',
              `Approved ${pendingOperation.to.slice(0, 6)}...${pendingOperation.to.slice(-4)} for NFT #${pendingOperation.tokenId}`,
              'nft',
              hash
            );
          }
          break;
        case 'approvalForAll':
          if (pendingOperation.operator) {
            const shortOperator = `${pendingOperation.operator.slice(0, 6)}...${pendingOperation.operator.slice(-4)}`;
            notifySuccess(
              pendingOperation.approved ? 'Operator Approved' : 'Operator Revoked',
              pendingOperation.approved
                ? `Approved ${shortOperator} as operator for all your NFTs`
                : `Revoked ${shortOperator} as operator for all your NFTs`,
              'nft',
              hash
            );
          }
          break;
      }
      setPendingOperation(null);
    }
  }, [isSuccess, pendingOperation, hash, notifyNFTTransfer, notifyNFTReveal, notifySuccess]);

  // Handle transaction errors
  useEffect(() => {
    if (writeError && pendingOperation) {
      switch (pendingOperation.type) {
        case 'transfer':
          if (pendingOperation.tokenId && pendingOperation.to) {
            notifyNFTTransfer(pendingOperation.tokenId, pendingOperation.to, undefined, false);
          }
          break;
        case 'reveal':
          if (pendingOperation.tokenId) {
            notifyNFTReveal(pendingOperation.tokenId, false);
          }
          break;
        case 'approve':
          notifyError('Approval Failed', 'Failed to approve NFT transfer');
          break;
        case 'approvalForAll':
          notifyError('Operator Update Failed', 'Failed to update operator approval');
          break;
      }
      setPendingOperation(null);
    }
  }, [writeError, pendingOperation, notifyNFTTransfer, notifyNFTReveal, notifyError]);

  const { data: totalSupply } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'totalSupply',
  });

  const { data: maxSupply } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'MAX_SUPPLY',
  });

  const { data: mintPrice } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'mintPrice',
  });

  // salePhase: 0 = Closed, 1 = Whitelist, 2 = Public
  const { data: salePhase } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'salePhase',
  });

  // Minting is active when salePhase is Public (2) or Whitelist (1)
  const isMintActive = salePhase !== undefined && (salePhase === 2 || salePhase === 1);

  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: revealed } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'revealed',
  });

  const mint = (quantity: number, value: bigint) => {
    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'publicMint',
      args: [BigInt(quantity)],
      value,
    });
  };

  /**
   * Transfer an NFT to another address
   * @param tokenId - The token ID to transfer
   * @param to - The recipient address
   */
  const transferNFT = useCallback((tokenId: bigint, to: Address) => {
    if (!address) {
      notifyError('Wallet Not Connected', 'Please connect your wallet to transfer NFTs');
      return;
    }

    setPendingOperation({ type: 'transfer', tokenId: tokenId.toString(), to });
    notifyPending('Transfer Pending', `Transferring NFT #${tokenId.toString()}...`);

    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'safeTransferFrom',
      args: [address, to, tokenId],
    });
  }, [address, nftAddress, writeContract, notifyPending, notifyError]);

  /**
   * Reveal NFT metadata (admin only)
   * Note: The reveal function in NexusNFT.sol is a global reveal for all tokens
   * This triggers metadata reveal for the collection
   */
  const revealNFT = useCallback((tokenId?: bigint) => {
    setPendingOperation({ type: 'reveal', tokenId: tokenId?.toString() || 'collection' });
    notifyPending('Reveal Pending', 'Revealing NFT metadata...');

    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'reveal',
      args: [],
    });
  }, [nftAddress, writeContract, notifyPending]);

  /**
   * Approve an address to transfer a specific NFT
   * @param tokenId - The token ID to approve
   * @param to - The address to approve
   */
  const approve = useCallback((tokenId: bigint, to: Address) => {
    setPendingOperation({ type: 'approve', tokenId: tokenId.toString(), to });
    notifyPending('Approval Pending', `Approving transfer for NFT #${tokenId.toString()}...`);

    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'approve',
      args: [to, tokenId],
    });
  }, [nftAddress, writeContract, notifyPending]);

  /**
   * Set approval for all NFTs to an operator
   * @param operator - The operator address
   * @param approved - Whether to approve or revoke
   */
  const setApprovalForAll = useCallback((operator: Address, approved: boolean) => {
    setPendingOperation({ type: 'approvalForAll', operator, approved });
    const action = approved ? 'Approving' : 'Revoking';
    notifyPending('Operator Update Pending', `${action} operator for all NFTs...`);

    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'setApprovalForAll',
      args: [operator, approved],
    });
  }, [nftAddress, writeContract, notifyPending]);

  return {
    // Existing methods
    mint,
    totalSupply: totalSupply as bigint | undefined,
    maxSupply: maxSupply as bigint | undefined,
    mintPrice: mintPrice as bigint | undefined,
    isMintActive,
    salePhase: salePhase as number | undefined,
    balance: balance as bigint | undefined,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
    refetchBalance,

    // New write methods
    transferNFT,
    revealNFT,
    approve,
    setApprovalForAll,

    // New read state
    revealed: revealed as boolean | undefined,

    // Contract address for standalone hooks
    nftAddress,
  };
}

/**
 * Fetch token metadata from tokenURI
 * This is a standalone async function that can be used outside React components
 * @param tokenURI - The token URI to fetch metadata from
 * @returns Promise<NFTMetadata | null>
 */
export async function fetchTokenMetadata(tokenURI: string): Promise<NFTMetadata | null> {
  try {
    // Handle IPFS URIs
    let fetchURL = tokenURI;
    if (tokenURI.startsWith('ipfs://')) {
      fetchURL = tokenURI.replace('ipfs://', 'https://ipfs.io/ipfs/');
    }

    const response = await fetch(fetchURL);
    if (!response.ok) {
      throw new Error(`Failed to fetch metadata: ${response.statusText}`);
    }

    const metadata = await response.json();
    return metadata as NFTMetadata;
  } catch (error) {
    console.error('Failed to fetch token metadata:', error);
    return null;
  }
}

/**
 * Hook to get token metadata for a specific token
 * @param chainId - Optional chain ID
 * @param tokenId - The token ID to fetch metadata for
 */
export function useTokenMetadata(chainId?: number, tokenId?: bigint) {
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;
  const [metadata, setMetadata] = useState<NFTMetadata | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const { data: tokenURI, isLoading: isLoadingURI } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'tokenURI',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: { enabled: tokenId !== undefined },
  });

  useEffect(() => {
    if (!tokenURI || typeof tokenURI !== 'string') {
      setMetadata(null);
      return;
    }

    setIsLoading(true);
    setError(null);

    fetchTokenMetadata(tokenURI)
      .then((data) => {
        setMetadata(data);
      })
      .catch((err) => {
        setError(err instanceof Error ? err : new Error('Unknown error'));
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, [tokenURI]);

  return {
    metadata,
    tokenURI: tokenURI as string | undefined,
    isLoading: isLoading || isLoadingURI,
    error,
  };
}

/**
 * Hook to check if an operator is approved for all NFTs
 * @param chainId - Optional chain ID
 * @param owner - The owner address
 * @param operator - The operator address to check
 */
export function useIsApprovedForAll(chainId?: number, owner?: Address, operator?: Address) {
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;

  const { data, isLoading, refetch } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'isApprovedForAll',
    args: owner && operator ? [owner, operator] : undefined,
    query: { enabled: !!owner && !!operator },
  });

  return {
    isApproved: data as boolean | undefined,
    isLoading,
    refetch,
  };
}

/**
 * Hook to get the approved address for a specific token
 * @param chainId - Optional chain ID
 * @param tokenId - The token ID to check
 */
export function useGetApproved(chainId?: number, tokenId?: bigint) {
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;

  const { data, isLoading, refetch } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'getApproved',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: { enabled: tokenId !== undefined },
  });

  return {
    approvedAddress: data as Address | undefined,
    isLoading,
    refetch,
  };
}

/**
 * Hook to check if a token is soulbound (non-transferable)
 * @param chainId - Optional chain ID
 * @param tokenId - The token ID to check
 */
export function useIsTokenSoulbound(chainId?: number, tokenId?: bigint) {
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;

  const { data, isLoading, refetch } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'isTokenSoulbound',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: { enabled: tokenId !== undefined },
  });

  return {
    isSoulbound: data as boolean | undefined,
    isLoading,
    refetch,
  };
}

/**
 * Hook to get the owner of a specific token
 * @param chainId - Optional chain ID
 * @param tokenId - The token ID to check
 */
export function useOwnerOf(chainId?: number, tokenId?: bigint) {
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;

  const { data, isLoading, refetch } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'ownerOf',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: { enabled: tokenId !== undefined },
  });

  return {
    owner: data as Address | undefined,
    isLoading,
    refetch,
  };
}

/**
 * Hook to get the token URI for a specific token
 * @param chainId - Optional chain ID
 * @param tokenId - The token ID
 */
export function useTokenURI(chainId?: number, tokenId?: bigint) {
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;

  const { data, isLoading, refetch } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'tokenURI',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: { enabled: tokenId !== undefined },
  });

  return {
    tokenURI: data as string | undefined,
    isLoading,
    refetch,
  };
}
