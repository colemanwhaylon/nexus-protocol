import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

interface Props {
  params: { tokenId: string };
}

export default function NFTDetailPage({ params }: Props) {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <Badge variant="outline" className="mb-2">Token #{params.tokenId}</Badge>
        <h1 className="text-3xl font-bold">Nexus NFT #{params.tokenId}</h1>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardContent className="p-6">
            <div className="aspect-square bg-muted rounded-lg flex items-center justify-center">
              <span className="text-muted-foreground">NFT Image</span>
            </div>
          </CardContent>
        </Card>

        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Token ID</span>
                <span className="font-medium">#{params.tokenId}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Owner</span>
                <span className="font-medium">--</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Rarity</span>
                <Badge variant="secondary">Common</Badge>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Attributes</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground">
                NFT attributes will be displayed here after reveal.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Actions</CardTitle>
            </CardHeader>
            <CardContent className="space-x-2">
              <Button variant="outline" disabled>Transfer</Button>
              <Button variant="outline" disabled>List for Sale</Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
