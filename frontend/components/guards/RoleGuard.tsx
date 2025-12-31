'use client';

import { ReactNode } from 'react';
import { useAccount } from 'wagmi';
import { useAdmin, ROLES } from '@/hooks/useAdmin';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ShieldX, Wallet, Loader2 } from 'lucide-react';
import Link from 'next/link';

type RoleType = keyof typeof ROLES;

interface RoleGuardProps {
  children: ReactNode;
  requiredRole: RoleType | RoleType[];
  fallback?: ReactNode;
  chainId?: number;
}

export function RoleGuard({
  children,
  requiredRole,
  fallback,
  chainId,
}: RoleGuardProps) {
  const { address, isConnected } = useAccount();
  const { isAdmin, isOperator, isPauser } = useAdmin(chainId);

  // Not connected
  if (!isConnected || !address) {
    if (fallback) return <>{fallback}</>;

    return (
      <Card className="max-w-md mx-auto mt-8">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Wallet className="h-5 w-5" />
            Wallet Required
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Please connect your wallet to access this page.
          </p>
          <Button asChild>
            <Link href="/">Go Home</Link>
          </Button>
        </CardContent>
      </Card>
    );
  }

  // Still loading role data
  if (isAdmin === undefined || isOperator === undefined || isPauser === undefined) {
    return (
      <div className="flex items-center justify-center min-h-[200px]">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  // Check if user has required role
  const roles = Array.isArray(requiredRole) ? requiredRole : [requiredRole];
  const hasRole = roles.some((role) => {
    switch (role) {
      case 'ADMIN_ROLE':
        return isAdmin;
      case 'OPERATOR_ROLE':
        return isOperator || isAdmin; // Admin has all roles
      case 'PAUSER_ROLE':
        return isPauser || isAdmin;
      case 'COMPLIANCE_ROLE':
        // Would need to add compliance role check
        return isAdmin;
      default:
        return false;
    }
  });

  if (!hasRole) {
    if (fallback) return <>{fallback}</>;

    return (
      <Card className="max-w-md mx-auto mt-8">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-destructive">
            <ShieldX className="h-5 w-5" />
            Access Denied
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">
            You do not have permission to access this page. Required role:{' '}
            <span className="font-medium">
              {roles.map((r) => r.replace('_ROLE', '')).join(' or ')}
            </span>
          </p>
          <Button variant="outline" asChild>
            <Link href="/">Go Home</Link>
          </Button>
        </CardContent>
      </Card>
    );
  }

  return <>{children}</>;
}

// Specific role guard components for convenience
export function AdminGuard({ children, fallback }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <RoleGuard requiredRole="ADMIN_ROLE" fallback={fallback}>
      {children}
    </RoleGuard>
  );
}

export function OperatorGuard({ children, fallback }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <RoleGuard requiredRole={['ADMIN_ROLE', 'OPERATOR_ROLE']} fallback={fallback}>
      {children}
    </RoleGuard>
  );
}

export function PauserGuard({ children, fallback }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <RoleGuard requiredRole={['ADMIN_ROLE', 'PAUSER_ROLE']} fallback={fallback}>
      {children}
    </RoleGuard>
  );
}
