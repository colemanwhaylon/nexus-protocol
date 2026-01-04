"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Plus } from "lucide-react";
import {
  ProposalList,
  VotingPowerCard,
  DelegateVoting,
} from "@/components/features/Governance";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { getContractAddresses } from "@/lib/contracts/addresses";
import type { Address } from "viem";
import { parseAbiItem } from "viem";

// Governor ABI for reading proposal data
const governorAbi = [
  {
    name: "state",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint8" }],
  },
  {
    name: "proposalVotes",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [
      { name: "againstVotes", type: "uint256" },
      { name: "forVotes", type: "uint256" },
      { name: "abstainVotes", type: "uint256" },
    ],
  },
  {
    name: "proposalDeadline",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

// Token ABI for voting power and delegation
const tokenAbi = [
  {
    name: "getVotes",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "delegates",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "address" }],
  },
  {
    name: "delegate",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "delegatee", type: "address" }],
    outputs: [],
  },
  {
    name: "totalSupply",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
] as const;

type ProposalState =
  | "pending"
  | "active"
  | "canceled"
  | "defeated"
  | "succeeded"
  | "queued"
  | "expired"
  | "executed";

interface Proposal {
  id: string;
  title: string;
  state: ProposalState;
  forVotes: bigint;
  againstVotes: bigint;
  endTime: number;
}

// Map numeric state to string state
const stateMap: Record<number, ProposalState> = {
  0: "pending",
  1: "active",
  2: "canceled",
  3: "defeated",
  4: "succeeded",
  5: "queued",
  6: "expired",
  7: "executed",
};

const ZERO_ADDRESS: Address = "0x0000000000000000000000000000000000000000";

