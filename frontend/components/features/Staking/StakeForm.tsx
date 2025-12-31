"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Loader2, ArrowRight } from "lucide-react";
import { formatUnits, parseUnits } from "viem";

interface StakeFormProps {
  balance?: bigint;
  onStake?: (amount: bigint) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function StakeForm({ balance = 0n, onStake, isLoading, disabled }: StakeFormProps) {
  const [amount, setAmount] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const formattedBalance = formatUnits(balance, 18);
  const parsedAmount = amount ? parseUnits(amount, 18) : 0n;
  const isValidAmount = parsedAmount > 0n && parsedAmount <= balance;

  const handleMax = () => {
    setAmount(formattedBalance);
  };

  const handleStake = async () => {
    if (!onStake || !isValidAmount) return;
    
    setIsSubmitting(true);
    try {
      await onStake(parsedAmount);
      setAmount("");
    } catch (error) {
      console.error("Stake failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const percentageButtons = [25, 50, 75, 100];

  return (
    <Card>
      <CardHeader>
        <CardTitle>Stake NEXUS</CardTitle>
        <CardDescription>
          Stake your tokens to earn rewards and participate in governance
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="stake-amount">Amount</Label>
            <span className="text-sm text-muted-foreground">
              Balance: {parseFloat(formattedBalance).toLocaleString()} NEXUS
            </span>
          </div>
          <div className="relative">
            <Input
              id="stake-amount"
              type="number"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              disabled={disabled || isLoading}
              className="pr-20"
            />
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="absolute right-1 top-1 h-7"
              onClick={handleMax}
              disabled={disabled || isLoading}
            >
              MAX
            </Button>
          </div>
        </div>

        <div className="flex gap-2">
          {percentageButtons.map((pct) => (
            <Button
              key={pct}
              type="button"
              variant="outline"
              size="sm"
              className="flex-1"
              onClick={() => setAmount(formatUnits((balance * BigInt(pct)) / 100n, 18))}
              disabled={disabled || isLoading}
            >
              {pct}%
            </Button>
          ))}
        </div>

        <Button
          className="w-full"
          disabled={!isValidAmount || disabled || isSubmitting}
          onClick={handleStake}
        >
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Staking...
            </>
          ) : (
            <>
              Stake NEXUS
              <ArrowRight className="ml-2 h-4 w-4" />
            </>
          )}
        </Button>

        {amount && !isValidAmount && parsedAmount > balance && (
          <p className="text-sm text-destructive">Insufficient balance</p>
        )}
      </CardContent>
    </Card>
  );
}
