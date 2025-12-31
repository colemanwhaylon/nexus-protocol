import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function GovernancePage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Governance</h1>
        <p className="text-muted-foreground">
          Participate in protocol governance through proposals and voting
        </p>
      </div>

      <div className="grid gap-6">
        {/* Proposals list placeholder */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Active Proposals</span>
              <Badge variant="outline">Coming Soon</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground">
              Governance proposals will appear here. Connect your wallet and stake tokens to participate.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
