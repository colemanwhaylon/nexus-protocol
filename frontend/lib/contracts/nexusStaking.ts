// NexusStaking contract integration
// Stub file - will be implemented with full ABI in Phase 2

import { Address, Abi } from "viem";
import { getContractAddresses } from "./addresses";

// Placeholder ABI - will be replaced with actual ABI
export const NEXUS_STAKING_ABI = [] as const satisfies Abi;

export function getStakingAddress(chainId: number): Address {
  return getContractAddresses(chainId).nexusStaking;
}

// Staking constants
export const STAKING_CONSTANTS = {
  MIN_STAKE: BigInt(1000000000000000000), // 1 NEXUS minimum
  UNBONDING_PERIOD: 7 * 24 * 60 * 60, // 7 days in seconds
  MAX_VALIDATORS: 100,
} as const;
