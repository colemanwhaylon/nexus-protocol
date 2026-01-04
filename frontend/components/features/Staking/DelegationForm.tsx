'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Loader2, Users, UserMinus } from 'lucide-react';
import { isAddress } from 'viem';
import type { Address } from 'viem';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

interface DelegationFormProps {
  currentDelegate?: Address;
  userAddress?: Address;
  onDelegate?: (delegatee: Address) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function DelegationForm({
  currentDelegate,
  userAddress,
  onDelegate,
  isLoading,
  disabled,
}: DelegationFormProps) {
  const [delegatee, setDelegatee] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isValidAddress = delegatee ? isAddress(delegatee) : false;
  const isSameAsUser = delegatee.toLowerCase() === userAddress?.toLowerCase();
  const hasDelegated = currentDelegate && currentDelegate !== ZERO_ADDRESS;
  const canSubmit = isValidAddress && !isSameAsUser && !disabled && !isSubmitting;

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const handleDelegate = async () => {
    if (!onDelegate || !canSubmit) return;

    setIsSubmitting(true);
    try {
      await onDelegate(delegatee as Address);
      setDelegatee('');
    } catch (error) {
      console.error('Delegation failed:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRemoveDelegation = async () => {
    if (!onDelegate || disabled || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await onDelegate(ZERO_ADDRESS as Address);
    } catch (error) {
      console.error('Remove delegation failed:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Users className="h-5 w-5" />
          Delegate Stake
        </CardTitle>
        <CardDescription>
          Delegate your voting power to another address (self-delegation not allowed)
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Current Delegation Status */}
        <div className="p-3 bg-muted rounded-lg">
          <p className="text-sm text-muted-foreground mb-1">Current Delegate</p>
          <div className="flex items-center justify-between">
            {hasDelegated ? (
              <>
                <span className="font-mono text-sm">{shortenAddress(currentDelegate)}</span>
                <Badge variant="default">Active</Badge>
              </>
            ) : (
              <>
                <span className="text-muted-foreground">Not delegated</span>
                <Badge variant="secondary">None</Badge>
              </>
            )}
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="delegatee">Delegate To</Label>
          <Input
            id="delegatee"
            placeholder="0x..."
            value={delegatee}
            onChange={(e) => setDelegatee(e.target.value)}
            disabled={disabled || isLoading || isSubmitting}
            className={delegatee && (!isValidAddress || isSameAsUser) ? 'border-destructive' : ''}
          />
          {delegatee && !isValidAddress && (
            <p className="text-sm text-destructive">Invalid address format</p>
          )}
          {delegatee && isSameAsUser && (
            <p className="text-sm text-destructive">Cannot delegate to yourself</p>
          )}
        </div>

        <div className="flex gap-2">
          <Button
            className="flex-1"
            disabled={!canSubmit}
            onClick={handleDelegate}
          >
            {isSubmitting ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Delegating...
              </>
            ) : (
              <>
                <Users className="mr-2 h-4 w-4" />
                Delegate
              </>
            )}
          </Button>

          {hasDelegated && (
            <Button
              variant="outline"
              disabled={disabled || isSubmitting}
              onClick={handleRemoveDelegation}
            >
              <UserMinus className="mr-2 h-4 w-4" />
              Remove
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
