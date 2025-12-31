"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Loader2, Gift, Sparkles } from "lucide-react";
import { formatUnits } from "viem";

interface RewardsCardProps {
  pendingRewards?: bigint;
  lastClaimTime?: number;
  onClaim?: () => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function RewardsCard({
  pendingRewards = 0n,
  lastClaimTime,
  onClaim,
  isLoading,
  disabled,
}: RewardsCardProps) {
  const [isClaiming, setIsClaiming] = useState(false);

  const formattedRewards = formatUnits(pendingRewards, 18);
  const hasRewards = pendingRewards > 0n;

  const handleClaim = async () => {
    if (!onClaim || !hasRewards) return;

    setIsClaiming(true);
    try {
      await onClaim();
    } catch (error) {
      console.error("Claim failed:", error);
    } finally {
      setIsClaiming(false);
    }
  };

  const formatLastClaim = () => {
    if (!lastClaimTime) return "Never";
    const date = new Date(lastClaimTime * 1000);
    return date.toLocaleDateString();
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <span className="flex items-center gap-2">
            <Gift className="h-5 w-5" />
            Staking Rewards
          </span>
          {hasRewards && (
            <Badge variant="default" className="bg-green-500">
              <Sparkles className="mr-1 h-3 w-3" />
              Claimable
            </Badge>
          )}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-center p-4 bg-muted rounded-lg">
          {isLoading ? (
            <Skeleton className="h-10 w-32 mx-auto" />
          ) : (
            <>
              <p className="text-3xl font-bold">
                {parseFloat(formattedRewards).toLocaleString(undefined, {
                  maximumFractionDigits: 4,
                })}
              </p>
              <p className="text-sm text-muted-foreground">NEXUS</p>
            </>
          )}
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-muted-foreground">Last claimed</span>
          <span>{formatLastClaim()}</span>
        </div>

        <Button
          className="w-full"
          disabled={!hasRewards || disabled || isClaiming}
          onClick={handleClaim}
        >
          {isClaiming ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Claiming...
            </>
          ) : hasRewards ? (
            <>
              <Gift className="mr-2 h-4 w-4" />
              Claim Rewards
            </>
          ) : (
            "No Rewards to Claim"
          )}
        </Button>
      </CardContent>
    </Card>
  );
}
