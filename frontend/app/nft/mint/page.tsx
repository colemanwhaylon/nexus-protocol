import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function MintPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Mint Nexus NFT</h1>
        <p className="text-muted-foreground">
          Mint your exclusive Nexus NFT to unlock protocol benefits
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              Mint Status
              <Badge>Not Started</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Price</span>
                <span className="font-medium">0.05 ETH</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Max per wallet</span>
                <span className="font-medium">5</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Remaining</span>
                <span className="font-medium">10,000</span>
              </div>
            </div>
            <Button className="w-full" disabled>
              Minting Not Active
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>NFT Benefits</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-muted-foreground">
              <li>• 10% boost to staking rewards</li>
              <li>• 1.5x governance voting power</li>
              <li>• Access to exclusive features</li>
              <li>• Early access to new protocol features</li>
              <li>• Community events and airdrops</li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
