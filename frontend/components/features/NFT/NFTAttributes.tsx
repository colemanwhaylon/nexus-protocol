'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import { Sparkles } from 'lucide-react';

interface NFTAttribute {
  trait_type: string;
  value: string | number;
  rarity?: number;
  count?: number;
  total?: number;
}

interface NFTAttributesProps {
  attributes?: NFTAttribute[];
  isLoading?: boolean;
}

export function NFTAttributes({
  attributes = [],
  isLoading,
}: NFTAttributesProps) {
  const getRarityColor = (rarity?: number) => {
    if (rarity === undefined) return 'bg-muted';
    if (rarity < 1) return 'bg-yellow-500/20 border-yellow-500';
    if (rarity < 5) return 'bg-purple-500/20 border-purple-500';
    if (rarity < 15) return 'bg-blue-500/20 border-blue-500';
    if (rarity < 35) return 'bg-green-500/20 border-green-500';
    return 'bg-muted';
  };

  const getRarityLabel = (rarity?: number) => {
    if (rarity === undefined) return null;
    if (rarity < 1) return 'Legendary';
    if (rarity < 5) return 'Epic';
    if (rarity < 15) return 'Rare';
    if (rarity < 35) return 'Uncommon';
    return 'Common';
  };

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Sparkles className="h-5 w-5" />
            Attributes
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-3">
            {[...Array(6)].map((_, i) => (
              <Skeleton key={i} className="h-20 w-full" />
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  if (attributes.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Sparkles className="h-5 w-5" />
            Attributes
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground text-center py-4">
            No attributes found
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Sparkles className="h-5 w-5" />
          Attributes ({attributes.length})
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-3">
          {attributes.map((attr, index) => (
            <div
              key={index}
              className={`p-3 rounded-lg border ${getRarityColor(attr.rarity)}`}
            >
              <div className="flex items-center justify-between mb-1">
                <p className="text-xs text-muted-foreground uppercase">
                  {attr.trait_type}
                </p>
                {attr.rarity !== undefined && (
                  <Badge variant="outline" className="text-xs">
                    {getRarityLabel(attr.rarity)}
                  </Badge>
                )}
              </div>
              <p className="font-medium truncate">{attr.value}</p>
              {attr.count !== undefined && attr.total !== undefined && (
                <div className="mt-2 space-y-1">
                  <Progress 
                    value={(attr.count / attr.total) * 100} 
                    className="h-1"
                  />
                  <p className="text-xs text-muted-foreground">
                    {attr.count.toLocaleString()} / {attr.total.toLocaleString()} ({attr.rarity?.toFixed(1)}%)
                  </p>
                </div>
              )}
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
