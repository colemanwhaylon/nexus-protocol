"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Share2, ExternalLink } from "lucide-react";
import {
  ProposalDetail,
  ProposalTimeline,
  ProposalActions,
  VotingPanel,
  VoteResults,
} from "@/components/features/Governance";

type VoteType = "for" | "against" | "abstain";

interface Props {
  params: { proposalId: string };
}

// Mock proposal data - in production, this would come from contract calls
const getMockProposal = (id: string) => ({
  id,
  title: "Increase staking rewards by 2%",
  description: `## Summary
This proposal aims to increase the base staking rewards from 8% to 10% APY to incentivize more token holders to participate in staking.

## Motivation
Current staking participation is at 35% of circulating supply. Increasing rewards will:
- Encourage more long-term holding
- Reduce circulating supply and selling pressure
- Strengthen protocol security through increased stake

## Implementation
The RewardsDistributor contract will be updated with new reward parameters. This change requires a single transaction to update the rewardRate variable.

## Risks
- Increased token inflation (~0.5% additional annually)
- Potential for short-term farming behavior

## Timeline
If passed, changes will take effect immediately after the timelock period.`,
  proposer: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bd18",
  state: "Active" as const,
  forVotes: BigInt("250000000000000000000000"),
  againstVotes: BigInt("75000000000000000000000"),
  abstainVotes: BigInt("25000000000000000000000"),
  startBlock: 18500000,
  endBlock: 18550000,
  createdAt: Math.floor(Date.now() / 1000) - 86400 * 2,
  votingStartedAt: Math.floor(Date.now() / 1000) - 86400,
  quorum: BigInt("400000000000000000000000"),
  actions: [
    {
      target: "0x1234567890123456789012345678901234567890",
      value: BigInt(0),
      calldata: "0x",
      signature: "setRewardRate(uint256)",
    },
  ],
});

export default function ProposalDetailPage({ params }: Props) {
  const [proposal, setProposal] = useState<ReturnType<typeof getMockProposal> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [hasVoted, setHasVoted] = useState(false);
  const [currentVote, setCurrentVote] = useState<VoteType | undefined>();

  // Mock user data
  const mockVotingPower = BigInt("100000000000000000000000"); // 100,000 NEXUS
  const mockUserAddress = "0xYourAddress1234567890123456789012345678";

  useEffect(() => {
    // Simulate loading proposal data
    const loadProposal = async () => {
      setIsLoading(true);
      await new Promise((resolve) => setTimeout(resolve, 500));
      setProposal(getMockProposal(params.proposalId));
      setIsLoading(false);
    };
    loadProposal();
  }, [params.proposalId]);

  const handleVote = async (vote: VoteType) => {
    // In production, this would call the castVote function on the Governor contract
    console.log("Casting vote:", vote, "for proposal:", params.proposalId);
    await new Promise((resolve) => setTimeout(resolve, 1000));
    setHasVoted(true);
    setCurrentVote(vote);
  };

  const handleQueue = async () => {
    // In production, this would call the queue function on the Governor contract
    console.log("Queueing proposal:", params.proposalId);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  };

  const handleExecute = async () => {
    // In production, this would call the execute function on the Governor contract
    console.log("Executing proposal:", params.proposalId);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  };

  const handleCancel = async () => {
    // In production, this would call the cancel function on the Governor contract
    console.log("Canceling proposal:", params.proposalId);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  };

  const handleShare = async () => {
    const url = window.location.href;
    try {
      await navigator.clipboard.writeText(url);
      // In production, show a toast notification
      console.log("Link copied to clipboard");
    } catch {
      console.error("Failed to copy link");
    }
  };

  if (isLoading || !proposal) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <Link href="/governance">
            <Button variant="ghost" size="sm" className="mb-4">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Governance
            </Button>
          </Link>
        </div>
        <ProposalDetail
          id=""
          title=""
          description=""
          proposer=""
          state="Pending"
          isLoading={true}
        />
      </div>
    );
  }

  const quorumReached = (proposal.forVotes + proposal.againstVotes + proposal.abstainVotes) >= proposal.quorum;

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
        <Link href="/governance">
          <Button variant="ghost" size="sm">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Governance
          </Button>
        </Link>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={handleShare}>
            <Share2 className="mr-2 h-4 w-4" />
            Share
          </Button>
          <Link
            href={`https://etherscan.io/tx/${proposal.id}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            <Button variant="outline" size="sm">
              <ExternalLink className="mr-2 h-4 w-4" />
              View on Explorer
            </Button>
          </Link>
        </div>
      </div>

      {/* Main Content */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Main Column - Proposal Details */}
        <div className="lg:col-span-2 space-y-6">
          <ProposalDetail
            id={proposal.id}
            title={proposal.title}
            description={proposal.description}
            proposer={proposal.proposer}
            state={proposal.state}
            actions={proposal.actions}
            startBlock={proposal.startBlock}
            endBlock={proposal.endBlock}
            createdAt={proposal.createdAt}
            chainId={1}
          />

          {/* Vote Results */}
          <VoteResults
            forVotes={proposal.forVotes}
            againstVotes={proposal.againstVotes}
            abstainVotes={proposal.abstainVotes}
            quorum={proposal.quorum}
            quorumReached={quorumReached}
          />
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Voting Panel */}
          <VotingPanel
            proposalId={proposal.id}
            votingPower={mockVotingPower}
            hasVoted={hasVoted}
            currentVote={currentVote}
            isActive={proposal.state === "Active"}
            onVote={handleVote}
          />

          {/* Timeline */}
          <ProposalTimeline
            state={proposal.state}
            createdAt={proposal.createdAt}
            votingStartedAt={proposal.votingStartedAt}
          />

          {/* Actions (Queue, Execute, Cancel) */}
          <ProposalActions
            state={proposal.state}
            proposer={proposal.proposer}
            currentUser={mockUserAddress}
            isAdmin={false}
            onQueue={handleQueue}
            onExecute={handleExecute}
            onCancel={handleCancel}
          />
        </div>
      </div>
    </div>
  );
}
