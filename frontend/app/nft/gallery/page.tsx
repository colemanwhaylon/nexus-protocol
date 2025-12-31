import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function GalleryPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">NFT Gallery</h1>
        <p className="text-muted-foreground">
          Browse the Nexus NFT collection
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            Your Collection
            <Badge variant="outline">0 NFTs</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-12">
            <p className="text-muted-foreground mb-4">
              You do not own any Nexus NFTs yet.
            </p>
            <p className="text-sm text-muted-foreground">
              Connect your wallet and mint an NFT to get started.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