export default function GovernancePage() {
  const { address: userAddress } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const addresses = getContractAddresses(chainId);

  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [isLoadingProposals, setIsLoadingProposals] = useState(true);
  const [isDelegating, setIsDelegating] = useState(false);

  const governorAddress = addresses.nexusGovernor;
  const tokenAddress = addresses.nexusToken;
  const isGovernorDeployed = governorAddress !== ZERO_ADDRESS;
  const isTokenDeployed = tokenAddress !== ZERO_ADDRESS;

  // Read user's voting power
  const { data: votingPower, isLoading: isLoadingVotingPower } = useReadContract({
    address: tokenAddress,
    abi: tokenAbi,
    functionName: "getVotes",
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: isTokenDeployed && !!userAddress,
    },
  });

  // Read total supply for voting power percentage
  const { data: totalSupply, isLoading: isLoadingTotalSupply } = useReadContract({
    address: tokenAddress,
    abi: tokenAbi,
    functionName: "totalSupply",
    query: {
      enabled: isTokenDeployed,
    },
  });

  // Read current delegate
  const { data: currentDelegate, refetch: refetchDelegate } = useReadContract({
    address: tokenAddress,
    abi: tokenAbi,
    functionName: "delegates",
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: isTokenDeployed && !!userAddress,
    },
  });

  // Delegation transaction
  const { writeContract, data: delegateHash, isPending: isDelegatePending } = useWriteContract();
  const { isLoading: isDelegateConfirming, isSuccess: isDelegateSuccess } = useWaitForTransactionReceipt({
    hash: delegateHash,
  });

  // Refetch delegate after successful transaction
  useEffect(() => {
    if (isDelegateSuccess) {
      refetchDelegate();
      setIsDelegating(false);
    }
  }, [isDelegateSuccess, refetchDelegate]);

  // Fetch proposals from contract events
  const fetchProposals = useCallback(async () => {
    if (!publicClient || !isGovernorDeployed) {
      setIsLoadingProposals(false);
      return;
    }

    setIsLoadingProposals(true);

    try {
      // Get ProposalCreated events from the governor contract
      const logs = await publicClient.getLogs({
        address: governorAddress,
        event: parseAbiItem(
          "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)"
        ),
        fromBlock: "earliest",
        toBlock: "latest",
      });

      // Build proposal objects from events
      const proposalPromises = logs.map(async (log) => {
        const proposalId = log.args.proposalId as bigint;
        const description = log.args.description as string;

        // Extract title from description (usually first line)
        const title = description.split("\n")[0] || `Proposal #${proposalId.toString()}`;

        // Get proposal state
        const stateResult = await publicClient.readContract({
          address: governorAddress,
          abi: governorAbi,
          functionName: "state",
          args: [proposalId],
        });

        // Get proposal votes
        const votesResult = await publicClient.readContract({
          address: governorAddress,
          abi: governorAbi,
          functionName: "proposalVotes",
          args: [proposalId],
        });

        // Get proposal deadline
        const deadlineResult = await publicClient.readContract({
          address: governorAddress,
          abi: governorAbi,
          functionName: "proposalDeadline",
          args: [proposalId],
        });

        const [againstVotes, forVotes] = votesResult as [bigint, bigint, bigint];

        return {
          id: proposalId.toString(),
          title,
          state: stateMap[Number(stateResult)] || "pending",
          forVotes,
          againstVotes,
          endTime: Number(deadlineResult),
        };
      });

      const fetchedProposals = await Promise.all(proposalPromises);
      // Sort by ID descending (newest first)
      fetchedProposals.sort((a, b) => Number(BigInt(b.id) - BigInt(a.id)));
      setProposals(fetchedProposals);
    } catch (error) {
      console.error("Error fetching proposals:", error);
      setProposals([]);
    } finally {
      setIsLoadingProposals(false);
    }
  }, [publicClient, governorAddress, isGovernorDeployed]);

  // Fetch proposals on mount and when dependencies change
  useEffect(() => {
    fetchProposals();
  }, [fetchProposals]);

  // Handle delegation
  const handleDelegate = async (delegatee: Address) => {
    if (!isTokenDeployed) return;

    setIsDelegating(true);
    try {
      writeContract({
        address: tokenAddress,
        abi: tokenAbi,
        functionName: "delegate",
        args: [delegatee],
      });
    } catch (error) {
      console.error("Delegation failed:", error);
      setIsDelegating(false);
    }
  };

  const isLoading = isLoadingVotingPower || isLoadingTotalSupply;
  const activeProposals = proposals.filter((p) => p.state === "active");

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
          <Button disabled={!isGovernorDeployed}>
            <Plus className="mr-2 h-4 w-4" />
            Create Proposal
          </Button>
        </Link>
      </div>

      {/* Governor not deployed warning */}
      {!isGovernorDeployed && (
        <div className="mb-6 p-4 bg-yellow-100 dark:bg-yellow-900/20 border border-yellow-300 dark:border-yellow-700 rounded-lg">
          <p className="text-yellow-800 dark:text-yellow-200">
            The Governor contract is not yet deployed on this network. Governance features will be available after deployment.
          </p>
        </div>
      )}

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
                proposals={proposals}
                isLoading={isLoadingProposals}
              />
            </TabsContent>

            <TabsContent value="delegate" className="mt-6">
              <DelegateVoting
                votingPower={votingPower as bigint | undefined}
                currentDelegate={currentDelegate as Address | undefined}
                selfAddress={userAddress}
                onDelegate={handleDelegate}
                disabled={isDelegating || isDelegatePending || isDelegateConfirming || !isTokenDeployed}
              />
            </TabsContent>
          </Tabs>
        </div>

        {/* Sidebar - 1 column */}
        <div className="space-y-6">
          <VotingPowerCard
            votingPower={votingPower as bigint | undefined}
            totalVotingPower={totalSupply as bigint | undefined}
            delegatedTo={currentDelegate as Address | undefined}
            isLoading={isLoading}
          />

          {/* Quick Stats */}
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-muted rounded-lg text-center">
              <p className="text-2xl font-bold">
                {isLoadingProposals ? "-" : proposals.length}
              </p>
              <p className="text-sm text-muted-foreground">Total Proposals</p>
            </div>
            <div className="p-4 bg-muted rounded-lg text-center">
              <p className="text-2xl font-bold">
                {isLoadingProposals ? "-" : activeProposals.length}
              </p>
              <p className="text-sm text-muted-foreground">Active</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
