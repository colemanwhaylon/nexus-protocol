'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useAccount, useChainId, useReadContract } from 'wagmi';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { useNFT } from '@/hooks/useNFT';
import { NFTGrid, NFTCard } from '@/components/features/NFT';
import { Loader2, ExternalLink, Image as ImageIcon } from 'lucide-react';

const nftAbi = [
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
] as const;

interface NFTData {
  tokenId: string;
  name?: string;
  image?: string;
}

export default function GalleryPage() {
  const router = useRouter();
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as `0x${string}`;

  const { balance, totalSupply, maxSupply } = useNFT(chainId);
  const [ownedNFTs, setOwnedNFTs] = useState<NFTData[]>([]);
  const [isLoadingTokens, setIsLoadingTokens] = useState(false);
  const [favoriteTokenIds, setFavoriteTokenIds] = useState<string[]>([]);

  // Handle NFT selection (navigate to detail page)
  const handleSelectNFT = (tokenId: string) => {
    router.push(`/nft/${tokenId}`);
  };

  // Handle favorite toggle
  const handleFavorite = (tokenId: string) => {
    setFavoriteTokenIds(prev => 
      prev.includes(tokenId)
        ? prev.filter(id => id !== tokenId)
        : [...prev, tokenId]
    );
  };

  // Set loading state based on balance
  useEffect(() => {
    if (address && balance !== undefined) {
      setIsLoadingTokens(false);
    }
  }, [address, balance]);

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">NFT Gallery</h1>
        <p className="text-muted-foreground">
          Browse the Nexus NFT collection
        </p>
      </div>

      {/* Collection Stats */}
      <div className="grid gap-4 md:grid-cols-3 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Supply</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">
              {totalSupply?.toString() || '0'} / {maxSupply?.toString() || '10,000'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Your NFTs</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{balance?.toString() || '0'}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Collection</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">Nexus Genesis</p>
          </CardContent>
        </Card>
      </div>

      {/* Your Collection */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            Your Collection
            <Badge variant="outline">{balance?.toString() || '0'} NFTs</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {!isConnected ? (
            <div className="text-center py-12">
              <p className="text-muted-foreground mb-4">
                Connect your wallet to view your NFTs.
              </p>
            </div>
          ) : isLoadingTokens ? (
            <NFTGrid isLoading={true} columns={4} />
          ) : !balance || balance === 0n ? (
            <div className="text-center py-12">
              <ImageIcon className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
              <p className="text-muted-foreground mb-4">
                You don&apos;t own any Nexus NFTs yet.
              </p>
              <Link href="/nft/mint">
                <Button>
                  Mint Your First NFT
                  <ExternalLink className="ml-2 h-4 w-4" />
                </Button>
              </Link>
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
              {Array.from({ length: Number(balance) }, (_, i) => (
                <NFTTokenCard
                  key={i}
                  ownerAddress={address!}
                  index={BigInt(i)}
                  nftAddress={nftAddress}
                  onSelect={handleSelectNFT}
                  onFavorite={handleFavorite}
                  isFavorite={favoriteTokenIds}
                />
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

// Separate component to fetch individual token ID and use NFTCard
function NFTTokenCard({
  ownerAddress,
  index,
  nftAddress,
  onSelect,
  onFavorite,
  isFavorite,
}: {
  ownerAddress: `0x${string}`;
  index: bigint;
  nftAddress: `0x${string}`;
  onSelect: (tokenId: string) => void;
  onFavorite: (tokenId: string) => void;
  isFavorite: string[];
}) {
  const { data: tokenId, isLoading } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'tokenOfOwnerByIndex',
    args: [ownerAddress, index],
  });

  if (isLoading) {
    return <NFTCard tokenId="" isLoading={true} />;
  }

  if (!tokenId) return null;

  const tokenIdStr = tokenId.toString();

  return (
    <NFTCard
      tokenId={tokenIdStr}
      name={`Nexus NFT #${tokenIdStr}`}
      isOwned={true}
      isFavorite={isFavorite.includes(tokenIdStr)}
      onClick={() => onSelect(tokenIdStr)}
      onFavorite={() => onFavorite(tokenIdStr)}
    />
  );
}
