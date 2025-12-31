"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Loader2, ThumbsUp, ThumbsDown, Minus } from "lucide-react";
import { formatUnits } from "viem";

type VoteType = "for" | "against" | "abstain";

interface VotingPanelProps {
  proposalId: string;
  votingPower?: bigint;
  hasVoted?: boolean;
  currentVote?: VoteType;
  isActive?: boolean;
  onVote?: (vote: VoteType) => Promise<void>;
}

export function VotingPanel({
  proposalId,
  votingPower = 0n,
  hasVoted = false,
  currentVote,
  isActive = false,
  onVote,
}: VotingPanelProps) {
  const [selectedVote, setSelectedVote] = useState<VoteType | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const formattedPower = formatUnits(votingPower, 18);
  const hasPower = votingPower > 0n;

  const handleVote = async () => {
    if (!selectedVote || !onVote) return;

    setIsSubmitting(true);
    try {
      await onVote(selectedVote);
    } catch (error) {
      console.error("Vote failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const voteOptions: { type: VoteType; label: string; icon: typeof ThumbsUp; color: string }[] = [
    { type: "for", label: "For", icon: ThumbsUp, color: "text-green-500 border-green-500" },
    { type: "against", label: "Against", icon: ThumbsDown, color: "text-red-500 border-red-500" },
    { type: "abstain", label: "Abstain", icon: Minus, color: "text-gray-500 border-gray-500" },
  ];

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          Cast Your Vote
          {hasVoted && <Badge variant="secondary">Voted</Badge>}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="p-3 bg-muted rounded-lg">
          <p className="text-sm text-muted-foreground">Your Voting Power</p>
          <p className="text-xl font-bold">
            {parseFloat(formattedPower).toLocaleString()} NEXUS
          </p>
        </div>

        {!isActive && (
          <p className="text-sm text-muted-foreground text-center">
            Voting is not currently active for this proposal
          </p>
        )}

        {isActive && !hasPower && (
          <p className="text-sm text-muted-foreground text-center">
            You need voting power to participate. Stake NEXUS tokens to gain voting power.
          </p>
        )}

        {isActive && hasPower && !hasVoted && (
          <>
            <div className="grid grid-cols-3 gap-2">
              {voteOptions.map((option) => (
                <Button
                  key={option.type}
                  variant={selectedVote === option.type ? "default" : "outline"}
                  className={`flex flex-col h-auto py-4 ${
                    selectedVote === option.type ? "" : option.color
                  }`}
                  onClick={() => setSelectedVote(option.type)}
                  disabled={isSubmitting}
                >
                  <option.icon className="h-5 w-5 mb-1" />
                  {option.label}
                </Button>
              ))}
            </div>

            <Button
              className="w-full"
              disabled={!selectedVote || isSubmitting}
              onClick={handleVote}
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Submitting Vote...
                </>
              ) : (
                "Submit Vote"
              )}
            </Button>
          </>
        )}

        {hasVoted && currentVote && (
          <div className="text-center p-4 bg-muted rounded-lg">
            <p className="text-sm text-muted-foreground">You voted</p>
            <p className="text-lg font-medium capitalize">{currentVote}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
