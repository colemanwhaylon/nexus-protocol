'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Coins, TrendingUp, TrendingDown } from 'lucide-react';
import { formatUnits } from 'viem';

interface TokenBalanceProps {
  balance?: bigint;
  symbol?: string;
  decimals?: number;
  usdPrice?: number;
  priceChange24h?: number;
  isLoading?: boolean;
}

export function TokenBalance({
  balance = 0n,
  symbol = 'NEXUS',
  decimals = 18,
  usdPrice,
  priceChange24h,
  isLoading,
}: TokenBalanceProps) {
  const formattedBalance = formatUnits(balance, decimals);
  const numericBalance = parseFloat(formattedBalance);
  const usdValue = usdPrice ? numericBalance * usdPrice : null;

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">Token Balance</CardTitle>
        <Coins className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-2">
            <Skeleton className="h-8 w-32" />
            <Skeleton className="h-4 w-24" />
          </div>
        ) : (
          <div className="space-y-1">
            <div className="text-2xl font-bold">
              {numericBalance.toLocaleString(undefined, {
                maximumFractionDigits: 4,
              })}{' '}
              <span className="text-lg text-muted-foreground">{symbol}</span>
            </div>
            {usdValue !== null && (
              <div className="flex items-center gap-2">
                <span className="text-sm text-muted-foreground">
                  ≈ ${usdValue.toLocaleString(undefined, { maximumFractionDigits: 2 })}
                </span>
                {priceChange24h !== undefined && (
                  <span
                    className={`flex items-center text-xs ${
                      priceChange24h >= 0 ? 'text-green-500' : 'text-red-500'
                    }`}
                  >
                    {priceChange24h >= 0 ? (
                      <TrendingUp className="mr-1 h-3 w-3" />
                    ) : (
                      <TrendingDown className="mr-1 h-3 w-3" />
                    )}
                    {Math.abs(priceChange24h).toFixed(2)}%
                  </span>
                )}
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
