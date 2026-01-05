'use client';

import { Skeleton } from '@/components/ui/skeleton';
import { AlertCircle, Loader2 } from 'lucide-react';
import { useContractAddresses } from '@/hooks/useContractAddresses';

interface AddressesGuardProps {
  children: React.ReactNode;
  requiredContracts?: string[]; // Optional: specify which contracts are needed
  loadingMessage?: string;
  showSkeleton?: boolean;
}

/**
 * Guard component that shows loading/error states for contract addresses.
 * Optionally validates that specific contracts are deployed.
 */
export function AddressesGuard({
  children,
  requiredContracts,
  loadingMessage = 'Loading contract addresses...',
  showSkeleton = true,
}: AddressesGuardProps) {
  const { addresses, isLoading, error, hasContract } = useContractAddresses();

  if (isLoading) {
    if (showSkeleton) {
      return (
        <div className="flex items-center justify-center p-8">
          <div className="text-center">
            <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2 text-muted-foreground" />
            <Skeleton className="h-4 w-48 mb-2 mx-auto" />
            <p className="text-sm text-muted-foreground">{loadingMessage}</p>
          </div>
        </div>
      );
    }
    return null;
  }

  if (error) {
    return (
      <div className="p-4 border border-destructive/50 bg-destructive/10 rounded-lg">
        <div className="flex items-center gap-2 text-destructive">
          <AlertCircle className="h-4 w-4" />
          <span className="font-medium">Failed to load contract addresses</span>
        </div>
        <p className="text-sm text-muted-foreground mt-1">{error.message}</p>
        <p className="text-xs text-muted-foreground mt-2">
          Make sure the API server is running and contracts are deployed.
        </p>
      </div>
    );
  }

  // Check if we have any contracts loaded
  if (Object.keys(addresses).length === 0) {
    return (
      <div className="p-4 border border-yellow-500/50 bg-yellow-500/10 rounded-lg">
        <div className="flex items-center gap-2 text-yellow-600 dark:text-yellow-400">
          <AlertCircle className="h-4 w-4" />
          <span className="font-medium">No contracts deployed</span>
        </div>
        <p className="text-sm text-muted-foreground mt-1">
          No contract addresses found for the current network.
        </p>
        <p className="text-xs text-muted-foreground mt-2">
          Run the deployment script and register contracts with post_deploy.py
        </p>
      </div>
    );
  }

  // Check required contracts are deployed
  if (requiredContracts && requiredContracts.length > 0) {
    const missing = requiredContracts.filter((name) => !hasContract(name));
    if (missing.length > 0) {
      return (
        <div className="p-4 border border-yellow-500/50 bg-yellow-500/10 rounded-lg">
          <div className="flex items-center gap-2 text-yellow-600 dark:text-yellow-400">
            <AlertCircle className="h-4 w-4" />
            <span className="font-medium">Required contracts not deployed</span>
          </div>
          <p className="text-sm text-muted-foreground mt-1">
            Missing: {missing.join(', ')}
          </p>
          <p className="text-xs text-muted-foreground mt-2">
            Deploy the missing contracts and register them via the API.
          </p>
        </div>
      );
    }
  }

  return <>{children}</>;
}

/**
 * Inline loading indicator for contract addresses.
 * Use this when you need a smaller loading state.
 */
export function AddressesLoading() {
  return (
    <div className="flex items-center gap-2 text-muted-foreground">
      <Loader2 className="h-4 w-4 animate-spin" />
      <span className="text-sm">Loading addresses...</span>
    </div>
  );
}

/**
 * Simple error display for contract address issues.
 */
export function AddressesError({ message }: { message: string }) {
  return (
    <div className="flex items-center gap-2 text-destructive text-sm">
      <AlertCircle className="h-4 w-4" />
      <span>{message}</span>
    </div>
  );
}
