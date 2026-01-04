"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Loader2, ArrowRight, Clock } from "lucide-react";
import { formatUnits, parseUnits } from "viem";

interface UnstakeFormProps {
  stakedBalance?: bigint;
  unbondingPeriod?: number; // in seconds
  onUnstake?: (amount: bigint) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function UnstakeForm({
  stakedBalance = 0n,
  unbondingPeriod = 604800, // 7 days default
  onUnstake,
  isLoading,
  disabled,
}: UnstakeFormProps) {
  const [amount, setAmount] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const formattedBalance = formatUnits(stakedBalance, 18);
  const parsedAmount = amount ? parseUnits(amount, 18) : 0n;
  const isValidAmount = parsedAmount > 0n && parsedAmount <= stakedBalance;
  const unbondingDays = Math.ceil(unbondingPeriod / 86400);

  const handleMax = () => {
    setAmount(formattedBalance);
  };

  const handleUnstake = async () => {
    if (!onUnstake || !isValidAmount) return;

    setIsSubmitting(true);
    try {
      await onUnstake(parsedAmount);
      setAmount("");
    } catch (error) {
      console.error("Unstake failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          Unstake NEXUS
          <Badge variant="outline">
            <Clock className="mr-1 h-3 w-3" />
            {unbondingDays} day unbonding
          </Badge>
        </CardTitle>
        <CardDescription>
          Unstaked tokens enter an unbonding period before withdrawal
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="unstake-amount">Amount</Label>
            <span className="text-sm text-muted-foreground">
              Staked: {parseFloat(formattedBalance).toLocaleString()} NEXUS
            </span>
          </div>
          <div className="relative">
            <Input
              id="unstake-amount"
              type="number"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              disabled={disabled || isLoading || stakedBalance === 0n}
              className="pr-20"
            />
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="absolute right-1 top-1 h-7"
              onClick={handleMax}
              disabled={disabled || isLoading || stakedBalance === 0n}
            >
              MAX
            </Button>
          </div>
        </div>

        {isValidAmount && (
          <div className="p-3 bg-muted rounded-lg text-sm">
            <p className="text-muted-foreground">
              Your tokens will be available for withdrawal on{" "}
              <span className="font-medium text-foreground">
                {new Date(Date.now() + unbondingPeriod * 1000).toLocaleDateString()}
              </span>
            </p>
          </div>
        )}

        <Button
          className="w-full"
          disabled={!isValidAmount || disabled || isSubmitting}
          onClick={handleUnstake}
        >
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Unstaking...
            </>
          ) : (
            <>
              Unstake NEXUS
              <ArrowRight className="ml-2 h-4 w-4" />
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
}
