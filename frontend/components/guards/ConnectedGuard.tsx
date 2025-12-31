'use client';

import { ReactNode } from 'react';
import { useAccount } from 'wagmi';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Wallet } from 'lucide-react';
import { ConnectButton } from '@rainbow-me/rainbowkit';

interface ConnectedGuardProps {
  children: ReactNode;
  fallback?: ReactNode;
  message?: string;
}

export function ConnectedGuard({
  children,
  fallback,
  message = 'Please connect your wallet to continue.',
}: ConnectedGuardProps) {
  const { isConnected } = useAccount();

  if (!isConnected) {
    if (fallback) return <>{fallback}</>;

    return (
      <Card className="max-w-md mx-auto mt-8">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Wallet className="h-5 w-5" />
            Connect Wallet
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">{message}</p>
          <ConnectButton />
        </CardContent>
      </Card>
    );
  }

  return <>{children}</>;
}
