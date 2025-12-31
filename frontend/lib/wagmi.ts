import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { mainnet, sepolia, localhost } from 'wagmi/chains';

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'demo-project-id';

export const wagmiConfig = getDefaultConfig({
  appName: 'Nexus Protocol',
  projectId,
  chains: [
    // Development
    localhost,
    // Testnet
    sepolia,
    // Mainnet (for production)
    ...(process.env.NODE_ENV === 'production' ? [mainnet] : []),
  ],
  transports: {
    [localhost.id]: http('http://127.0.0.1:8545'),
    [sepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL || 'https://eth-sepolia.public.blastapi.io'),
    [mainnet.id]: http(),
  },
  ssr: true,
});

// Chain IDs for easy reference
export const CHAIN_IDS = {
  LOCALHOST: localhost.id,
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
