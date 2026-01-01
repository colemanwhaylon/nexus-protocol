"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { ArrowLeft, Info, AlertTriangle } from "lucide-react";
import { CreateProposalForm } from "@/components/features/Governance";

interface ProposalAction {
  target: string;
  value: string;
  calldata: string;
}

export default function CreateProposalPage() {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Mock data - in production, this would come from contract calls and wallet connection
  const mockVotingPower = BigInt("100000000000000000000000"); // 100,000 NEXUS
  const mockProposalThreshold = BigInt("50000000000000000000000"); // 50,000 NEXUS
  const hasEnoughPower = mockVotingPower >= mockProposalThreshold;

  const handleSubmit = async (
    title: string,
    description: string,
    actions: ProposalAction[]
  ) => {
    setIsSubmitting(true);
    try {
      // In production, this would:
      // 1. Encode the actions into calldata
      // 2. Call the propose() function on the Governor contract
      // 3. Wait for transaction confirmation
      console.log("Creating proposal:", { title, description, actions });

      // Simulate transaction delay
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // Redirect to governance page after successful creation
      router.push("/governance");
    } catch (error) {
      console.error("Failed to create proposal:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

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

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Main Form - 2 columns */}
        <div className="lg:col-span-2">
          <CreateProposalForm
            votingPower={mockVotingPower}
            proposalThreshold={mockProposalThreshold}
            onSubmit={handleSubmit}
            disabled={isSubmitting}
          />
        </div>

        {/* Sidebar - Guidelines */}
        <div className="space-y-6">
          {/* Eligibility Alert */}
          {!hasEnoughPower && (
            <Alert variant="destructive">
              <AlertTriangle className="h-4 w-4" />
              <AlertTitle>Insufficient Voting Power</AlertTitle>
              <AlertDescription>
                You need at least 50,000 NEXUS voting power to create a proposal.
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
