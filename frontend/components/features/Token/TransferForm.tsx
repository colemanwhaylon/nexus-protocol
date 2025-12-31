'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Loader2, Send } from 'lucide-react';
import { formatUnits, parseUnits, isAddress } from 'viem';
import type { Address } from 'viem';

interface TransferFormProps {
  balance?: bigint;
  symbol?: string;
  decimals?: number;
  onTransfer?: (to: Address, amount: bigint) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function TransferForm({
  balance = 0n,
  symbol = 'NEXUS',
  decimals = 18,
  onTransfer,
  isLoading,
  disabled,
}: TransferFormProps) {
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const formattedBalance = formatUnits(balance, decimals);
  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n;
  const isValidAddress = isAddress(recipient);
  const isValidAmount = parsedAmount > 0n && parsedAmount <= balance;
  const canSubmit = isValidAddress && isValidAmount && !disabled && !isSubmitting;

  const handleMax = () => {
    setAmount(formattedBalance);
  };

  const handleTransfer = async () => {
    if (!onTransfer || !canSubmit) return;

    setIsSubmitting(true);
    try {
      await onTransfer(recipient as Address, parsedAmount);
      setRecipient('');
      setAmount('');
    } catch (error) {
      console.error('Transfer failed:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Transfer {symbol}</CardTitle>
        <CardDescription>Send tokens to another address</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="recipient">Recipient Address</Label>
          <Input
            id="recipient"
            placeholder="0x..."
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            disabled={disabled || isLoading}
            className={recipient && !isValidAddress ? 'border-destructive' : ''}
          />
          {recipient && !isValidAddress && (
            <p className="text-sm text-destructive">Invalid address format</p>
          )}
        </div>

        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="transfer-amount">Amount</Label>
            <span className="text-sm text-muted-foreground">
              Balance: {parseFloat(formattedBalance).toLocaleString()} {symbol}
            </span>
          </div>
          <div className="relative">
            <Input
              id="transfer-amount"
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
          {amount && parsedAmount > balance && (
            <p className="text-sm text-destructive">Insufficient balance</p>
          )}
        </div>

        <Button
          className="w-full"
          disabled={!canSubmit}
          onClick={handleTransfer}
        >
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Sending...
            </>
          ) : (
            <>
              <Send className="mr-2 h-4 w-4" />
              Send {symbol}
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
}
