'use client';

import { useAccount, useChainId, useDisconnect } from 'wagmi';
import { useConnectModal } from '@rainbow-me/rainbowkit';
import { useEffect } from 'react';
import { useWalletStore } from '@/stores/walletStore';
import { formatAddress } from '@/lib/utils';

export function useWallet() {
  const { address, isConnected, isConnecting, isReconnecting } = useAccount();
  const chainId = useChainId();
  const { disconnect } = useDisconnect();
  const { openConnectModal } = useConnectModal();
  const { setConnected, setDisconnected, setChainId } = useWalletStore();

  // Sync wagmi state with our store
  useEffect(() => {
    if (isConnected && address) {
      setConnected(address, chainId);
    } else if (!isConnected) {
      setDisconnected();
    }
  }, [isConnected, address, chainId, setConnected, setDisconnected]);

  useEffect(() => {
    if (chainId) {
      setChainId(chainId);
    }
  }, [chainId, setChainId]);

  return {
    // State
    address,
    chainId,
    isConnected,
    isConnecting: isConnecting || isReconnecting,

    // Formatted values
    displayAddress: address ? formatAddress(address) : null,

    // Actions
    connect: openConnectModal,
    disconnect,
  };
}
