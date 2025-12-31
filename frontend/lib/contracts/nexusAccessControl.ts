// NexusAccessControl contract integration
// Stub file - will be implemented with full ABI in Phase 2

import { Address, Abi, keccak256, toBytes } from "viem";
import { getContractAddresses } from "./addresses";

// Placeholder ABI - will be replaced with actual ABI
export const NEXUS_ACCESS_CONTROL_ABI = [] as const satisfies Abi;

export function getAccessControlAddress(chainId: number): Address {
  return getContractAddresses(chainId).nexusAccessControl;
}

// Role identifiers matching the smart contract
export const ROLES = {
  DEFAULT_ADMIN_ROLE: "0x0000000000000000000000000000000000000000000000000000000000000000" as const,
  OPERATOR_ROLE: keccak256(toBytes("OPERATOR_ROLE")),
  COMPLIANCE_ROLE: keccak256(toBytes("COMPLIANCE_ROLE")),
  PAUSER_ROLE: keccak256(toBytes("PAUSER_ROLE")),
} as const;

export const ROLE_LABELS: Record<string, string> = {
  [ROLES.DEFAULT_ADMIN_ROLE]: "Default Admin",
  [ROLES.OPERATOR_ROLE]: "Operator",
  [ROLES.COMPLIANCE_ROLE]: "Compliance",
  [ROLES.PAUSER_ROLE]: "Pauser",
};
