import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { type Address } from 'viem';

type WalletState = {
  // Connection state
  isConnected: boolean;
  address: Address | null;
  chainId: number | null;

  // UI preferences
  preferredChainId: number;
  showTestnets: boolean;

  // Actions
  setConnected: (address: Address, chainId: number) => void;
  setDisconnected: () => void;
  setChainId: (chainId: number) => void;
  setPreferredChainId: (chainId: number) => void;
  toggleTestnets: () => void;
};

export const useWalletStore = create<WalletState>()(
  persist(
    (set) => ({
      // Initial state
      isConnected: false,
      address: null,
      chainId: null,
      preferredChainId: 11155111, // Sepolia
      showTestnets: true,

      // Actions
      setConnected: (address, chainId) =>
        set({
          isConnected: true,
          address,
          chainId,
        }),

      setDisconnected: () =>
        set({
          isConnected: false,
          address: null,
          chainId: null,
        }),

      setChainId: (chainId) => set({ chainId }),

      setPreferredChainId: (preferredChainId) => set({ preferredChainId }),

      toggleTestnets: () => set((state) => ({ showTestnets: !state.showTestnets })),
    }),
    {
      name: 'nexus-wallet-store',
      partialize: (state) => ({
        preferredChainId: state.preferredChainId,
        showTestnets: state.showTestnets,
      }),
    }
  )
);
