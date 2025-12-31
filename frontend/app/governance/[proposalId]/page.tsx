import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

interface Props {
  params: { proposalId: string };
}

export default function ProposalDetailPage({ params }: Props) {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <Badge variant="outline" className="mb-2">Proposal #{params.proposalId}</Badge>
        <h1 className="text-3xl font-bold">Proposal Details</h1>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Description</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground">
              Proposal details and voting interface coming soon.
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Voting</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground">
              Cast your vote here.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
