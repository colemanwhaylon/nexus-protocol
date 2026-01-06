import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export default function NFTPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Nexus NFT Collection</h1>
        <p className="text-muted-foreground">
          Exclusive NFTs with staking benefits and governance perks
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Supply</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">10,000</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Minted</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">0</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Floor Price</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">-- ETH</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Your NFTs</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">0</p>
          </CardContent>
        </Card>
      </div>

      <div className="flex gap-4 mb-8">
        <Link href="/nft/mint">
          <Button>Mint NFT</Button>
        </Link>
        <Link href="/nft/gallery">
          <Button variant="outline">View Gallery</Button>
        </Link>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            Collection Info
            <Badge variant="default">Live</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">
            Nexus Genesis NFTs are exclusive collectibles in the Nexus ecosystem.
            Future protocol upgrades may introduce holder benefits such as boosted
            staking rewards and governance voting multipliers.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
