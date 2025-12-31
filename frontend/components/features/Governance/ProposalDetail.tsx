'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Separator } from '@/components/ui/separator';
import { ExternalLink, Copy, Check } from 'lucide-react';
import { useState } from 'react';

type ProposalState = 'Pending' | 'Active' | 'Canceled' | 'Defeated' | 'Succeeded' | 'Queued' | 'Expired' | 'Executed';

interface ProposalAction {
  target: string;
  value: bigint;
  calldata: string;
  signature?: string;
}

interface ProposalDetailProps {
  id: string;
  title: string;
  description: string;
  proposer: string;
  state: ProposalState;
  actions?: ProposalAction[];
  startBlock?: number;
  endBlock?: number;
  createdAt?: number;
  chainId?: number;
  isLoading?: boolean;
}

export function ProposalDetail({
  id,
  title,
  description,
  proposer,
  state,
  actions = [],
  startBlock,
  endBlock,
  createdAt,
  chainId,
  isLoading,
}: ProposalDetailProps) {
  const [copied, setCopied] = useState(false);

  const copyProposalId = async () => {
    await navigator.clipboard.writeText(id);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const getExplorerUrl = (address: string) => {
    switch (chainId) {
      case 1:
        return `https://etherscan.io/address/${address}`;
      case 11155111:
        return `https://sepolia.etherscan.io/address/${address}`;
      default:
        return '#';
    }
  };

  const getStateBadgeVariant = (state: ProposalState) => {
    switch (state) {
      case 'Active':
        return 'default';
      case 'Succeeded':
      case 'Executed':
        return 'default';
      case 'Defeated':
      case 'Canceled':
      case 'Expired':
        return 'destructive';
      case 'Queued':
        return 'secondary';
      default:
        return 'outline';
    }
  };

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const formatDate = (timestamp: number) =>
    new Date(timestamp * 1000).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-48" />
          <Skeleton className="h-4 w-32" />
        </CardHeader>
        <CardContent className="space-y-4">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-16 w-full" />
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between gap-4">
          <div className="space-y-1">
            <CardTitle>{title}</CardTitle>
            <CardDescription className="flex items-center gap-2">
              <span>Proposal ID:</span>
              <code className="text-xs bg-muted px-1 rounded">
                {shortenAddress(id)}
              </code>
              <button onClick={copyProposalId} className="p-0.5 hover:bg-muted rounded">
                {copied ? <Check className="h-3 w-3 text-green-500" /> : <Copy className="h-3 w-3" />}
              </button>
            </CardDescription>
          </div>
          <Badge variant={getStateBadgeVariant(state)}>{state}</Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="prose prose-sm dark:prose-invert max-w-none">
          <p className="whitespace-pre-wrap">{description}</p>
        </div>

        <Separator />

        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-muted-foreground">Proposer</p>
            <a
              href={getExplorerUrl(proposer)}
              target="_blank"
              rel="noopener noreferrer"
              className="font-mono flex items-center gap-1 hover:underline"
            >
              {shortenAddress(proposer)}
              <ExternalLink className="h-3 w-3" />
            </a>
          </div>
          {createdAt && (
            <div>
              <p className="text-muted-foreground">Created</p>
              <p className="font-medium">{formatDate(createdAt)}</p>
            </div>
          )}
          {startBlock && (
            <div>
              <p className="text-muted-foreground">Voting Starts</p>
              <p className="font-medium">Block {startBlock.toLocaleString()}</p>
            </div>
          )}
          {endBlock && (
            <div>
              <p className="text-muted-foreground">Voting Ends</p>
              <p className="font-medium">Block {endBlock.toLocaleString()}</p>
            </div>
          )}
        </div>

        {actions.length > 0 && (
          <>
            <Separator />
            <div className="space-y-3">
              <h4 className="font-medium">Actions ({actions.length})</h4>
              {actions.map((action, index) => (
                <div key={index} className="p-3 bg-muted rounded-lg space-y-2 text-sm">
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">Target</span>
                    <code className="font-mono text-xs">{shortenAddress(action.target)}</code>
                  </div>
                  {action.signature && (
                    <div className="flex items-center justify-between">
                      <span className="text-muted-foreground">Function</span>
                      <code className="font-mono text-xs">{action.signature}</code>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}
