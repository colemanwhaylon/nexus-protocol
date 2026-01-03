import { type Address } from 'viem';
import { CHAIN_IDS } from '@/lib/wagmi';

type ContractAddresses = {
  nexusToken: Address;
  nexusNFT: Address;
  nexusStaking: Address;
  nexusGovernor: Address;
  nexusTimelock: Address;
  nexusAccessControl: Address;
  nexusKYC: Address;
  nexusEmergency: Address;
};

// Contract addresses by chain ID
const addresses: Record<number, ContractAddresses> = {
  // Localhost (Anvil) - Deployed via DeployLocal.s.sol
  // Last deployed: 2026-01-03 (run `forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast` to redeploy)
  [CHAIN_IDS.LOCALHOST]: {
    nexusToken: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    nexusNFT: '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6',
    nexusStaking: '0x0165878A594ca255338adfa4d48449f69242Eb8F',
    nexusGovernor: '0x0000000000000000000000000000000000000000', // Not deployed yet
    nexusTimelock: '0x0000000000000000000000000000000000000000', // Not deployed yet
    nexusAccessControl: '0x0000000000000000000000000000000000000000', // Not deployed yet
    nexusKYC: '0x0000000000000000000000000000000000000000', // Not deployed yet
    nexusEmergency: '0x0000000000000000000000000000000000000000', // Not deployed yet
  },
  // Sepolia Testnet (update after deployment)
  [CHAIN_IDS.SEPOLIA]: {
    nexusToken: (process.env.NEXT_PUBLIC_NEXUS_TOKEN_ADDRESS || '0x0') as Address,
    nexusNFT: (process.env.NEXT_PUBLIC_NEXUS_NFT_ADDRESS || '0x0') as Address,
    nexusStaking: (process.env.NEXT_PUBLIC_NEXUS_STAKING_ADDRESS || '0x0') as Address,
    nexusGovernor: (process.env.NEXT_PUBLIC_NEXUS_GOVERNOR_ADDRESS || '0x0') as Address,
    nexusTimelock: (process.env.NEXT_PUBLIC_NEXUS_TIMELOCK_ADDRESS || '0x0') as Address,
    nexusAccessControl: (process.env.NEXT_PUBLIC_NEXUS_ACCESS_CONTROL_ADDRESS || '0x0') as Address,
    nexusKYC: (process.env.NEXT_PUBLIC_NEXUS_KYC_ADDRESS || '0x0') as Address,
    nexusEmergency: (process.env.NEXT_PUBLIC_NEXUS_EMERGENCY_ADDRESS || '0x0') as Address,
  },
  // Mainnet (update for production)
  [CHAIN_IDS.MAINNET]: {
    nexusToken: '0x0000000000000000000000000000000000000000',
    nexusNFT: '0x0000000000000000000000000000000000000000',
    nexusStaking: '0x0000000000000000000000000000000000000000',
    nexusGovernor: '0x0000000000000000000000000000000000000000',
    nexusTimelock: '0x0000000000000000000000000000000000000000',
    nexusAccessControl: '0x0000000000000000000000000000000000000000',
    nexusKYC: '0x0000000000000000000000000000000000000000',
    nexusEmergency: '0x0000000000000000000000000000000000000000',
  },
};

export function getContractAddresses(chainId?: number): ContractAddresses {
  const effectiveChainId = chainId ?? CHAIN_IDS.LOCALHOST;
  const chainAddresses = addresses[effectiveChainId];
  if (!chainAddresses) {
    throw new Error(`No contract addresses configured for chain ID: ${effectiveChainId}`);
  }
  return chainAddresses;
}

export function getContractAddress(chainId: number | undefined, contract: keyof ContractAddresses): Address {
  return getContractAddresses(chainId)[contract];
}
