import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http, fallback } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { defineChain } from 'viem';

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'demo-project-id';

// RPC URLs - use public nodes with generous rate limits
// IMPORTANT: Alchemy free tier only allows 10 block range for getLogs
// We MUST use publicnode or other providers that support full block ranges
const SEPOLIA_RPC_PRIMARY = 'https://ethereum-sepolia-rpc.publicnode.com';
const SEPOLIA_RPC_FALLBACK = 'https://rpc.sepolia.org';
const MAINNET_RPC_PRIMARY = 'https://ethereum-rpc.publicnode.com';
const MAINNET_RPC_FALLBACK = 'https://eth.llamarpc.com';

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
  : [anvil, sepolia] as const;   // Development: Anvil first (local), then Sepolia

// Configure transports with fallback for reliability
// This explicitly overrides RainbowKit's default Alchemy endpoints
export const wagmiConfig = getDefaultConfig({
  appName: 'Nexus Protocol',
  projectId,
  chains,
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
    [sepolia.id]: fallback([
      http(SEPOLIA_RPC_PRIMARY),
      http(SEPOLIA_RPC_FALLBACK),
    ]),
    [mainnet.id]: fallback([
      http(MAINNET_RPC_PRIMARY),
      http(MAINNET_RPC_FALLBACK),
    ]),
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
