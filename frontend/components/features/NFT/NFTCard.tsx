'use client';

import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Heart, ExternalLink } from 'lucide-react';

interface NFTAttribute {
  trait_type: string;
  value: string | number;
  rarity?: number;
}

interface NFTCardProps {
  tokenId: string;
  name?: string;
  image?: string;
  attributes?: NFTAttribute[];
  rarity?: number;
  isOwned?: boolean;
  isFavorite?: boolean;
  onClick?: () => void;
  onFavorite?: () => void;
  isLoading?: boolean;
}

export function NFTCard({
  tokenId,
  name,
  image,
  attributes = [],
  rarity,
  isOwned,
  isFavorite,
  onClick,
  onFavorite,
  isLoading,
}: NFTCardProps) {
  if (isLoading) {
    return (
      <Card className="overflow-hidden">
        <Skeleton className="aspect-square w-full" />
        <CardContent className="p-3 space-y-2">
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-3 w-16" />
        </CardContent>
      </Card>
    );
  }

  const displayName = name || `#${tokenId}`;
  const rarityLabel = rarity !== undefined
    ? rarity < 1 ? 'Legendary'
    : rarity < 5 ? 'Epic'
    : rarity < 15 ? 'Rare'
    : rarity < 35 ? 'Uncommon'
    : 'Common'
    : undefined;

  const rarityColor = {
    Legendary: 'bg-yellow-500',
    Epic: 'bg-purple-500',
    Rare: 'bg-blue-500',
    Uncommon: 'bg-green-500',
    Common: 'bg-gray-500',
  };

  return (
    <Card 
      className="overflow-hidden group cursor-pointer hover:border-primary/50 transition-all"
      onClick={onClick}
    >
      <div className="relative aspect-square bg-muted">
        {image ? (
          /* eslint-disable-next-line @next/next/no-img-element */
          <img
            src={image}
            alt={displayName}
            className="absolute inset-0 w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-muted-foreground">
            No Image
          </div>
        )}
        
        {/* Overlay actions */}
        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors">
          <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
            {onFavorite && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onFavorite();
                }}
                className="p-1.5 bg-background/80 rounded-full hover:bg-background"
              >
                <Heart className={`h-4 w-4 ${isFavorite ? 'fill-red-500 text-red-500' : ''}`} />
              </button>
            )}
            <button className="p-1.5 bg-background/80 rounded-full hover:bg-background">
              <ExternalLink className="h-4 w-4" />
            </button>
          </div>
        </div>

        {/* Badges */}
        <div className="absolute top-2 left-2 flex flex-col gap-1">
          {isOwned && (
            <Badge variant="secondary" className="text-xs">Owned</Badge>
          )}
          {rarityLabel && (
            <Badge className={`text-xs ${rarityColor[rarityLabel]}`}>
              {rarityLabel}
            </Badge>
          )}
        </div>
      </div>

      <CardContent className="p-3">
        <h3 className="font-medium truncate">{displayName}</h3>
        <p className="text-sm text-muted-foreground">
          Token #{tokenId}
        </p>
        {attributes.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-1">
            {attributes.slice(0, 2).map((attr, i) => (
              <Badge key={i} variant="outline" className="text-xs">
                {attr.value}
              </Badge>
            ))}
            {attributes.length > 2 && (
              <Badge variant="outline" className="text-xs">
                +{attributes.length - 2}
              </Badge>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
