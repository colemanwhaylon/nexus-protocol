/**
 * Contract Addresses React Query Hook
 *
 * Fetches contract addresses from the database via API.
 * NO HARDCODED FALLBACKS - properly handle loading/error states.
 */

'use client';

import { useQuery } from '@tanstack/react-query';
import { useChainId } from 'wagmi';
import { type Address } from 'viem';
import {
  fetchContractAddresses,
  fetchDeploymentConfig,
  fetchContractMappings,
  fetchNetworks,
  type ContractAddresses,
  type DeploymentConfig,
  type ContractMappingResponse,
  type NetworkConfigResponse,
} from '@/lib/api/contracts';
import { getDefaultChainId, CHAIN_IDS } from '@/lib/wagmi';

// ============================================================================
// Main Hook: Contract Addresses
// ============================================================================

/**
 * Hook to fetch contract addresses from database.
 * Uses environment-aware chainId to ensure production uses Sepolia.
 */
export function useContractAddresses() {
  const wagmiChainId = useChainId();

  // In production, if wagmi returns localhost chainId (no wallet connected),
  // use the environment-appropriate default instead
  const chainId = (process.env.NODE_ENV === 'production' && wagmiChainId === CHAIN_IDS.LOCALHOST)
    ? getDefaultChainId()
    : wagmiChainId;

  const { data, isLoading, error, refetch, isFetching } = useQuery({
    queryKey: ['contractAddresses', chainId],
    queryFn: () => fetchContractAddresses(chainId),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes cache (previously cacheTime)
    retry: 2,
    refetchOnWindowFocus: false,
  });

  return {
    // Return empty object if loading, not hardcoded fallbacks
    addresses: data ?? ({} as ContractAddresses),
    isLoading,
    isFetching,
    error: error as Error | null,
    refetch,
    // Helper: check if a specific contract is available
    hasContract: (name: string) => !isLoading && !!data?.[name],
    // Helper: get a specific address or undefined
    getAddress: (name: string) => data?.[name] as Address | undefined,
  };
}

// ============================================================================
// Single Contract Address Hook
// ============================================================================

/**
 * Hook to get a specific contract address.
 * Returns undefined if not loaded or not found.
 */
export function useContractAddress(contractName: string) {
  const { addresses, isLoading, error, hasContract } = useContractAddresses();

  return {
    address: addresses[contractName] as Address | undefined,
    isLoading,
    error,
    isAvailable: hasContract(contractName),
  };
}

// ============================================================================
// Deployment Config Hook (Admin/Debug)
// ============================================================================

/**
 * Hook to fetch full deployment config.
 * Useful for admin pages that need to show all possible contracts.
 */
export function useDeploymentConfig() {
  const wagmiChainId = useChainId();

  // In production, if wagmi returns localhost chainId, use the environment default
  const chainId = (process.env.NODE_ENV === 'production' && wagmiChainId === CHAIN_IDS.LOCALHOST)
    ? getDefaultChainId()
    : wagmiChainId;

  const { data, isLoading, error, refetch, isFetching } = useQuery<DeploymentConfig>({
    queryKey: ['deploymentConfig', chainId],
    queryFn: () => fetchDeploymentConfig(chainId),
    staleTime: 5 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
    retry: 2,
    refetchOnWindowFocus: false,
  });

  // Compute deployment status
  const deployedDbNames = new Set(data?.contracts?.map((c) => c.db_name) || []);
  const missingContracts =
    data?.mappings?.filter((m) => m.is_required && !deployedDbNames.has(m.db_name)) || [];

  return {
    config: data,
    network: data?.network,
    mappings: data?.mappings ?? [],
    contracts: data?.contracts ?? [],
    isLoading,
    isFetching,
    error: error as Error | null,
    refetch,
    // Helpers
    isFullyDeployed: missingContracts.length === 0,
    missingContracts,
    deployedCount: data?.contracts?.length ?? 0,
    totalCount: data?.mappings?.length ?? 0,
  };
}

// ============================================================================
// Contract Mappings Hook
// ============================================================================

/**
 * Hook to fetch contract name mappings.
 * Returns what contracts are defined in the system.
 */
export function useContractMappings() {
  const { data, isLoading, error, refetch } = useQuery<ContractMappingResponse[]>({
    queryKey: ['contractMappings'],
    queryFn: fetchContractMappings,
    staleTime: 60 * 60 * 1000, // 1 hour - mappings rarely change
    gcTime: 24 * 60 * 60 * 1000, // 24 hours
    retry: 2,
  });

  // Group by category
  const byCategory = (data ?? []).reduce(
    (acc, mapping) => {
      const category = mapping.category;
      if (!acc[category]) {
        acc[category] = [];
      }
      acc[category].push(mapping);
      return acc;
    },
    {} as Record<string, ContractMappingResponse[]>
  );

  return {
    mappings: data ?? [],
    byCategory,
    isLoading,
    error: error as Error | null,
    refetch,
  };
}

// ============================================================================
// Networks Hook
// ============================================================================

/**
 * Hook to fetch all active networks.
 */
export function useNetworks() {
  const { data, isLoading, error, refetch } = useQuery<NetworkConfigResponse[]>({
    queryKey: ['networks'],
    queryFn: fetchNetworks,
    staleTime: 60 * 60 * 1000, // 1 hour
    gcTime: 24 * 60 * 60 * 1000, // 24 hours
    retry: 2,
  });

  return {
    networks: data ?? [],
    isLoading,
    error: error as Error | null,
    refetch,
    // Helpers
    getNetwork: (chainId: number) => data?.find((n) => n.chain_id === chainId),
    testnets: data?.filter((n) => n.is_testnet) ?? [],
    mainnets: data?.filter((n) => !n.is_testnet) ?? [],
  };
}

// ============================================================================
// Utility Hooks
// ============================================================================

/**
 * Hook to check if contracts are ready for use.
 * Returns true only when addresses are loaded successfully.
 */
export function useContractsReady(requiredContracts?: string[]) {
  const { addresses, isLoading, error, hasContract } = useContractAddresses();

  if (isLoading) {
    return { isReady: false, isLoading: true, error: null, missing: [] };
  }

  if (error) {
    return { isReady: false, isLoading: false, error, missing: [] };
  }

  // If no specific contracts required, just check if we have any
  if (!requiredContracts) {
    const hasAny = Object.keys(addresses).length > 0;
    return { isReady: hasAny, isLoading: false, error: null, missing: [] };
  }

  // Check all required contracts are available
  const missing = requiredContracts.filter((name) => !hasContract(name));
  return {
    isReady: missing.length === 0,
    isLoading: false,
    error: null,
    missing,
  };
}
