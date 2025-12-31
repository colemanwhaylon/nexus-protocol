import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function RolesPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Role Management</h1>
        <p className="text-muted-foreground">
          Manage protocol roles and permissions
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Protocol Roles</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-3 border rounded">
              <div>
                <p className="font-medium">DEFAULT_ADMIN_ROLE</p>
                <p className="text-sm text-muted-foreground">Full administrative access</p>
              </div>
              <Badge>Active</Badge>
            </div>
            <div className="flex items-center justify-between p-3 border rounded">
              <div>
                <p className="font-medium">OPERATOR_ROLE</p>
                <p className="text-sm text-muted-foreground">Operational management</p>
              </div>
              <Badge variant="outline">1 member</Badge>
            </div>
            <div className="flex items-center justify-between p-3 border rounded">
              <div>
                <p className="font-medium">COMPLIANCE_ROLE</p>
                <p className="text-sm text-muted-foreground">KYC and compliance management</p>
              </div>
              <Badge variant="outline">1 member</Badge>
            </div>
            <div className="flex items-center justify-between p-3 border rounded">
              <div>
                <p className="font-medium">PAUSER_ROLE</p>
                <p className="text-sm text-muted-foreground">Emergency pause capability</p>
              </div>
              <Badge variant="outline">1 member</Badge>
            </div>
          </div>
          <div className="mt-4">
            <Button disabled>Grant Role</Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
