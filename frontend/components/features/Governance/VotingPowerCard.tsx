'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Badge } from '@/components/ui/badge';
import { Vote, Users, TrendingUp } from 'lucide-react';
import { formatUnits } from 'viem';

interface VotingPowerCardProps {
  votingPower?: bigint;
  totalVotingPower?: bigint;
  delegatedTo?: string;
  delegatedFrom?: string[];
  decimals?: number;
  symbol?: string;
  isLoading?: boolean;
}

export function VotingPowerCard({
  votingPower = 0n,
  totalVotingPower,
  delegatedTo,
  delegatedFrom = [],
  decimals = 18,
  symbol: _symbol = 'NEXUS',
  isLoading,
}: VotingPowerCardProps) {
  const formattedPower = parseFloat(formatUnits(votingPower, decimals));
  const percentage = totalVotingPower && totalVotingPower > 0n
    ? Number((votingPower * 10000n) / totalVotingPower) / 100
    : 0;

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const isSelfDelegated = !delegatedTo || delegatedTo === '0x0000000000000000000000000000000000000000';

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">Your Voting Power</CardTitle>
        <Vote className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-2">
            <Skeleton className="h-8 w-32" />
            <Skeleton className="h-4 w-24" />
          </div>
        ) : (
          <div className="space-y-3">
            <div>
              <div className="text-2xl font-bold">
                {formattedPower.toLocaleString(undefined, { maximumFractionDigits: 2 })}
              </div>
              <p className="text-xs text-muted-foreground">
                {percentage.toFixed(4)}% of total voting power
              </p>
            </div>

            {!isSelfDelegated && delegatedTo && (
              <div className="flex items-center gap-2 text-sm">
                <TrendingUp className="h-4 w-4 text-muted-foreground" />
                <span className="text-muted-foreground">Delegated to:</span>
                <code className="text-xs bg-muted px-1.5 py-0.5 rounded">
                  {shortenAddress(delegatedTo)}
                </code>
              </div>
            )}

            {delegatedFrom.length > 0 && (
              <div className="space-y-2">
                <div className="flex items-center gap-2 text-sm">
                  <Users className="h-4 w-4 text-muted-foreground" />
                  <span className="text-muted-foreground">
                    {delegatedFrom.length} delegator{delegatedFrom.length > 1 ? 's' : ''}
                  </span>
                </div>
                <div className="flex flex-wrap gap-1">
                  {delegatedFrom.slice(0, 3).map((addr) => (
                    <Badge key={addr} variant="secondary" className="text-xs font-mono">
                      {shortenAddress(addr)}
                    </Badge>
                  ))}
                  {delegatedFrom.length > 3 && (
                    <Badge variant="outline" className="text-xs">
                      +{delegatedFrom.length - 3} more
                    </Badge>
                  )}
                </div>
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
