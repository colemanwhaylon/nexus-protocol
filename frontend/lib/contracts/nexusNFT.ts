// NexusNFT contract integration
// Stub file - will be implemented with full ABI in Phase 2

import { Address, Abi } from "viem";
import { getContractAddresses } from "./addresses";

// Placeholder ABI - will be replaced with actual ABI
export const NEXUS_NFT_ABI = [] as const satisfies Abi;

export function getNFTAddress(chainId: number): Address {
  return getContractAddresses(chainId).nexusNFT;
}

// NFT constants
export const NFT_CONSTANTS = {
  MAX_SUPPLY: 10000,
  MAX_PER_WALLET: 5,
  MINT_PRICE: BigInt(50000000000000000), // 0.05 ETH
  ROYALTY_BPS: 500, // 5%
} as const;

// Rarity tiers
export enum Rarity {
  Common = 0,
  Uncommon = 1,
  Rare = 2,
  Epic = 3,
  Legendary = 4,
}

export const RARITY_LABELS: Record<Rarity, string> = {
  [Rarity.Common]: "Common",
  [Rarity.Uncommon]: "Uncommon",
  [Rarity.Rare]: "Rare",
  [Rarity.Epic]: "Epic",
  [Rarity.Legendary]: "Legendary",
};
