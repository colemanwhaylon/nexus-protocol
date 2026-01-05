"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { ArrowLeft, Share2, ExternalLink, AlertTriangle, Loader2 } from "lucide-react";
import {
  ProposalDetail,
  ProposalTimeline,
  ProposalActions,
  VotingPanel,
  VoteResults,
} from "@/components/features/Governance";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useBlockNumber,
} from "wagmi";
import { useContractAddresses } from "@/hooks/useContractAddresses";
import { useGovernance, VoteSupport } from "@/hooks/useGovernance";
import { parseAbiItem } from "viem";
import type { Address } from "viem";

type VoteType = "for" | "against" | "abstain";

interface Props {
  params: { proposalId: string };
}

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
  {
    name: "proposalSnapshot",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "proposalProposer",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "address" }],
  },
  {
    name: "hasVoted",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "proposalId", type: "uint256" },
      { name: "account", type: "address" },
    ],
    outputs: [{ type: "bool" }],
  },
  {
    name: "quorum",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "blockNumber", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
  {
    name: "proposalEta",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

// Token ABI for reading voting power
const tokenAbi = [
  {
    name: "getVotes",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

interface ProposalData {
  id: string;
  title: string;
  description: string;
  proposer: Address;
  state: "Pending" | "Active" | "Canceled" | "Defeated" | "Succeeded" | "Queued" | "Expired" | "Executed";
  forVotes: bigint;
  againstVotes: bigint;
  abstainVotes: bigint;
  startBlock: number;
  endBlock: number;
  createdAt: number;
  votingStartedAt: number;
  quorum: bigint;
  eta?: number; // Execution timestamp for queued proposals
  actions: {
    target: string;
    value: bigint;
    calldata: string;
    signature?: string;
  }[];
  // Raw data for queue/execute/cancel operations
  targets: Address[];
  values: bigint[];
  calldatas: `0x${string}`[];
  fullDescription: string;
}

// Map numeric state to display state
const stateDisplayMap: Record<number, ProposalData["state"]> = {
  0: "Pending",
  1: "Active",
  2: "Canceled",
  3: "Defeated",
  4: "Succeeded",
  5: "Queued",
  6: "Expired",
  7: "Executed",
};

export default function ProposalDetailPage({ params }: Props) {
  const { address: userAddress } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const { addresses, hasContract } = useContractAddresses();

  const governorAddress = addresses.nexusGovernor;
  const tokenAddress = addresses.nexusToken;
  const isGovernorDeployed = hasContract('nexusGovernor');
  const isTokenDeployed = hasContract('nexusToken');

  // Get current block number for progress tracking
  const { data: currentBlock } = useBlockNumber({ watch: true });

  // Get current block timestamp for accurate timelock comparison
  const [blockTimestamp, setBlockTimestamp] = useState<number | undefined>();

  // Fetch block timestamp when block number changes
  useEffect(() => {
    async function fetchBlockTimestamp() {
      if (publicClient && currentBlock) {
        try {
          const block = await publicClient.getBlock({ blockNumber: currentBlock });
          setBlockTimestamp(Number(block.timestamp));
        } catch (e) {
          console.warn("Could not fetch block timestamp:", e);
        }
      }
    }
    fetchBlockTimestamp();
  }, [publicClient, currentBlock]);

  const [proposal, setProposal] = useState<ProposalData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [currentVote, setCurrentVote] = useState<VoteType | undefined>();

  const proposalIdBigInt = BigInt(params.proposalId);

  const {
    castVote,
    queue,
    execute,
    cancel,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
  } = useGovernance();

  // Read user's voting power
  const { data: votingPower } = useReadContract({
    address: tokenAddress,
    abi: tokenAbi,
    functionName: "getVotes",
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: isTokenDeployed && !!userAddress,
    },
  });

  // Check if user has voted
  const { data: hasVotedData, refetch: refetchHasVoted } = useReadContract({
    address: governorAddress,
    abi: governorAbi,
    functionName: "hasVoted",
    args: userAddress ? [proposalIdBigInt, userAddress] : undefined,
    query: {
      enabled: isGovernorDeployed && !!userAddress,
    },
  });

  const hasVoted = hasVotedData as boolean | undefined;

  // Fetch proposal data from contract events
  const fetchProposal = useCallback(async () => {
    if (!publicClient || !isGovernorDeployed) {
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setLoadError(null);

    try {
      // Get the current block number to calculate a safe range
      // Most RPC providers limit getLogs to ~50000 blocks
      const latestBlock = await publicClient.getBlockNumber();
      const maxBlockRange = 45000n; // Stay under the 50000 limit
      const fromBlock = latestBlock > maxBlockRange ? latestBlock - maxBlockRange : 0n;

      // Get ProposalCreated event for this specific proposal
      const logs = await publicClient.getLogs({
        address: governorAddress,
        event: parseAbiItem(
          "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)"
        ),
        fromBlock,
        toBlock: "latest",
      });

      // Find the log for this proposal ID
      const proposalLog = logs.find(
        (log) => log.args.proposalId?.toString() === params.proposalId
      );

      if (!proposalLog) {
        setLoadError("Proposal not found");
        setIsLoading(false);
        return;
      }

      const proposalId = proposalLog.args.proposalId as bigint;
      const description = proposalLog.args.description as string;
      const targets = proposalLog.args.targets as Address[];
      const values = proposalLog.args.values as bigint[];
      const calldatas = proposalLog.args.calldatas as `0x${string}`[];
      const signatures = proposalLog.args.signatures as string[];
      const proposer = proposalLog.args.proposer as Address;
      const voteStart = proposalLog.args.voteStart as bigint;
      const voteEnd = proposalLog.args.voteEnd as bigint;

      // Extract title from description (first line or before ##)
      const titleMatch = description.match(/^#\s*(.+)/m);
      const title = titleMatch ? titleMatch[1] : description.split("\n")[0] || `Proposal #${proposalId.toString()}`;

      // Get proposal state
      const stateResult = await publicClient.readContract({
        address: governorAddress,
        abi: governorAbi,
        functionName: "state",
        args: [proposalId],
      });

      // Get proposal eta (execution timestamp) if queued
      let eta: number | undefined;
      const stateNum = Number(stateResult);
      if (stateNum === 5) { // 5 = Queued
        try {
          const etaResult = await publicClient.readContract({
            address: governorAddress,
            abi: governorAbi,
            functionName: "proposalEta",
            args: [proposalId],
          });
          eta = Number(etaResult);
        } catch (e) {
          console.warn("Could not fetch proposal eta:", e);
        }
      }

      // Get proposal votes
      const votesResult = await publicClient.readContract({
        address: governorAddress,
        abi: governorAbi,
        functionName: "proposalVotes",
        args: [proposalId],
      });

      const [againstVotes, forVotes, abstainVotes] = votesResult as [bigint, bigint, bigint];

      // Get quorum at the snapshot block
      let quorum = BigInt(0);
      try {
        quorum = await publicClient.readContract({
          address: governorAddress,
          abi: governorAbi,
          functionName: "quorum",
          args: [voteStart],
        }) as bigint;
      } catch {
        // Quorum might not be available for all blocks
        console.warn("Could not fetch quorum");
      }

      // Build actions array
      const actions = targets.map((target, index) => ({
        target,
        value: values[index],
        calldata: calldatas[index],
        signature: signatures[index] || undefined,
      }));

      // Estimate timestamps based on block numbers (assuming ~12s per block on Ethereum)
      const currentBlock = await publicClient.getBlockNumber();
      const currentTimestamp = Math.floor(Date.now() / 1000);

      // Rough estimate for creation time
      const blocksSinceVoteStart = Number(currentBlock) - Number(voteStart);
      const createdAt = currentTimestamp - (blocksSinceVoteStart * 12) - 86400; // Subtract a day for voting delay
      const votingStartedAt = currentTimestamp - (blocksSinceVoteStart * 12);

      setProposal({
        id: proposalId.toString(),
        title,
        description,
        proposer,
        state: stateDisplayMap[Number(stateResult)] || "Pending",
        forVotes,
        againstVotes,
        abstainVotes,
        startBlock: Number(voteStart),
        endBlock: Number(voteEnd),
        createdAt,
        votingStartedAt,
        quorum,
        eta, // Execution timestamp for queued proposals
        actions,
        // Raw data for operations
        targets,
        values,
        calldatas,
        fullDescription: description,
      });
    } catch (error) {
      console.error("Error fetching proposal:", error);
      setLoadError("Failed to load proposal data");
    } finally {
      setIsLoading(false);
    }
  }, [publicClient, governorAddress, isGovernorDeployed, params.proposalId]);

  // Fetch proposal on mount
  useEffect(() => {
    fetchProposal();
  }, [fetchProposal]);

  // Refetch data after successful transaction
  useEffect(() => {
    if (isSuccess) {
      refetchHasVoted();
      fetchProposal();
    }
  }, [isSuccess, refetchHasVoted, fetchProposal]);

  const handleVote = async (vote: VoteType) => {
    reset();

    const support = vote === "for" ? VoteSupport.For
      : vote === "against" ? VoteSupport.Against
      : VoteSupport.Abstain;

    castVote(proposalIdBigInt, support);
    setCurrentVote(vote);
  };

  const handleQueue = async () => {
    if (!proposal) return;
    reset();

    queue({
      targets: proposal.targets,
      values: proposal.values,
      calldatas: proposal.calldatas,
      description: proposal.fullDescription,
    });
  };

  const handleExecute = async () => {
    if (!proposal) return;
    reset();

    execute({
      targets: proposal.targets,
      values: proposal.values,
      calldatas: proposal.calldatas,
      description: proposal.fullDescription,
    });
  };

  const handleCancel = async () => {
    if (!proposal) return;
    reset();

    cancel({
      targets: proposal.targets,
      values: proposal.values,
      calldatas: proposal.calldatas,
      description: proposal.fullDescription,
    });
  };

  const handleShare = async () => {
    const url = window.location.href;
    try {
      await navigator.clipboard.writeText(url);
      // In production, show a toast notification
    } catch {
      console.error("Failed to copy link");
    }
  };

  const getExplorerUrl = () => {
    const baseUrl = chainId === 1
      ? "https://etherscan.io"
      : chainId === 11155111
        ? "https://sepolia.etherscan.io"
        : "";
    return baseUrl ? `${baseUrl}/tx/${params.proposalId}` : "#";
  };

  const isTransacting = isPending || isConfirming;

  // Loading state
  if (isLoading) {
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

  // Error state
  if (loadError || !proposal) {
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
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Error Loading Proposal</AlertTitle>
          <AlertDescription>
            {loadError || "Could not find proposal with this ID."}
          </AlertDescription>
        </Alert>
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
            href={getExplorerUrl()}
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

      {/* Block Progress Indicator */}
      {proposal && currentBlock !== undefined && (
        <div className="mb-6 p-4 bg-muted rounded-lg">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium">Block Progress</span>
            <span className="text-sm text-muted-foreground">
              Current Block: <span className="font-mono font-bold">{currentBlock.toLocaleString()}</span>
            </span>
          </div>
          <div className="w-full bg-secondary rounded-full h-2 mb-2">
            <div
              className={`h-2 rounded-full transition-all ${
                proposal.state === "Active" ? "bg-blue-500" :
                proposal.state === "Succeeded" ? "bg-green-500" :
                proposal.state === "Defeated" ? "bg-red-500" :
                "bg-primary"
              }`}
              style={{
                width: `${Math.min(100, Math.max(0,
                  proposal.state === "Pending"
                    ? ((Number(currentBlock) - (proposal.startBlock - 7200)) / 7200) * 100
                    : ((Number(currentBlock) - proposal.startBlock) / (proposal.endBlock - proposal.startBlock)) * 100
                ))}%`
              }}
            />
          </div>
          <div className="flex justify-between text-xs text-muted-foreground">
            <span>Start: {proposal.startBlock.toLocaleString()}</span>
            <span>End: {proposal.endBlock.toLocaleString()}</span>
          </div>
          {proposal.state === "Active" && Number(currentBlock) < proposal.endBlock && (
            <p className="text-xs text-muted-foreground mt-1">
              ~{(proposal.endBlock - Number(currentBlock)).toLocaleString()} blocks remaining
            </p>
          )}
        </div>
      )}

      {/* Transaction error */}
      {writeError && (
        <Alert variant="destructive" className="mb-6">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Transaction Failed</AlertTitle>
          <AlertDescription>
            {writeError.message || "Failed to process transaction. Please try again."}
          </AlertDescription>
        </Alert>
      )}

      {/* Transaction pending */}
      {isTransacting && (
        <Alert className="mb-6">
          <Loader2 className="h-4 w-4 animate-spin" />
          <AlertTitle>Transaction Pending</AlertTitle>
          <AlertDescription>
            Please confirm the transaction in your wallet and wait for confirmation...
          </AlertDescription>
        </Alert>
      )}

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
            chainId={chainId}
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
            votingPower={votingPower as bigint | undefined}
            hasVoted={hasVoted ?? false}
            currentVote={hasVoted ? currentVote : undefined}
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
            currentUser={userAddress}
            eta={proposal.eta}
            blockTimestamp={blockTimestamp}
            isAdmin={false} // TODO: Check if user has admin role from AccessControl contract
            onQueue={handleQueue}
            onExecute={handleExecute}
            onCancel={handleCancel}
          />
        </div>
      </div>
    </div>
  );
}
