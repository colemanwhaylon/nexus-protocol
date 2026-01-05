"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { ArrowLeft, Info, AlertTriangle } from "lucide-react";
import { CreateProposalForm } from "@/components/features/Governance";
import {
  useAccount,
  useReadContract,
} from "wagmi";
import { useContractAddresses } from "@/hooks/useContractAddresses";
import { useGovernance } from "@/hooks/useGovernance";
import { parseEther } from "viem";
import type { Address } from "viem";

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

interface ProposalAction {
  target: string;
  value: string;
  calldata: string;
}

export default function CreateProposalPage() {
  const router = useRouter();
  const { address: userAddress, isConnected } = useAccount();
  const { addresses, hasContract } = useContractAddresses();

  const tokenAddress = addresses.nexusToken;
  const isGovernorDeployed = hasContract('nexusGovernor');
  const isTokenDeployed = hasContract('nexusToken');

  const {
    createProposal,
    proposalThreshold,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
  } = useGovernance();

  // Read user's voting power from token contract
  const { data: votingPower, isLoading: isLoadingVotingPower } = useReadContract({
    address: tokenAddress,
    abi: tokenAbi,
    functionName: "getVotes",
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: isTokenDeployed && !!userAddress,
    },
  });

  // Redirect to governance page after successful creation
  useEffect(() => {
    if (isSuccess) {
      // Small delay to allow for transaction confirmation
      const timer = setTimeout(() => {
        router.push("/governance");
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [isSuccess, router]);

  const handleSubmit = async (
    title: string,
    description: string,
    actions: ProposalAction[]
  ) => {
    if (!isGovernorDeployed) return;

    // Reset any previous errors
    reset();

    // Convert actions to contract format
    const targets = actions.map((a) => a.target as Address);
    const values = actions.map((a) => {
      try {
        return parseEther(a.value || "0");
      } catch {
        return BigInt(0);
      }
    });
    const calldatas = actions.map((a) => (a.calldata || "0x") as `0x${string}`);

    createProposal({
      title,
      description,
      targets,
      values,
      calldatas,
    });
  };

  const hasEnoughPower = votingPower !== undefined && proposalThreshold !== undefined
    ? votingPower >= proposalThreshold
    : false;

  const isSubmitting = isPending || isConfirming;

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header with Back Button */}
      <div className="mb-8">
        <Link href="/governance">
          <Button variant="ghost" size="sm" className="mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Governance
          </Button>
        </Link>
        <h1 className="text-3xl font-bold">Create Proposal</h1>
        <p className="text-muted-foreground">
          Submit a new governance proposal for the community to vote on
        </p>
      </div>

      {/* Governor not deployed warning */}
      {!isGovernorDeployed && (
        <Alert variant="destructive" className="mb-6">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Governor Not Deployed</AlertTitle>
          <AlertDescription>
            The Governor contract is not yet deployed on this network. You cannot create proposals until deployment is complete.
          </AlertDescription>
        </Alert>
      )}

      {/* Not connected warning */}
      {!isConnected && (
        <Alert className="mb-6">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Wallet Not Connected</AlertTitle>
          <AlertDescription>
            Please connect your wallet to create a proposal.
          </AlertDescription>
        </Alert>
      )}

      {/* Transaction error */}
      {writeError && (
        <Alert variant="destructive" className="mb-6">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Transaction Failed</AlertTitle>
          <AlertDescription>
            {writeError.message || "Failed to create proposal. Please try again."}
          </AlertDescription>
        </Alert>
      )}

      {/* Transaction success */}
      {isSuccess && (
        <Alert className="mb-6 border-green-500 bg-green-50 dark:bg-green-900/20">
          <Info className="h-4 w-4 text-green-600" />
          <AlertTitle className="text-green-800 dark:text-green-200">Proposal Created!</AlertTitle>
          <AlertDescription className="text-green-700 dark:text-green-300">
            Your proposal has been submitted successfully. Redirecting to governance page...
          </AlertDescription>
        </Alert>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Main Form - 2 columns */}
        <div className="lg:col-span-2">
          <CreateProposalForm
            votingPower={votingPower as bigint | undefined}
            proposalThreshold={proposalThreshold}
            onSubmit={handleSubmit}
            disabled={isSubmitting || !isGovernorDeployed || !isConnected}
          />
        </div>

        {/* Sidebar - Guidelines */}
        <div className="space-y-6">
          {/* Eligibility Alert */}
          {isConnected && !isLoadingVotingPower && !hasEnoughPower && (
            <Alert variant="destructive">
              <AlertTriangle className="h-4 w-4" />
              <AlertTitle>Insufficient Voting Power</AlertTitle>
              <AlertDescription>
                You need at least {proposalThreshold ? (Number(proposalThreshold) / 1e18).toLocaleString() : "50,000"} NEXUS voting power to create a proposal.
                Stake more tokens or receive delegations to reach the threshold.
              </AlertDescription>
            </Alert>
          )}

          {/* Guidelines Card */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Info className="h-5 w-5" />
                Proposal Guidelines
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <h4 className="font-medium mb-1">Title</h4>
                <p className="text-sm text-muted-foreground">
                  Keep it clear and descriptive. This is the first thing voters will see.
                </p>
              </div>

              <div>
                <h4 className="font-medium mb-1">Description</h4>
                <p className="text-sm text-muted-foreground">
                  Explain the rationale, expected outcomes, and any risks. Include
                  relevant links or data to support your proposal.
                </p>
              </div>

              <div>
                <h4 className="font-medium mb-1">Actions</h4>
                <p className="text-sm text-muted-foreground">
                  Each action specifies a contract call. Ensure addresses and
                  calldata are correct - they cannot be changed after submission.
                </p>
              </div>

              <div className="pt-2 border-t">
                <h4 className="font-medium mb-1">Voting Process</h4>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>- Voting period: 7 days</li>
                  <li>- Quorum required: 4% of total supply</li>
                  <li>- Timelock delay: 48 hours</li>
                </ul>
              </div>
            </CardContent>
          </Card>

          {/* Tips Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Tips for Success</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground space-y-2">
              <p>
                1. Discuss your proposal in the forum before submitting
              </p>
              <p>
                2. Be responsive to questions and feedback during voting
              </p>
              <p>
                3. Consider starting with smaller, less controversial proposals
              </p>
              <p>
                4. Ensure actions are thoroughly tested on testnet first
              </p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
