"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ChevronRight, Clock, CheckCircle, XCircle, Timer } from "lucide-react";
import Link from "next/link";

type ProposalState = "pending" | "active" | "succeeded" | "defeated" | "queued" | "executed" | "canceled" | "expired";

interface Proposal {
  id: string;
  title: string;
  state: ProposalState;
  forVotes: bigint;
  againstVotes: bigint;
  endTime: number;
}

interface ProposalListProps {
  proposals?: Proposal[];
  isLoading?: boolean;
}

const stateConfig: Record<ProposalState, { label: string; variant: "default" | "secondary" | "destructive" | "outline"; icon: typeof Clock }> = {
  pending: { label: "Pending", variant: "secondary", icon: Clock },
  active: { label: "Active", variant: "default", icon: Timer },
  succeeded: { label: "Succeeded", variant: "default", icon: CheckCircle },
  defeated: { label: "Defeated", variant: "destructive", icon: XCircle },
  queued: { label: "Queued", variant: "secondary", icon: Clock },
  executed: { label: "Executed", variant: "default", icon: CheckCircle },
  canceled: { label: "Canceled", variant: "outline", icon: XCircle },
  expired: { label: "Expired", variant: "outline", icon: Clock },
};

function ProposalCard({ proposal }: { proposal: Proposal }) {
  const config = stateConfig[proposal.state];
  const totalVotes = proposal.forVotes + proposal.againstVotes;
  const forPercentage = totalVotes > 0n 
    ? Number((proposal.forVotes * 100n) / totalVotes)
    : 0;

  return (
    <Link href={`/governance/${proposal.id}`}>
      <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div className="space-y-1 flex-1">
              <div className="flex items-center gap-2">
                <Badge variant={config.variant}>
                  <config.icon className="mr-1 h-3 w-3" />
                  {config.label}
                </Badge>
                <span className="text-sm text-muted-foreground">#{proposal.id}</span>
              </div>
              <h3 className="font-medium">{proposal.title}</h3>
              {proposal.state === "active" && (
                <div className="flex items-center gap-2 mt-2">
                  <div className="flex-1 h-2 bg-muted rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-green-500 transition-all"
                      style={{ width: `${forPercentage}%` }}
                    />
                  </div>
                  <span className="text-xs text-muted-foreground">{forPercentage}% For</span>
                </div>
              )}
            </div>
            <ChevronRight className="h-5 w-5 text-muted-foreground" />
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

export function ProposalList({ proposals, isLoading }: ProposalListProps) {
  const [filter, setFilter] = useState<"all" | "active" | "passed" | "failed">("all");

  if (isLoading) {
    return (
      <div className="space-y-4">
        {[...Array(3)].map((_, i) => (
          <Card key={i}>
            <CardContent className="p-4">
              <Skeleton className="h-6 w-24 mb-2" />
              <Skeleton className="h-5 w-full" />
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  const filteredProposals = proposals?.filter((p) => {
    if (filter === "all") return true;
    if (filter === "active") return p.state === "active" || p.state === "pending";
    if (filter === "passed") return p.state === "succeeded" || p.state === "executed" || p.state === "queued";
    if (filter === "failed") return p.state === "defeated" || p.state === "canceled" || p.state === "expired";
    return true;
  });

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        {(["all", "active", "passed", "failed"] as const).map((f) => (
          <Button
            key={f}
            variant={filter === f ? "default" : "outline"}
            size="sm"
            onClick={() => setFilter(f)}
          >
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </Button>
        ))}
      </div>

      {filteredProposals?.length === 0 ? (
        <Card>
          <CardContent className="p-8 text-center">
            <p className="text-muted-foreground">No proposals found</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-2">
          {filteredProposals?.map((proposal) => (
            <ProposalCard key={proposal.id} proposal={proposal} />
          ))}
        </div>
      )}
    </div>
  );
}
