import { type Address } from 'viem';

// ============================================
// Common Types
// ============================================

export type TransactionStatus = 'idle' | 'pending' | 'success' | 'error';

export type TransactionState =
  | { status: 'idle' }
  | { status: 'pending'; hash?: string }
  | { status: 'success'; hash: string }
  | { status: 'error'; error: Error };

// ============================================
// Token Types
// ============================================

export type TokenInfo = {
  name: string;
  symbol: string;
  decimals: number;
  totalSupply: bigint;
  address: Address;
};

export type TokenBalance = {
  value: bigint;
  formatted: string;
  symbol: string;
};

// ============================================
// Staking Types
// ============================================

export type StakingPosition = {
  stakedAmount: bigint;
  stakedAt: number;
  pendingRewards: bigint;
  delegatee: Address | null;
};

export type StakingStats = {
  totalStaked: bigint;
  apy: number;
  stakersCount: number;
  minStake: bigint;
  unbondingPeriod: number;
};

export type UnbondingRequest = {
  amount: bigint;
  unlockTime: number;
  claimed: boolean;
};

// ============================================
// NFT Types
// ============================================

export type NFTMetadata = {
  name: string;
  description: string;
  image: string;
  attributes: NFTAttribute[];
};

export type NFTAttribute = {
  trait_type: string;
  value: string | number;
  display_type?: string;
};

export type NFTToken = {
  tokenId: bigint;
  owner: Address;
  metadata: NFTMetadata;
  soulbound: boolean;
};

export type NFTCollection = {
  name: string;
  symbol: string;
  maxSupply: number;
  totalMinted: number;
  mintPrice: bigint;
  whitelistPrice: bigint;
  salePhase: SalePhase;
  revealed: boolean;
  royaltyBps: number;
};

export type SalePhase = 'closed' | 'whitelist' | 'public';

// ============================================
// Governance Types
// ============================================

export type ProposalState =
  | 'pending'
  | 'active'
  | 'canceled'
  | 'defeated'
  | 'succeeded'
  | 'queued'
  | 'expired'
  | 'executed';

export type VoteType = 'against' | 'for' | 'abstain';

export type Proposal = {
  id: bigint;
  proposer: Address;
  title: string;
  description: string;
  targets: Address[];
  values: bigint[];
  calldatas: `0x${string}`[];
  state: ProposalState;
  startBlock: bigint;
  endBlock: bigint;
  forVotes: bigint;
  againstVotes: bigint;
  abstainVotes: bigint;
  eta?: number;
};

export type Vote = {
  voter: Address;
  proposalId: bigint;
  support: VoteType;
  weight: bigint;
  reason?: string;
};

// ============================================
// KYC / Compliance Types
// ============================================

export type KYCLevel = 'none' | 'basic' | 'standard' | 'advanced';

export type KYCStatus = 'pending' | 'approved' | 'rejected' | 'expired' | 'suspended';

export type KYCRegistration = {
  address: Address;
  status: KYCStatus;
  level: KYCLevel;
  jurisdiction: string;
  verifiedAt?: number;
  expiresAt?: number;
  accreditedInvestor: boolean;
};

// ============================================
// Access Control Types
// ============================================

export type Role =
  | 'admin'
  | 'operator'
  | 'compliance'
  | 'pauser'
  | 'guardian'
  | 'upgrader'
  | 'slasher';

export type RoleAssignment = {
  role: Role;
  account: Address;
  grantedAt: number;
  grantedBy: Address;
};
