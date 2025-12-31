'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Loader2, Shield, AlertTriangle } from 'lucide-react';
import { formatUnits, parseUnits, isAddress, maxUint256 } from 'viem';
import type { Address } from 'viem';

interface ApproveFormProps {
  balance?: bigint;
  symbol?: string;
  decimals?: number;
  currentAllowance?: bigint;
  spender?: Address;
  onApprove?: (spender: Address, amount: bigint) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function ApproveForm({
  balance = 0n,
  symbol = 'NEXUS',
  decimals = 18,
  currentAllowance = 0n,
  spender: defaultSpender,
  onApprove,
  isLoading,
  disabled,
}: ApproveFormProps) {
  const [spender, setSpender] = useState(defaultSpender || '');
  const [amount, setAmount] = useState('');
  const [isUnlimited, setIsUnlimited] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const formattedBalance = formatUnits(balance, decimals);
  const formattedAllowance = formatUnits(currentAllowance, decimals);
  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n;
  const isValidAddress = isAddress(spender);
  const approveAmount = isUnlimited ? maxUint256 : parsedAmount;
  const canSubmit = isValidAddress && (isUnlimited || parsedAmount > 0n) && !disabled && !isSubmitting;

  const handleApprove = async () => {
    if (!onApprove || !canSubmit) return;

    setIsSubmitting(true);
    try {
      await onApprove(spender as Address, approveAmount);
      setAmount('');
    } catch (error) {
      console.error('Approval failed:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Shield className="h-5 w-5" />
          Approve Spending
        </CardTitle>
        <CardDescription>
          Allow a contract to spend your {symbol} tokens
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="spender">Spender Address</Label>
          <Input
            id="spender"
            placeholder="0x..."
            value={spender}
            onChange={(e) => setSpender(e.target.value)}
            disabled={disabled || isLoading || !!defaultSpender}
            className={spender && !isValidAddress ? 'border-destructive' : ''}
          />
          {spender && !isValidAddress && (
            <p className="text-sm text-destructive">Invalid address format</p>
          )}
        </div>

        {currentAllowance > 0n && (
          <div className="p-3 bg-muted rounded-lg">
            <p className="text-sm text-muted-foreground">Current Allowance</p>
            <p className="font-medium">
              {currentAllowance === maxUint256
                ? 'Unlimited'
                : `${parseFloat(formattedAllowance).toLocaleString()} ${symbol}`}
            </p>
          </div>
        )}

        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="approve-amount">Amount</Label>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={isUnlimited}
                onChange={(e) => setIsUnlimited(e.target.checked)}
                disabled={disabled || isLoading}
              />
              Unlimited
            </label>
          </div>
          <Input
            id="approve-amount"
            type="number"
            placeholder="0.0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            disabled={disabled || isLoading || isUnlimited}
          />
          <p className="text-xs text-muted-foreground">
            Balance: {parseFloat(formattedBalance).toLocaleString()} {symbol}
          </p>
        </div>

        {isUnlimited && (
          <div className="flex items-start gap-2 p-3 bg-yellow-500/10 border border-yellow-500/20 rounded-lg">
            <AlertTriangle className="h-4 w-4 text-yellow-500 mt-0.5" />
            <p className="text-sm text-yellow-600 dark:text-yellow-400">
              Unlimited approval allows the spender to transfer all your tokens.
              Only approve trusted contracts.
            </p>
          </div>
        )}

        <Button
          className="w-full"
          disabled={!canSubmit}
          onClick={handleApprove}
        >
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Approving...
            </>
          ) : (
            <>
              <Shield className="mr-2 h-4 w-4" />
              Approve {isUnlimited ? 'Unlimited' : symbol}
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
}
