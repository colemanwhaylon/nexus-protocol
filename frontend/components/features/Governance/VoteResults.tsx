"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatUnits } from "viem";

interface VoteResultsProps {
  forVotes: bigint;
  againstVotes: bigint;
  abstainVotes: bigint;
  quorum?: bigint;
  quorumReached?: boolean;
}

export function VoteResults({
  forVotes,
  againstVotes,
  abstainVotes,
  quorum,
  quorumReached = false,
}: VoteResultsProps) {
  const totalVotes = forVotes + againstVotes + abstainVotes;
  
  const forPercentage = totalVotes > 0n ? Number((forVotes * 100n) / totalVotes) : 0;
  const againstPercentage = totalVotes > 0n ? Number((againstVotes * 100n) / totalVotes) : 0;
  const abstainPercentage = totalVotes > 0n ? Number((abstainVotes * 100n) / totalVotes) : 0;

  const formatVotes = (votes: bigint) => {
    const formatted = formatUnits(votes, 18);
    return parseFloat(formatted).toLocaleString(undefined, { maximumFractionDigits: 0 });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          Current Results
          {quorum && (
            <span className={`text-sm font-normal ${quorumReached ? "text-green-500" : "text-muted-foreground"}`}>
              {quorumReached ? "✓ Quorum reached" : `Quorum: ${formatVotes(quorum)}`}
            </span>
          )}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* For votes */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium text-green-500">For</span>
            <span>{formatVotes(forVotes)} ({forPercentage.toFixed(1)}%)</span>
          </div>
          <div className="h-3 bg-muted rounded-full overflow-hidden">
            <div
              className="h-full bg-green-500 transition-all duration-500"
              style={{ width: `${forPercentage}%` }}
            />
          </div>
        </div>

        {/* Against votes */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium text-red-500">Against</span>
            <span>{formatVotes(againstVotes)} ({againstPercentage.toFixed(1)}%)</span>
          </div>
          <div className="h-3 bg-muted rounded-full overflow-hidden">
            <div
              className="h-full bg-red-500 transition-all duration-500"
              style={{ width: `${againstPercentage}%` }}
            />
          </div>
        </div>

        {/* Abstain votes */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium text-gray-500">Abstain</span>
            <span>{formatVotes(abstainVotes)} ({abstainPercentage.toFixed(1)}%)</span>
          </div>
          <div className="h-3 bg-muted rounded-full overflow-hidden">
            <div
              className="h-full bg-gray-500 transition-all duration-500"
              style={{ width: `${abstainPercentage}%` }}
            />
          </div>
        </div>

        {/* Total */}
        <div className="pt-2 border-t">
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">Total Votes</span>
            <span className="font-medium">{formatVotes(totalVotes)}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
