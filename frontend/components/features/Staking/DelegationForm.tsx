'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Loader2, Users, UserCheck } from 'lucide-react';
import { isAddress } from 'viem';
import type { Address } from 'viem';

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
  const isSelfDelegated = currentDelegate === userAddress;
  const canSubmit = isValidAddress && !disabled && !isSubmitting;

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

  const handleSelfDelegate = async () => {
    if (!onDelegate || !userAddress || disabled || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await onDelegate(userAddress);
    } catch (error) {
      console.error('Self-delegation failed:', error);
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
          Delegate your staking power to another address
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {currentDelegate && (
          <div className="p-3 bg-muted rounded-lg">
            <p className="text-sm text-muted-foreground">Current Delegate</p>
            <div className="flex items-center gap-2">
              {isSelfDelegated ? (
                <>
                  <UserCheck className="h-4 w-4 text-green-500" />
                  <span className="font-medium">Self-delegated</span>
                </>
              ) : (
                <span className="font-mono">{shortenAddress(currentDelegate)}</span>
              )}
            </div>
          </div>
        )}

        <div className="space-y-2">
          <Label htmlFor="delegatee">Delegate To</Label>
          <Input
            id="delegatee"
            placeholder="0x..."
            value={delegatee}
            onChange={(e) => setDelegatee(e.target.value)}
            disabled={disabled || isLoading}
            className={delegatee && !isValidAddress ? 'border-destructive' : ''}
          />
          {delegatee && !isValidAddress && (
            <p className="text-sm text-destructive">Invalid address format</p>
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
          
          {!isSelfDelegated && userAddress && (
            <Button
              variant="outline"
              disabled={disabled || isSubmitting}
              onClick={handleSelfDelegate}
            >
              <UserCheck className="mr-2 h-4 w-4" />
              Self
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
