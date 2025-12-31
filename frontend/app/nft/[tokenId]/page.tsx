'use client';

import { useParams } from 'next/navigation';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useChainId, useReadContract } from 'wagmi';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { ArrowLeft, User, Hash, Sparkles } from 'lucide-react';

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

  const truncateAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Back Button */}
      <Link href="/nft/gallery" className="inline-flex items-center text-muted-foreground hover:text-foreground mb-6">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back to Gallery
      </Link>

      <div className="grid gap-8 md:grid-cols-2">
        {/* NFT Image */}
        <Card>
          <CardContent className="p-6">
            <div className="aspect-square bg-gradient-to-br from-blue-500 via-purple-500 to-pink-500 rounded-xl flex items-center justify-center">
              <div className="text-center text-white">
                <Sparkles className="h-16 w-16 mx-auto mb-4 opacity-50" />
                <p className="text-2xl font-bold">Nexus NFT</p>
                <p className="text-lg opacity-75">#{tokenId}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* NFT Details */}
        <div className="space-y-6">
          <div>
            <h1 className="text-3xl font-bold mb-2">Nexus NFT #{tokenId}</h1>
            <p className="text-muted-foreground">Genesis Collection</p>
          </div>

          {/* Owner Info */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm font-medium flex items-center gap-2">
                <User className="h-4 w-4" />
                Owner
              </CardTitle>
            </CardHeader>
            <CardContent>
              {isLoadingOwner ? (
                <p className="text-muted-foreground">Loading...</p>
              ) : owner ? (
                <p className="font-mono text-sm">{truncateAddress(owner)}</p>
              ) : (
                <p className="text-muted-foreground">Unknown</p>
              )}
            </CardContent>
          </Card>

          {/* Token Details */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm font-medium flex items-center gap-2">
                <Hash className="h-4 w-4" />
                Token Details
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Token ID</span>
                <span className="font-medium">#{tokenId}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Contract</span>
                <span className="font-mono text-sm">{truncateAddress(nftAddress)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Standard</span>
                <span className="font-medium">ERC-721</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Chain</span>
                <Badge variant="outline">Anvil (Local)</Badge>
              </div>
            </CardContent>
          </Card>

          {/* Benefits */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm font-medium flex items-center gap-2">
                <Sparkles className="h-4 w-4" />
                NFT Benefits
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2 text-sm">
                <li className="flex items-center gap-2">
                  <Badge variant="secondary" className="h-2 w-2 p-0 rounded-full" />
                  10% boost to staking rewards
                </li>
                <li className="flex items-center gap-2">
                  <Badge variant="secondary" className="h-2 w-2 p-0 rounded-full" />
                  1.5x governance voting power
                </li>
                <li className="flex items-center gap-2">
                  <Badge variant="secondary" className="h-2 w-2 p-0 rounded-full" />
                  Access to exclusive features
                </li>
                <li className="flex items-center gap-2">
                  <Badge variant="secondary" className="h-2 w-2 p-0 rounded-full" />
                  Community events and airdrops
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
