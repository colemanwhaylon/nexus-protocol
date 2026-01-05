import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { defineChain } from 'viem';

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'demo-project-id';

// Custom Anvil chain (uses 31337, not 1337 like wagmi's localhost)
const anvil = defineChain({
  id: 31337,
  name: 'Anvil',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
  },
  testnet: true,
});

// Build chains array based on environment
// IMPORTANT: First chain in array becomes the default when no wallet connected
const chains = process.env.NODE_ENV === 'production'
  ? [sepolia, mainnet] as const  // Production: Sepolia first (testnet), then mainnet
  : [anvil, sepolia] as const;    // Development: Anvil first (local), then Sepolia

export const wagmiConfig = getDefaultConfig({
  appName: 'Nexus Protocol',
  projectId,
  chains,
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
    [sepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL || 'https://eth-sepolia.public.blastapi.io'),
    [mainnet.id]: http(),
  },
  ssr: true,
});

// Chain IDs for easy reference
export const CHAIN_IDS = {
  LOCALHOST: anvil.id,  // 31337 (Anvil default)
  SEPOLIA: sepolia.id,
  MAINNET: mainnet.id,
} as const;

// Get current chain based on environment
export function getDefaultChainId(): number {
  if (process.env.NODE_ENV === 'development') {
    return CHAIN_IDS.LOCALHOST;
  }
  return CHAIN_IDS.SEPOLIA;
}
