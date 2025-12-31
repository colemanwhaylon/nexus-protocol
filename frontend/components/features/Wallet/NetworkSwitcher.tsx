'use client';

import { useChainId, useSwitchChain } from 'wagmi';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ChevronDown, Check, AlertCircle } from 'lucide-react';
import { CHAIN_IDS } from '@/lib/wagmi';

const SUPPORTED_CHAINS = [
  { id: CHAIN_IDS.MAINNET, name: 'Ethereum', icon: '⟠' },
  { id: CHAIN_IDS.SEPOLIA, name: 'Sepolia', icon: '🧪' },
  { id: CHAIN_IDS.LOCALHOST, name: 'Localhost', icon: '🔧' },
];

export function NetworkSwitcher() {
  const chainId = useChainId();
  const { switchChain, isPending } = useSwitchChain();

  const currentChain = SUPPORTED_CHAINS.find((c) => c.id === chainId);
  const isUnsupported = !currentChain;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant={isUnsupported ? 'destructive' : 'outline'}
          size="sm"
          disabled={isPending}
        >
          {isUnsupported ? (
            <>
              <AlertCircle className="mr-2 h-4 w-4" />
              Unsupported Network
            </>
          ) : (
            <>
              <span className="mr-2">{currentChain.icon}</span>
              {currentChain.name}
            </>
          )}
          <ChevronDown className="ml-2 h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {SUPPORTED_CHAINS.map((chain) => (
          <DropdownMenuItem
            key={chain.id}
            onClick={() => switchChain?.({ chainId: chain.id })}
            className="cursor-pointer"
          >
            <span className="mr-2">{chain.icon}</span>
            {chain.name}
            {chain.id === chainId && (
              <Check className="ml-auto h-4 w-4 text-green-500" />
            )}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
