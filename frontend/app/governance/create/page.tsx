import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export default function CreateProposalPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Create Proposal</h1>
        <p className="text-muted-foreground">
          Submit a new governance proposal for the community to vote on
        </p>
      </div>

      <Card className="max-w-2xl">
        <CardHeader>
          <CardTitle>New Proposal</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-muted-foreground">
            Proposal creation form coming soon. You will need sufficient voting power to create proposals.
          </p>
          <Button disabled>Create Proposal</Button>
        </CardContent>
      </Card>
    </div>
  );
}
