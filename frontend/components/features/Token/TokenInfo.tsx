'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Copy, Check, ExternalLink } from 'lucide-react';
import { useState } from 'react';
import { formatUnits } from 'viem';

interface TokenInfoProps {
  name?: string;
  symbol?: string;
  decimals?: number;
  totalSupply?: bigint;
  contractAddress?: string;
  chainId?: number;
  isLoading?: boolean;
}

export function TokenInfo({
  name = 'Nexus Token',
  symbol = 'NEXUS',
  decimals = 18,
  totalSupply,
  contractAddress,
  chainId,
  isLoading,
}: TokenInfoProps) {
  const [copied, setCopied] = useState(false);

  const copyAddress = async () => {
    if (contractAddress) {
      await navigator.clipboard.writeText(contractAddress);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const getExplorerUrl = () => {
    if (!contractAddress) return '#';
    switch (chainId) {
      case 1:
        return `https://etherscan.io/token/${contractAddress}`;
      case 11155111:
        return `https://sepolia.etherscan.io/token/${contractAddress}`;
      default:
        return '#';
    }
  };

  const formattedSupply = totalSupply
    ? parseFloat(formatUnits(totalSupply, decimals)).toLocaleString()
    : '0';

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          Token Information
          <Badge variant="outline">{symbol}</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {isLoading ? (
          <div className="space-y-3">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="flex justify-between">
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-4 w-32" />
              </div>
            ))}
          </div>
        ) : (
          <>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Name</span>
              <span className="font-medium">{name}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Symbol</span>
              <span className="font-medium">{symbol}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Decimals</span>
              <span className="font-medium">{decimals}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-muted-foreground">Total Supply</span>
              <span className="font-medium">
                {formattedSupply} {symbol}
              </span>
            </div>
            {contractAddress && (
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Contract</span>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-sm">
                    {shortenAddress(contractAddress)}
                  </span>
                  <button
                    onClick={copyAddress}
                    className="p-1 hover:bg-muted rounded"
                  >
                    {copied ? (
                      <Check className="h-3 w-3 text-green-500" />
                    ) : (
                      <Copy className="h-3 w-3" />
                    )}
                  </button>
                  <a
                    href={getExplorerUrl()}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-1 hover:bg-muted rounded"
                  >
                    <ExternalLink className="h-3 w-3" />
                  </a>
                </div>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
