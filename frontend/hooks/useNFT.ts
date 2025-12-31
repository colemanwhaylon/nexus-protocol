'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';

const nftAbi = [
  {
    name: 'mint',
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
    name: 'maxSupply',
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
    name: 'isMintActive',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
] as const;

export function useNFT(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as Address;

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data: totalSupply } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'totalSupply',
  });

  const { data: maxSupply } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'maxSupply',
  });

  const { data: mintPrice } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'mintPrice',
  });

  const { data: isMintActive } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'isMintActive',
  });

  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const mint = (quantity: number, value: bigint) => {
    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'mint',
      args: [BigInt(quantity)],
      value,
    });
  };

  return {
    mint,
    totalSupply: totalSupply as bigint | undefined,
    maxSupply: maxSupply as bigint | undefined,
    mintPrice: mintPrice as bigint | undefined,
    isMintActive: isMintActive as boolean | undefined,
    balance: balance as bigint | undefined,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
    refetchBalance,
  };
}
