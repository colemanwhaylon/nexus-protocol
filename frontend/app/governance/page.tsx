"use client";

import { useState, useEffect, useCallback, Suspense } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Plus, RefreshCw } from "lucide-react";
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
import { useContractAddresses } from "@/hooks/useContractAddresses";
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

function GovernancePageContent() {
  const { address: userAddress } = useAccount();
  useChainId(); // Required for wagmi context
  const publicClient = usePublicClient();
  const searchParams = useSearchParams();
  const { addresses, isLoading: isLoadingAddresses, hasContract } = useContractAddresses();

  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [isLoadingProposals, setIsLoadingProposals] = useState(true);
  const [isDelegating, setIsDelegating] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Get refresh param (used to trigger refetch after proposal creation)
  const refreshParam = searchParams.get("refresh");

  const governorAddress = addresses.nexusGovernor;
  const tokenAddress = addresses.nexusToken;
  // Only show "not deployed" after addresses have loaded
  const isGovernorDeployed = !isLoadingAddresses && hasContract('nexusGovernor');
  const isTokenDeployed = !isLoadingAddresses && hasContract('nexusToken');
  // Show loading state while addresses are being fetched
  const isAddressesReady = !isLoadingAddresses && !!governorAddress;

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
    if (!publicClient || !isAddressesReady) {
      setIsLoadingProposals(false);
      return;
    }

    setIsLoadingProposals(true);

    try {
      // Get the current block number to calculate a safe range
      // Most RPC providers limit getLogs to ~50000 blocks
      const currentBlock = await publicClient.getBlockNumber();
      const maxBlockRange = 45000n; // Stay under the 50000 limit
      const fromBlock = currentBlock > maxBlockRange ? currentBlock - maxBlockRange : 0n;

      // Get ProposalCreated events from the governor contract
      const logs = await publicClient.getLogs({
        address: governorAddress,
        event: parseAbiItem(
          "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)"
        ),
        fromBlock,
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
  }, [publicClient, governorAddress, isAddressesReady]);

  // Fetch proposals on mount and when dependencies change
  // Also refetch when refreshParam changes (e.g., after creating a proposal)
  useEffect(() => {
    fetchProposals();
  }, [fetchProposals, refreshParam]);

  // Manual refresh function with visual feedback
  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    await fetchProposals();
    setIsRefreshing(false);
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
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={handleRefresh}
            disabled={isRefreshing || isLoadingProposals}
            title="Refresh proposals"
          >
            <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          </Button>
          <Link href="/governance/create">
            <Button disabled={!isGovernorDeployed}>
              <Plus className="mr-2 h-4 w-4" />
              Create Proposal
            </Button>
          </Link>
        </div>
      </div>

      {/* Loading addresses state */}
      {isLoadingAddresses && (
        <div className="mb-6 p-4 bg-blue-100 dark:bg-blue-900/20 border border-blue-300 dark:border-blue-700 rounded-lg">
          <p className="text-blue-800 dark:text-blue-200">
            Loading contract addresses...
          </p>
        </div>
      )}

      {/* Governor not deployed warning - only show after addresses loaded */}
      {!isLoadingAddresses && !isGovernorDeployed && (
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

// Wrapper with Suspense for useSearchParams
export default function GovernancePage() {
  return (
    <Suspense fallback={
      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-center items-center h-64">
          <RefreshCw className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      </div>
    }>
      <GovernancePageContent />
    </Suspense>
  );
}
