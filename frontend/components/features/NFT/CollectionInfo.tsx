'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Image, Users, Coins, Percent } from 'lucide-react';
import { formatEther } from 'viem';

interface CollectionInfoProps {
  name?: string;
  symbol?: string;
  totalSupply?: bigint;
  maxSupply?: bigint;
  floorPrice?: bigint;
  royaltyPercentage?: number;
  ownerCount?: number;
  isLoading?: boolean;
}

export function CollectionInfo({
  name = 'Nexus NFT',
  symbol = 'NNFT',
  totalSupply = 0n,
  maxSupply = 10000n,
  floorPrice,
  royaltyPercentage = 5,
  ownerCount,
  isLoading,
}: CollectionInfoProps) {
  const mintedPercentage = maxSupply > 0n
    ? Number((totalSupply * 100n) / maxSupply)
    : 0;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Image className="h-5 w-5" />
            Collection Info
          </div>
          <Badge variant="outline">{symbol}</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-3">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="flex justify-between">
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-4 w-24" />
              </div>
            ))}
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Name</span>
              <span className="font-medium">{name}</span>
            </div>

            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Minted</span>
              <div className="text-right">
                <span className="font-medium">
                  {totalSupply.toString()} / {maxSupply.toString()}
                </span>
                <span className="text-xs text-muted-foreground ml-2">
                  ({mintedPercentage.toFixed(1)}%)
                </span>
              </div>
            </div>

            {floorPrice !== undefined && (
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground flex items-center gap-1">
                  <Coins className="h-3 w-3" />
                  Floor Price
                </span>
                <span className="font-medium">
                  {parseFloat(formatEther(floorPrice)).toFixed(4)} ETH
                </span>
              </div>
            )}

            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground flex items-center gap-1">
                <Percent className="h-3 w-3" />
                Royalty
              </span>
              <span className="font-medium">{royaltyPercentage}%</span>
            </div>

            {ownerCount !== undefined && (
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground flex items-center gap-1">
                  <Users className="h-3 w-3" />
                  Owners
                </span>
                <span className="font-medium">{ownerCount.toLocaleString()}</span>
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
