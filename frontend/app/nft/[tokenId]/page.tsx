'use client';

import { useParams, useRouter } from 'next/navigation';
import { useChainId, useReadContract } from 'wagmi';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { NFTDetail } from '@/components/features/NFT';

const nftAbi = [
  {
    name: 'ownerOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
] as const;

export default function NFTDetailPage() {
  const params = useParams();
  const router = useRouter();
  const tokenId = params.tokenId as string;
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as `0x${string}`;

  const { data: owner, isLoading: isLoadingOwner } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'ownerOf',
    args: [BigInt(tokenId)],
  });

  const handleBack = () => {
    router.push('/nft/gallery');
  };

  const handleTransfer = () => {
    // TODO: Implement transfer modal
    console.log('Transfer NFT', tokenId);
  };

  // Mock attributes for demo
  const attributes = [
    { trait_type: 'Tier', value: 'Genesis', rarity: 2.5 },
    { trait_type: 'Power', value: 85, rarity: 12 },
    { trait_type: 'Element', value: 'Cosmic', rarity: 5 },
    { trait_type: 'Rarity', value: 'Epic', rarity: 4.2 },
    { trait_type: 'Staking Boost', value: '10%', rarity: 25 },
    { trait_type: 'Governance Weight', value: '1.5x', rarity: 15 },
  ];

  return (
    <div className="container mx-auto px-4 py-8">
      <NFTDetail
        tokenId={tokenId}
        name={`Nexus NFT #${tokenId}`}
        description="A Nexus Genesis NFT providing exclusive benefits including staking boosts, enhanced governance voting power, and access to exclusive platform features."
        owner={owner}
        contractAddress={nftAddress}
        attributes={attributes}
        chainId={chainId}
        onBack={handleBack}
        onTransfer={handleTransfer}
        isLoading={isLoadingOwner}
      />
    </div>
  );
}
