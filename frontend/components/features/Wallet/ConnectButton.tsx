'use client';

import Image from 'next/image';
import { ConnectButton as RainbowConnectButton } from '@rainbow-me/rainbowkit';
import { Button } from '@/components/ui/button';
import { Wallet, ChevronDown } from 'lucide-react';

export function ConnectButton() {
  return (
    <RainbowConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
        mounted,
      }) => {
        const ready = mounted;
        const connected = ready && account && chain;

        return (
          <div
            {...(!ready && {
              'aria-hidden': true,
              style: {
                opacity: 0,
                pointerEvents: 'none',
                userSelect: 'none',
              },
            })}
          >
            {(() => {
              if (!connected) {
                return (
                  <Button onClick={openConnectModal}>
                    <Wallet className="mr-2 h-4 w-4" />
                    Connect Wallet
                  </Button>
                );
              }

              if (chain.unsupported) {
                return (
                  <Button variant="destructive" onClick={openChainModal}>
                    Wrong Network
                  </Button>
                );
              }

              return (
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={openChainModal}
                    className="hidden sm:flex"
                  >
                    {chain.hasIcon && chain.iconUrl && (
                      <Image
                        alt={chain.name ?? 'Chain icon'}
                        src={chain.iconUrl}
                        width={16}
                        height={16}
                        className="mr-2"
                        unoptimized
                      />
                    )}
                    {chain.name}
                    <ChevronDown className="ml-1 h-3 w-3" />
                  </Button>

                  <Button variant="outline" onClick={openAccountModal}>
                    {account.displayName}
                    {account.displayBalance && (
                      <span className="ml-2 hidden sm:inline text-muted-foreground">
                        {account.displayBalance}
                      </span>
                    )}
                  </Button>
                </div>
              );
            })()}
          </div>
        );
      }}
    </RainbowConnectButton.Custom>
  );
}
