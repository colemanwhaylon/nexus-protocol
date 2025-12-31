import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function EmergencyPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Emergency Controls</h1>
        <p className="text-muted-foreground">
          Protocol pause and circuit breaker management
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              Protocol Status
              <Badge variant="default">Active</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-muted-foreground">
              Emergency pause controls for protocol contracts.
            </p>
            <Button variant="destructive" disabled>Pause Protocol</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              Circuit Breaker
              <Badge variant="outline">Normal</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-muted-foreground">
              Automatic circuit breaker status and controls.
            </p>
            <Button variant="outline" disabled>View Thresholds</Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
