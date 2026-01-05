/**
 * Contract Address API Client
 *
 * Fetches contract addresses from the backend PostgreSQL database via API.
 *
 * IMPORTANT: NO HARDCODED FALLBACK ADDRESSES
 * All contract addresses MUST come from the database. This ensures:
 * - Single source of truth for contract addresses
 * - OCP (Open-Closed Principle) compliance - new deployments only require DB updates
 * - No risk of stale hardcoded addresses causing bugs
 *
 * If the API is unavailable, the error should propagate and be handled by the UI
 * with appropriate error states rather than silently using potentially outdated addresses.
 */

import { type Address } from 'viem';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

// ============================================================================
// Response Types from API
// ============================================================================

export type NetworkConfigResponse = {
  id: string;
  chain_id: number;
  network_name: string;
  display_name: string;
  rpc_url: string | null;
  explorer_url: string | null;
  default_deployer: string | null;
  is_testnet: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type ContractMappingResponse = {
  id: string;
  solidity_name: string;
  db_name: string;
  display_name: string;
  category: string;
  description: string | null;
  is_required: boolean;
  sort_order: number;
  created_at: string;
};

export type ContractAddressResponse = {
  id: string;
  chain_id: number;
  contract_mapping_id: string;
  db_name: string;
  solidity_name: string;
  address: string;
  deployment_tx_hash: string | null;
  deployment_block: number | null;
  abi_version: string;
  status: string;
  is_primary: boolean;
  deployed_by: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type ContractHistoryResponse = {
  id: string;
  contract_id: string;
  old_address: string | null;
  new_address: string;
  change_reason: string | null;
  changed_by: string;
  changed_at: string;
};

export type DeploymentConfig = {
  network: NetworkConfigResponse;
  mappings: ContractMappingResponse[];
  contracts: ContractAddressResponse[];
};

// Dynamic contract addresses - keys come from database
export type ContractAddresses = Record<string, Address>;

// ============================================================================
// API Response Wrapper
// ============================================================================

type ApiResponse<T> = {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
};

// ============================================================================
// API Functions
// ============================================================================

/**
 * Fetch all active networks
 */
export async function fetchNetworks(): Promise<NetworkConfigResponse[]> {
  const response = await fetch(`${API_URL}/api/v1/networks`);
  if (!response.ok) {
    throw new Error(`Failed to fetch networks: ${response.statusText}`);
  }
  const data: ApiResponse<{ networks: NetworkConfigResponse[]; total: number }> =
    await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch networks');
  }
  return data.data?.networks || [];
}

/**
 * Fetch network config by chain ID
 */
export async function fetchNetwork(chainId: number): Promise<NetworkConfigResponse> {
  const response = await fetch(`${API_URL}/api/v1/networks/${chainId}`);
  if (!response.ok) {
    if (response.status === 404) {
      throw new Error(`Network not found for chain ID: ${chainId}`);
    }
    throw new Error(`Failed to fetch network: ${response.statusText}`);
  }
  const data: ApiResponse<NetworkConfigResponse> = await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch network');
  }
  return data.data!;
}

/**
 * Fetch all contract name mappings
 */
export async function fetchContractMappings(): Promise<ContractMappingResponse[]> {
  const response = await fetch(`${API_URL}/api/v1/contracts/mappings`);
  if (!response.ok) {
    throw new Error(`Failed to fetch mappings: ${response.statusText}`);
  }
  const data: ApiResponse<{ mappings: ContractMappingResponse[]; total: number }> =
    await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch mappings');
  }
  return data.data?.mappings || [];
}

/**
 * Fetch full deployment config (network + mappings + contracts)
 */
export async function fetchDeploymentConfig(chainId: number): Promise<DeploymentConfig> {
  const response = await fetch(`${API_URL}/api/v1/contracts/config/${chainId}`);
  if (!response.ok) {
    if (response.status === 404) {
      throw new Error(`Network not found for chain ID: ${chainId}`);
    }
    throw new Error(`Failed to fetch config: ${response.statusText}`);
  }
  const data: ApiResponse<DeploymentConfig> = await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch config');
  }
  return data.data!;
}

/**
 * Fetch all contracts for a chain
 */
export async function fetchContractsList(
  chainId: number
): Promise<ContractAddressResponse[]> {
  const response = await fetch(`${API_URL}/api/v1/contracts/${chainId}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch contracts: ${response.statusText}`);
  }
  const data: ApiResponse<{ contracts: ContractAddressResponse[]; total: number }> =
    await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch contracts');
  }
  return data.data?.contracts || [];
}

/**
 * Fetch contract addresses from the PostgreSQL database via API.
 * Returns a dynamic Record<string, Address> built from database data.
 *
 * NO FALLBACKS - All addresses come from the database.
 * If the API fails, the error propagates to be handled by the UI.
 */
export async function fetchContractAddresses(chainId: number): Promise<ContractAddresses> {
  const contracts = await fetchContractsList(chainId);

  // Build dynamic object from API response
  return contracts.reduce(
    (acc: ContractAddresses, c: ContractAddressResponse) => ({
      ...acc,
      [c.db_name]: c.address as Address,
    }),
    {} as ContractAddresses
  );
}

/**
 * Fetch a specific contract by chain ID and DB name
 */
export async function fetchContract(
  chainId: number,
  dbName: string
): Promise<ContractAddressResponse> {
  const response = await fetch(`${API_URL}/api/v1/contracts/${chainId}/${dbName}`);
  if (!response.ok) {
    if (response.status === 404) {
      throw new Error(`Contract not found: ${dbName} on chain ${chainId}`);
    }
    throw new Error(`Failed to fetch contract: ${response.statusText}`);
  }
  const data: ApiResponse<ContractAddressResponse> = await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch contract');
  }
  return data.data!;
}

/**
 * Fetch contract deployment history
 */
export async function fetchContractHistory(
  contractId: string,
  limit: number = 20
): Promise<ContractHistoryResponse[]> {
  const response = await fetch(
    `${API_URL}/api/v1/contracts/history/${contractId}?limit=${limit}`
  );
  if (!response.ok) {
    if (response.status === 404) {
      throw new Error(`Contract not found: ${contractId}`);
    }
    throw new Error(`Failed to fetch history: ${response.statusText}`);
  }
  const data: ApiResponse<{
    contract_id: string;
    contract_name: string;
    chain_id: number;
    history: ContractHistoryResponse[];
    total: number;
  }> = await response.json();
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch history');
  }
  return data.data?.history || [];
}
