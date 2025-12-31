'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Clock, Users } from 'lucide-react';

type ProposalState = 'Pending' | 'Active' | 'Canceled' | 'Defeated' | 'Succeeded' | 'Queued' | 'Expired' | 'Executed';

interface ProposalCardProps {
  id: string;
  title: string;
  description?: string;
  proposer: string;
  state: ProposalState;
  forVotes: bigint;
  againstVotes: bigint;
  startBlock?: number;
  endBlock?: number;
  currentBlock?: number;
  onClick?: () => void;
}

export function ProposalCard({
  id,
  title,
  description,
  proposer,
  state,
  forVotes,
  againstVotes,
  startBlock,
  endBlock,
  currentBlock,
  onClick,
}: ProposalCardProps) {
  const totalVotes = forVotes + againstVotes;
  const forPercentage = totalVotes > 0n
    ? Number((forVotes * 100n) / totalVotes)
    : 0;

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

  const getVotingProgress = () => {
    if (!startBlock || !endBlock || !currentBlock) return 0;
    if (currentBlock < startBlock) return 0;
    if (currentBlock > endBlock) return 100;
    return ((currentBlock - startBlock) / (endBlock - startBlock)) * 100;
  };

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  return (
    <Card 
      className="cursor-pointer hover:border-primary/50 transition-colors"
      onClick={onClick}
    >
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between gap-2">
          <div className="space-y-1 flex-1">
            <CardTitle className="text-base line-clamp-1">{title}</CardTitle>
            {description && (
              <CardDescription className="line-clamp-2">
                {description}
              </CardDescription>
            )}
          </div>
          <Badge variant={getStateBadgeVariant(state)}>{state}</Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="space-y-1">
          <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">Approval</span>
            <span className="font-medium">{forPercentage.toFixed(1)}%</span>
          </div>
          <Progress value={forPercentage} className="h-2" />
        </div>

        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <div className="flex items-center gap-1">
            <Users className="h-3 w-3" />
            <span>by {shortenAddress(proposer)}</span>
          </div>
          {state === 'Active' && (
            <div className="flex items-center gap-1">
              <Clock className="h-3 w-3" />
              <span>{Math.round(getVotingProgress())}% complete</span>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
