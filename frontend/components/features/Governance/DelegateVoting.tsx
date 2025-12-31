"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Loader2, Users, ArrowRight, UserCheck } from "lucide-react";
import { formatUnits, isAddress } from "viem";
import type { Address } from "viem";

interface DelegateVotingProps {
  votingPower?: bigint;
  currentDelegate?: Address;
  selfAddress?: Address;
  onDelegate?: (delegatee: Address) => Promise<void>;
  disabled?: boolean;
}

export function DelegateVoting({
  votingPower = 0n,
  currentDelegate,
  selfAddress,
  onDelegate,
  disabled,
}: DelegateVotingProps) {
  const [delegatee, setDelegatee] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const formattedPower = formatUnits(votingPower, 18);
  const isValidAddress = delegatee === "" || isAddress(delegatee);
  const isSelfDelegated = currentDelegate === selfAddress;
  const hasDelegated = currentDelegate && !isSelfDelegated;

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const handleDelegate = async () => {
    if (!onDelegate || !isAddress(delegatee)) return;

    setIsSubmitting(true);
    try {
      await onDelegate(delegatee as Address);
      setDelegatee("");
    } catch (error) {
      console.error("Delegation failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSelfDelegate = async () => {
    if (!onDelegate || !selfAddress) return;

    setIsSubmitting(true);
    try {
      await onDelegate(selfAddress);
    } catch (error) {
      console.error("Self-delegation failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Users className="h-5 w-5" />
          Delegate Voting Power
        </CardTitle>
        <CardDescription>
          Delegate your voting power to yourself or another address
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="p-4 bg-muted rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Your Voting Power</p>
              <p className="text-2xl font-bold">
                {parseFloat(formattedPower).toLocaleString()} NEXUS
              </p>
            </div>
            {hasDelegated && (
              <Badge variant="secondary">
                <UserCheck className="mr-1 h-3 w-3" />
                Delegated
              </Badge>
            )}
            {isSelfDelegated && (
              <Badge variant="default">
                <UserCheck className="mr-1 h-3 w-3" />
                Self-delegated
              </Badge>
            )}
          </div>
        </div>

        {currentDelegate && (
          <div className="p-3 border rounded-lg">
            <p className="text-sm text-muted-foreground">Current Delegate</p>
            <p className="font-mono">
              {isSelfDelegated ? "Yourself" : shortenAddress(currentDelegate)}
            </p>
          </div>
        )}

        <div className="space-y-2">
          <Label htmlFor="delegatee">Delegate To</Label>
          <Input
            id="delegatee"
            placeholder="0x... or leave empty for self-delegation"
            value={delegatee}
            onChange={(e) => setDelegatee(e.target.value)}
            disabled={disabled || isSubmitting}
            className={!isValidAddress ? "border-destructive" : ""}
          />
          {!isValidAddress && (
            <p className="text-sm text-destructive">Invalid address format</p>
          )}
        </div>

        <div className="grid grid-cols-2 gap-2">
          <Button
            variant="outline"
            disabled={isSelfDelegated || disabled || isSubmitting}
            onClick={handleSelfDelegate}
          >
            {isSubmitting && !delegatee ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <UserCheck className="mr-2 h-4 w-4" />
            )}
            Self-delegate
          </Button>

          <Button
            disabled={!isAddress(delegatee) || disabled || isSubmitting}
            onClick={handleDelegate}
          >
            {isSubmitting && delegatee ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <ArrowRight className="mr-2 h-4 w-4" />
            )}
            Delegate
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
