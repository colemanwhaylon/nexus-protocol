'use client';

import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { NFTAttributes } from './NFTAttributes';
import { 
  ExternalLink, 
  Copy, 
  Check, 
  Share2, 
  Heart,
  ArrowLeft 
} from 'lucide-react';
import { useState } from 'react';

interface NFTAttribute {
  trait_type: string;
  value: string | number;
  rarity?: number;
  count?: number;
  total?: number;
}

interface NFTDetailProps {
  tokenId: string;
  name?: string;
  description?: string;
  image?: string;
  owner?: string;
  creator?: string;
  contractAddress?: string;
  attributes?: NFTAttribute[];
  rarity?: number;
  isFavorite?: boolean;
  chainId?: number;
  onBack?: () => void;
  onFavorite?: () => void;
  onTransfer?: () => void;
  isLoading?: boolean;
}

export function NFTDetail({
  tokenId,
  name,
  description,
  image,
  owner,
  creator,
  contractAddress,
  attributes = [],
  rarity,
  isFavorite,
  chainId,
  onBack,
  onFavorite,
  onTransfer,
  isLoading,
}: NFTDetailProps) {
  const [copied, setCopied] = useState(false);

  const displayName = name || `Nexus NFT #${tokenId}`;

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const getExplorerUrl = (address: string, type: 'address' | 'token' = 'address') => {
    const path = type === 'token' ? `token/${address}?a=${tokenId}` : `address/${address}`;
    switch (chainId) {
      case 1:
        return `https://etherscan.io/${path}`;
      case 11155111:
        return `https://sepolia.etherscan.io/${path}`;
      default:
        return '#';
    }
  };

  const copyTokenId = async () => {
    await navigator.clipboard.writeText(tokenId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleShare = async () => {
    if (navigator.share) {
      await navigator.share({
        title: displayName,
        text: description || `Check out ${displayName}`,
        url: window.location.href,
      });
    } else {
      await navigator.clipboard.writeText(window.location.href);
    }
  };

  const rarityLabel = rarity !== undefined
    ? rarity < 1 ? 'Legendary'
    : rarity < 5 ? 'Epic'
    : rarity < 15 ? 'Rare'
    : rarity < 35 ? 'Uncommon'
    : 'Common'
    : undefined;

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-32" />
        <div className="grid md:grid-cols-2 gap-6">
          <Skeleton className="aspect-square w-full rounded-lg" />
          <div className="space-y-4">
            <Skeleton className="h-8 w-48" />
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {onBack && (
        <Button variant="ghost" onClick={onBack} className="gap-2">
          <ArrowLeft className="h-4 w-4" />
          Back to Gallery
        </Button>
      )}

      <div className="grid md:grid-cols-2 gap-6">
        {/* Image */}
        <Card className="overflow-hidden">
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
          </div>
        </Card>

        {/* Info */}
        <div className="space-y-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold">{displayName}</h1>
              <div className="flex items-center gap-2 mt-1">
                <code className="text-sm bg-muted px-2 py-0.5 rounded">
                  #{tokenId}
                </code>
                <button onClick={copyTokenId} className="p-1 hover:bg-muted rounded">
                  {copied ? <Check className="h-4 w-4 text-green-500" /> : <Copy className="h-4 w-4" />}
                </button>
                {rarityLabel && (
                  <Badge>{rarityLabel}</Badge>
                )}
              </div>
            </div>
            <div className="flex gap-2">
              {onFavorite && (
                <Button variant="outline" size="icon" onClick={onFavorite}>
                  <Heart className={`h-4 w-4 ${isFavorite ? 'fill-red-500 text-red-500' : ''}`} />
                </Button>
              )}
              <Button variant="outline" size="icon" onClick={handleShare}>
                <Share2 className="h-4 w-4" />
              </Button>
            </div>
          </div>

          {description && (
            <p className="text-muted-foreground">{description}</p>
          )}

          <Card>
            <CardContent className="p-4 space-y-3">
              {owner && (
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Owner</span>
                  <a
                    href={getExplorerUrl(owner)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="font-mono text-sm flex items-center gap-1 hover:underline"
                  >
                    {shortenAddress(owner)}
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              )}
              {creator && (
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Creator</span>
                  <a
                    href={getExplorerUrl(creator)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="font-mono text-sm flex items-center gap-1 hover:underline"
                  >
                    {shortenAddress(creator)}
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              )}
              {contractAddress && (
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Contract</span>
                  <a
                    href={getExplorerUrl(contractAddress, 'token')}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="font-mono text-sm flex items-center gap-1 hover:underline"
                  >
                    {shortenAddress(contractAddress)}
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              )}
            </CardContent>
          </Card>

          {onTransfer && (
            <Button className="w-full" onClick={onTransfer}>
              Transfer NFT
            </Button>
          )}
        </div>
      </div>

      {/* Attributes */}
      <NFTAttributes attributes={attributes} />
    </div>
  );
}
