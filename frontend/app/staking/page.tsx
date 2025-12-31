import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export default function StakingPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Staking</h1>
        <p className="text-muted-foreground">
          Stake your NEXUS tokens to earn rewards and participate in governance
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Staked</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">0 NEXUS</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">APY</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-green-500">12.5%</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Your Stake</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">0 NEXUS</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Pending Rewards</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">0 NEXUS</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Stake Tokens</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-muted-foreground">
              Staking interface coming soon. Connect your wallet to stake tokens.
            </p>
            <Button disabled>Stake NEXUS</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              Unbonding Queue
              <Badge variant="outline">0 pending</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground">
              No unbonding requests. Unstaked tokens have a 7-day unbonding period.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
