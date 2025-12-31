import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export default function CompliancePage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">KYC Compliance</h1>
        <p className="text-muted-foreground">
          Manage KYC requests and whitelist status
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Pending Requests</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground mb-4">
            KYC management interface coming soon.
          </p>
          <Button disabled>Review Requests</Button>
        </CardContent>
      </Card>
    </div>
  );
}
