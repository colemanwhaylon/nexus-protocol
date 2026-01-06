import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { defineChain } from 'viem';

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'demo-project-id';

// RPC URLs - use public nodes with generous rate limits
// Alchemy free tier only allows 10 block range for getLogs, so we use publicnode
const SEPOLIA_RPC = process.env.NEXT_PUBLIC_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com';
const MAINNET_RPC = 'https://ethereum-rpc.publicnode.com';

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

// Override Sepolia chain with our RPC URL to avoid Alchemy defaults
const sepoliaWithRpc = {
  ...sepolia,
  rpcUrls: {
    ...sepolia.rpcUrls,
    default: { http: [SEPOLIA_RPC] },
  },
};

// Override Mainnet chain with our RPC URL
const mainnetWithRpc = {
  ...mainnet,
  rpcUrls: {
    ...mainnet.rpcUrls,
    default: { http: [MAINNET_RPC] },
  },
};

// Build chains array based on environment
// IMPORTANT: First chain in array becomes the default when no wallet connected
const chains = process.env.NODE_ENV === 'production'
  ? [sepoliaWithRpc, mainnetWithRpc] as const  // Production: Sepolia first (testnet), then mainnet
  : [anvil, sepoliaWithRpc] as const;           // Development: Anvil first (local), then Sepolia

export const wagmiConfig = getDefaultConfig({
  appName: 'Nexus Protocol',
  projectId,
  chains,
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
    [sepolia.id]: http(SEPOLIA_RPC),
    [mainnet.id]: http(MAINNET_RPC),
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
