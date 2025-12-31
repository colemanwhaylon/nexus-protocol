'use client';

import { NFTCard } from './NFTCard';
import { Skeleton } from '@/components/ui/skeleton';
import { Card, CardContent } from '@/components/ui/card';

interface NFTAttribute {
  trait_type: string;
  value: string | number;
  rarity?: number;
}

interface NFT {
  tokenId: string;
  name?: string;
  image?: string;
  attributes?: NFTAttribute[];
  rarity?: number;
}

interface NFTGridProps {
  nfts?: NFT[];
  ownedTokenIds?: string[];
  favoriteTokenIds?: string[];
  onSelect?: (tokenId: string) => void;
  onFavorite?: (tokenId: string) => void;
  isLoading?: boolean;
  emptyMessage?: string;
  columns?: 2 | 3 | 4;
}

export function NFTGrid({
  nfts = [],
  ownedTokenIds = [],
  favoriteTokenIds = [],
  onSelect,
  onFavorite,
  isLoading,
  emptyMessage = 'No NFTs found',
  columns = 3,
}: NFTGridProps) {
  const gridCols = {
    2: 'grid-cols-1 sm:grid-cols-2',
    3: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3',
    4: 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-4',
  };

  if (isLoading) {
    return (
      <div className={`grid ${gridCols[columns]} gap-4`}>
        {[...Array(6)].map((_, i) => (
          <Card key={i} className="overflow-hidden">
            <Skeleton className="aspect-square w-full" />
            <CardContent className="p-3 space-y-2">
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-3 w-16" />
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  if (nfts.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-muted-foreground">{emptyMessage}</p>
      </div>
    );
  }

  return (
    <div className={`grid ${gridCols[columns]} gap-4`}>
      {nfts.map((nft) => (
        <NFTCard
          key={nft.tokenId}
          tokenId={nft.tokenId}
          name={nft.name}
          image={nft.image}
          attributes={nft.attributes}
          rarity={nft.rarity}
          isOwned={ownedTokenIds.includes(nft.tokenId)}
          isFavorite={favoriteTokenIds.includes(nft.tokenId)}
          onClick={() => onSelect?.(nft.tokenId)}
          onFavorite={() => onFavorite?.(nft.tokenId)}
        />
      ))}
    </div>
  );
}
