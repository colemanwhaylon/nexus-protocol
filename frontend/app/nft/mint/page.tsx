'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import { useNFT } from '@/hooks/useNFT';
import { MintCard } from '@/components/features/NFT/MintCard';
import { useNotifications } from '@/hooks/useNotifications';

export default function MintPage() {
  const router = useRouter();
  const { isConnected } = useAccount();
  const [mintQuantity, setMintQuantity] = useState(1);
  const processedHashRef = useRef<string | null>(null);

  const { notifyMint } = useNotifications();

  const {
    mint,
    totalSupply,
    maxSupply,
    mintPrice,
    isMintActive,
    isPending,
    isConfirming,
    isSuccess,
    hash,
    refetchBalance,
  } = useNFT();

  // Refetch after successful mint, send notification, and navigate to gallery
  useEffect(() => {
    if (isSuccess && hash && hash !== processedHashRef.current) {
      processedHashRef.current = hash;
      refetchBalance();
      // Notification with quantity info
      notifyMint(`${mintQuantity}`, hash);
      // Navigate to gallery after a brief delay to show success state
      setTimeout(() => {
        router.push('/nft/gallery');
      }, 1500);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, hash, refetchBalance, router]);

  const handleMint = async (quantity: number) => {
    // mintPrice can be 0n for free mints, so check for undefined specifically
    if (mintPrice === undefined) return;
    setMintQuantity(quantity);
    const totalCost = mintPrice * BigInt(quantity);
    mint(quantity, totalCost);
  };

  const isLoading = isPending || isConfirming;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Mint Nexus NFT</h1>
        <p className="text-muted-foreground">
          Mint your exclusive Nexus NFT to unlock protocol benefits
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Mint Card */}
        {!isConnected ? (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                Mint Status
                <Badge variant="outline">Connect Wallet</Badge>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-muted-foreground">
                Connect your wallet to mint NFTs.
              </p>
              <Button className="w-full" disabled>
                Connect Wallet to Mint
              </Button>
            </CardContent>
          </Card>
        ) : (
          <MintCard
            mintPrice={mintPrice}
            maxPerTx={5}
            totalMinted={totalSupply}
            maxSupply={maxSupply || 10000n}
            isMintActive={isMintActive ?? false}
            onMint={handleMint}
            isLoading={isLoading}
            disabled={!isMintActive}
          />
        )}

        {/* Benefits Card */}
        <Card>
          <CardHeader>
            <CardTitle>NFT Benefits</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-muted-foreground">
              <li>• Exclusive Nexus Genesis collectible</li>
              <li>• On-chain proof of early supporter status</li>
              <li>• Access to holder-only community channels</li>
              <li>• Priority for future airdrops and events</li>
            </ul>
            <p className="text-xs text-amber-600 dark:text-amber-400 mt-4">
              Future protocol upgrades may introduce staking boosts and voting multipliers for NFT holders.
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Stats Section */}
      <div className="grid gap-6 md:grid-cols-3 mt-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Minted</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">
              {totalSupply?.toString() || '0'} / {maxSupply?.toString() || '10,000'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Mint Price</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">
              {mintPrice ? parseFloat(formatEther(mintPrice)).toFixed(4) : '0'} ETH
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Mint Status</CardTitle>
          </CardHeader>
          <CardContent>
            <Badge variant={isMintActive ? "default" : "secondary"} className="text-lg px-3 py-1">
              {isMintActive ? 'Active' : 'Not Active'}
            </Badge>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
