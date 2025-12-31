"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { TrendingUp, Coins, Users, Clock } from "lucide-react";
import { formatUnits } from "viem";

interface StakingStats {
  totalStaked: bigint;
  apy: number;
  totalStakers: number;
  unbondingPeriod: number;
}

interface StakingOverviewProps {
  stats?: StakingStats;
  isLoading?: boolean;
}

export function StakingOverview({ stats, isLoading }: StakingOverviewProps) {
  const cards = [
    {
      title: "Total Staked",
      value: stats ? `${formatUnits(stats.totalStaked, 18)} NEXUS` : "0 NEXUS",
      icon: Coins,
      description: "Total tokens in staking pool",
    },
    {
      title: "Current APY",
      value: stats ? `${(stats.apy / 100).toFixed(2)}%` : "0%",
      icon: TrendingUp,
      description: "Annual percentage yield",
      highlight: true,
    },
    {
      title: "Total Stakers",
      value: stats?.totalStakers?.toLocaleString() ?? "0",
      icon: Users,
      description: "Active staking participants",
    },
    {
      title: "Unbonding Period",
      value: stats ? `${stats.unbondingPeriod / 86400} days` : "7 days",
      icon: Clock,
      description: "Time to unlock staked tokens",
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      {cards.map((card) => (
        <Card key={card.title}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">{card.title}</CardTitle>
            <card.icon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-8 w-24" />
            ) : (
              <div
                className={`text-2xl font-bold ${card.highlight ? "text-green-500" : ""}`}
              >
                {card.value}
              </div>
            )}
            <p className="text-xs text-muted-foreground">{card.description}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
