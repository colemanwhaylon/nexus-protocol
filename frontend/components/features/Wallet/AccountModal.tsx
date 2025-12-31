'use client';

import { useWallet } from '@/hooks/useWallet';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Copy, ExternalLink, LogOut, Check } from 'lucide-react';
import { useState } from 'react';

interface AccountModalProps {
  children: React.ReactNode;
}

export function AccountModal({ children }: AccountModalProps) {
  const { address, displayAddress, chainId, disconnect, isConnected } = useWallet();
  const [copied, setCopied] = useState(false);

  const copyAddress = async () => {
    if (address) {
      await navigator.clipboard.writeText(address);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const getExplorerUrl = () => {
    if (!address) return '#';
    switch (chainId) {
      case 1:
        return `https://etherscan.io/address/${address}`;
      case 11155111:
        return `https://sepolia.etherscan.io/address/${address}`;
      default:
        return '#';
    }
  };

  if (!isConnected) return <>{children}</>;

  return (
    <Dialog>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Account</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <div className="flex items-center justify-between p-4 bg-muted rounded-lg">
            <div>
              <p className="text-sm text-muted-foreground">Connected with</p>
              <p className="font-mono text-lg">{displayAddress}</p>
            </div>
            <Badge variant="outline">
              {chainId === 1 ? 'Mainnet' : chainId === 11155111 ? 'Sepolia' : `Chain ${chainId}`}
            </Badge>
          </div>

          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              className="flex-1"
              onClick={copyAddress}
            >
              {copied ? (
                <Check className="mr-2 h-4 w-4" />
              ) : (
                <Copy className="mr-2 h-4 w-4" />
              )}
              {copied ? 'Copied!' : 'Copy Address'}
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="flex-1"
              asChild
            >
              <a href={getExplorerUrl()} target="_blank" rel="noopener noreferrer">
                <ExternalLink className="mr-2 h-4 w-4" />
                Explorer
              </a>
            </Button>
          </div>

          <Button
            variant="destructive"
            className="w-full"
            onClick={() => disconnect()}
          >
            <LogOut className="mr-2 h-4 w-4" />
            Disconnect
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
