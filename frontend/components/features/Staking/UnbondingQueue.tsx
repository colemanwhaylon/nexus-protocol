'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Clock, Timer } from 'lucide-react';
import { formatUnits } from 'viem';

interface UnbondingRequest {
  amount: bigint;
  unlockTime: number;
  id: string;
}

interface UnbondingQueueProps {
  requests?: UnbondingRequest[];
  symbol?: string;
  decimals?: number;
  isLoading?: boolean;
}

export function UnbondingQueue({
  requests = [],
  symbol = 'NEXUS',
  decimals = 18,
  isLoading,
}: UnbondingQueueProps) {
  const now = Math.floor(Date.now() / 1000);

  const formatTimeRemaining = (unlockTime: number) => {
    const remaining = unlockTime - now;
    if (remaining <= 0) return 'Ready to claim';
    
    const days = Math.floor(remaining / 86400);
    const hours = Math.floor((remaining % 86400) / 3600);
    const minutes = Math.floor((remaining % 3600) / 60);
    
    if (days > 0) return `${days}d ${hours}h remaining`;
    if (hours > 0) return `${hours}h ${minutes}m remaining`;
    return `${minutes}m remaining`;
  };

  const isReady = (unlockTime: number) => unlockTime <= now;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Timer className="h-5 w-5" />
          Unbonding Queue
        </CardTitle>
        <CardDescription>
          Your pending unstake requests
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-3">
            {[...Array(3)].map((_, i) => (
              <Skeleton key={i} className="h-16 w-full" />
            ))}
          </div>
        ) : requests.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-4">
            No pending unbonding requests
          </p>
        ) : (
          <div className="space-y-3">
            {requests.map((request) => (
              <div
                key={request.id}
                className="flex items-center justify-between p-3 rounded-lg border"
              >
                <div className="space-y-1">
                  <p className="font-medium">
                    {parseFloat(formatUnits(request.amount, decimals)).toLocaleString()} {symbol}
                  </p>
                  <div className="flex items-center gap-1 text-sm text-muted-foreground">
                    <Clock className="h-3 w-3" />
                    {formatTimeRemaining(request.unlockTime)}
                  </div>
                </div>
                <Badge variant={isReady(request.unlockTime) ? 'default' : 'secondary'}>
                  {isReady(request.unlockTime) ? 'Claimable' : 'Pending'}
                </Badge>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
