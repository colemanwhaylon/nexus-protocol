'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Loader2, UserPlus, UserMinus, ShieldCheck } from 'lucide-react';
import { isAddress } from 'viem';
import type { Address } from 'viem';

interface Role {
  id: string;
  name: string;
  description: string;
}

interface RoleManagerProps {
  roles?: Role[];
  onGrantRole?: (role: string, account: Address) => Promise<void>;
  onRevokeRole?: (role: string, account: Address) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function RoleManager({
  roles = [
    { id: 'ADMIN_ROLE', name: 'Admin', description: 'Full protocol access' },
    { id: 'OPERATOR_ROLE', name: 'Operator', description: 'Operational controls' },
    { id: 'COMPLIANCE_ROLE', name: 'Compliance', description: 'KYC/AML management' },
    { id: 'PAUSER_ROLE', name: 'Pauser', description: 'Emergency pause controls' },
  ],
  onGrantRole,
  onRevokeRole,
  isLoading,
  disabled,
}: RoleManagerProps) {
  const [selectedRole, setSelectedRole] = useState(roles[0]?.id || '');
  const [account, setAccount] = useState('');
  const [action, setAction] = useState<'grant' | 'revoke'>('grant');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isValidAddress = account ? isAddress(account) : false;
  const canSubmit = selectedRole && isValidAddress && !disabled && !isSubmitting;

  const handleSubmit = async () => {
    if (!canSubmit) return;

    setIsSubmitting(true);
    try {
      if (action === 'grant' && onGrantRole) {
        await onGrantRole(selectedRole, account as Address);
      } else if (action === 'revoke' && onRevokeRole) {
        await onRevokeRole(selectedRole, account as Address);
      }
      setAccount('');
    } catch (error) {
      console.error('Role operation failed:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ShieldCheck className="h-5 w-5" />
          Role Management
        </CardTitle>
        <CardDescription>
          Grant or revoke protocol roles
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label>Role</Label>
          <select
            value={selectedRole}
            onChange={(e) => setSelectedRole(e.target.value)}
            className="w-full px-3 py-2 border rounded-md bg-background"
            disabled={disabled || isLoading}
          >
            {roles.map((role) => (
              <option key={role.id} value={role.id}>
                {role.name} - {role.description}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="account">Account Address</Label>
          <Input
            id="account"
            placeholder="0x..."
            value={account}
            onChange={(e) => setAccount(e.target.value)}
            disabled={disabled || isLoading}
            className={account && !isValidAddress ? 'border-destructive' : ''}
          />
          {account && !isValidAddress && (
            <p className="text-sm text-destructive">Invalid address format</p>
          )}
        </div>

        <div className="flex gap-2">
          <Button
            variant={action === 'grant' ? 'default' : 'outline'}
            className="flex-1"
            onClick={() => setAction('grant')}
            disabled={disabled || isSubmitting}
          >
            <UserPlus className="mr-2 h-4 w-4" />
            Grant
          </Button>
          <Button
            variant={action === 'revoke' ? 'destructive' : 'outline'}
            className="flex-1"
            onClick={() => setAction('revoke')}
            disabled={disabled || isSubmitting}
          >
            <UserMinus className="mr-2 h-4 w-4" />
            Revoke
          </Button>
        </div>

        <Button
          className="w-full"
          variant={action === 'revoke' ? 'destructive' : 'default'}
          disabled={!canSubmit}
          onClick={handleSubmit}
        >
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Processing...
            </>
          ) : (
            <>
              {action === 'grant' ? (
                <UserPlus className="mr-2 h-4 w-4" />
              ) : (
                <UserMinus className="mr-2 h-4 w-4" />
              )}
              {action === 'grant' ? 'Grant Role' : 'Revoke Role'}
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
}
