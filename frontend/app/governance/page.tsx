"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Plus } from "lucide-react";
import {
  ProposalList,
  VotingPowerCard,
  DelegateVoting,
} from "@/components/features/Governance";
import type { Address } from "viem";

// Mock data for demonstration - in production, this would come from contract calls
const mockProposals = [
  {
    id: "1",
    title: "Increase staking rewards by 2%",
    state: "active" as const,
    forVotes: BigInt("250000000000000000000000"),
    againstVotes: BigInt("75000000000000000000000"),
    endTime: Math.floor(Date.now() / 1000) + 86400 * 3,
  },
  {
    id: "2",
    title: "Add new liquidity pool for NEXUS/USDC",
    state: "succeeded" as const,
    forVotes: BigInt("500000000000000000000000"),
    againstVotes: BigInt("100000000000000000000000"),
    endTime: Math.floor(Date.now() / 1000) - 86400,
  },
  {
    id: "3",
    title: "Reduce proposal threshold to 50,000 NEXUS",
    state: "pending" as const,
    forVotes: BigInt("0"),
    againstVotes: BigInt("0"),
    endTime: Math.floor(Date.now() / 1000) + 86400 * 7,
  },
  {
    id: "4",
    title: "Update emergency withdrawal parameters",
    state: "defeated" as const,
    forVotes: BigInt("80000000000000000000000"),
    againstVotes: BigInt("320000000000000000000000"),
    endTime: Math.floor(Date.now() / 1000) - 86400 * 2,
  },
  {
    id: "5",
    title: "Allocate treasury funds for security audit",
    state: "executed" as const,
    forVotes: BigInt("600000000000000000000000"),
    againstVotes: BigInt("50000000000000000000000"),
    endTime: Math.floor(Date.now() / 1000) - 86400 * 10,
  },
];

// Mock addresses
const ZERO_ADDRESS: Address = "0x0000000000000000000000000000000000000000";
const MOCK_USER_ADDRESS: Address = "0x742d35Cc6634C0532925a3b844Bc9e7595f2bd18";

export default function GovernancePage() {
  const [isLoading] = useState(false);

  // Mock user data - in production, this would come from wallet connection and contract calls
  const mockVotingPower = BigInt("100000000000000000000000"); // 100,000 NEXUS
  const mockTotalVotingPower = BigInt("10000000000000000000000000"); // 10,000,000 NEXUS
  const mockDelegatedFrom = [
    "0x1234567890123456789012345678901234567890",
    "0x2345678901234567890123456789012345678901",
  ];

  const handleDelegate = async (delegatee: Address) => {
    // In production, this would call the delegate function on the token contract
    console.log("Delegating to:", delegatee);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  };

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold">Governance</h1>
          <p className="text-muted-foreground">
            Participate in protocol governance through proposals and voting
          </p>
        </div>
        <Link href="/governance/create">
          <Button>
            <Plus className="mr-2 h-4 w-4" />
            Create Proposal
          </Button>
        </Link>
      </div>

      {/* Main Content */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Proposals Section - 2 columns */}
        <div className="lg:col-span-2 space-y-6">
          <Tabs defaultValue="proposals" className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="proposals">Proposals</TabsTrigger>
              <TabsTrigger value="delegate">Delegate</TabsTrigger>
            </TabsList>

            <TabsContent value="proposals" className="mt-6">
              <ProposalList
                proposals={mockProposals}
                isLoading={isLoading}
              />
            </TabsContent>

            <TabsContent value="delegate" className="mt-6">
              <DelegateVoting
                votingPower={mockVotingPower}
                currentDelegate={ZERO_ADDRESS}
                selfAddress={MOCK_USER_ADDRESS}
                onDelegate={handleDelegate}
              />
            </TabsContent>
          </Tabs>
        </div>

        {/* Sidebar - 1 column */}
        <div className="space-y-6">
          <VotingPowerCard
            votingPower={mockVotingPower}
            totalVotingPower={mockTotalVotingPower}
            delegatedFrom={mockDelegatedFrom}
            isLoading={isLoading}
          />

          {/* Quick Stats */}
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-muted rounded-lg text-center">
              <p className="text-2xl font-bold">{mockProposals.length}</p>
              <p className="text-sm text-muted-foreground">Total Proposals</p>
            </div>
            <div className="p-4 bg-muted rounded-lg text-center">
              <p className="text-2xl font-bold">
                {mockProposals.filter((p) => p.state === "active").length}
              </p>
              <p className="text-sm text-muted-foreground">Active</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
