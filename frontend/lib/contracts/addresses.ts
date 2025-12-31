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
  // Localhost (Anvil)
  [CHAIN_IDS.LOCALHOST]: {
    nexusToken: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    nexusNFT: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    nexusStaking: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    nexusGovernor: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    nexusTimelock: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    nexusAccessControl: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
    nexusKYC: '0x0165878A594ca255338adfa4d48449f69242Eb8F',
    nexusEmergency: '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853',
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
