// NexusGovernor contract integration
// Stub file - will be implemented with full ABI in Phase 2

import { Address, Abi } from "viem";
import { getContractAddresses } from "./addresses";

// Placeholder ABI - will be replaced with actual ABI
export const NEXUS_GOVERNOR_ABI = [] as const satisfies Abi;

export function getGovernorAddress(chainId: number): Address {
  return getContractAddresses(chainId).nexusGovernor;
}

// Proposal states enum matching OpenZeppelin Governor
export enum ProposalState {
  Pending = 0,
  Active = 1,
  Canceled = 2,
  Defeated = 3,
  Succeeded = 4,
  Queued = 5,
  Expired = 6,
  Executed = 7,
}

export const PROPOSAL_STATE_LABELS: Record<ProposalState, string> = {
  [ProposalState.Pending]: "Pending",
  [ProposalState.Active]: "Active",
  [ProposalState.Canceled]: "Canceled",
  [ProposalState.Defeated]: "Defeated",
  [ProposalState.Succeeded]: "Succeeded",
  [ProposalState.Queued]: "Queued",
  [ProposalState.Expired]: "Expired",
  [ProposalState.Executed]: "Executed",
};
