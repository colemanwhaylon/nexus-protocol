"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Wallet, TrendingUp, Calendar } from "lucide-react";
import { formatUnits } from "viem";

interface StakingPositionProps {
  stakedAmount?: bigint;
  stakingShare?: number; // percentage of total pool
  startTime?: number;
  estimatedRewards?: bigint;
  isLoading?: boolean;
}

export function StakingPosition({
  stakedAmount = 0n,
  stakingShare = 0,
  startTime,
  estimatedRewards = 0n,
  isLoading,
}: StakingPositionProps) {
  const formattedStaked = formatUnits(stakedAmount, 18);
  const formattedRewards = formatUnits(estimatedRewards, 18);
  const hasPosition = stakedAmount > 0n;

  const stakingDuration = startTime
    ? Math.floor((Date.now() / 1000 - startTime) / 86400)
    : 0;

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Your Position</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <Skeleton className="h-20 w-full" />
          <div className="grid grid-cols-2 gap-4">
            <Skeleton className="h-16" />
            <Skeleton className="h-16" />
          </div>
        </CardContent>
      </Card>
    );
  }

  if (!hasPosition) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Your Position</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <Wallet className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
            <p className="text-muted-foreground">
              You have no staked tokens yet
            </p>
            <p className="text-sm text-muted-foreground mt-1">
              Stake NEXUS to start earning rewards
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          Your Position
          <Badge variant="default">Active</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-center p-4 bg-muted rounded-lg">
          <p className="text-sm text-muted-foreground">Staked Amount</p>
          <p className="text-3xl font-bold">
            {parseFloat(formattedStaked).toLocaleString()}
          </p>
          <p className="text-sm text-muted-foreground">NEXUS</p>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="p-3 border rounded-lg">
            <div className="flex items-center gap-2 mb-1">
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
              <span className="text-sm text-muted-foreground">Pool Share</span>
            </div>
            <p className="text-lg font-semibold">{stakingShare.toFixed(4)}%</p>
          </div>

          <div className="p-3 border rounded-lg">
            <div className="flex items-center gap-2 mb-1">
              <Calendar className="h-4 w-4 text-muted-foreground" />
              <span className="text-sm text-muted-foreground">Duration</span>
            </div>
            <p className="text-lg font-semibold">{stakingDuration} days</p>
          </div>
        </div>

        <div className="p-3 bg-green-500/10 border border-green-500/20 rounded-lg">
          <div className="flex items-center justify-between">
            <span className="text-sm text-green-600 dark:text-green-400">
              Estimated Daily Rewards
            </span>
            <span className="font-medium text-green-600 dark:text-green-400">
              +{parseFloat(formattedRewards).toFixed(4)} NEXUS
            </span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
