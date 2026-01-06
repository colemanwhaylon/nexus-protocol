'use client';

import { useState, useCallback, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useContractAddresses } from './useContractAddresses';

// API base URL for governance config
// Uses NEXT_PUBLIC_GOVERNANCE_API_URL if set, otherwise falls back to Supabase Edge Functions
const API_BASE_URL =
  process.env.NEXT_PUBLIC_GOVERNANCE_API_URL ||
  'https://lddtgmolwkbgqsxgbdjw.supabase.co/functions/v1/api';

// NexusGovernor ABI for admin functions
const GOVERNOR_ADMIN_ABI = [
  {
    inputs: [{ name: 'newThreshold', type: 'uint256' }],
    name: 'setProposalThresholdAdmin',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'newVotingDelay', type: 'uint48' }],
    name: 'setVotingDelayAdmin',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'newVotingPeriod', type: 'uint32' }],
    name: 'setVotingPeriodAdmin',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'isTestnet',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'admin',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'proposalThreshold',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'votingDelay',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'votingPeriod',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

// Types matching the backend repository types
export interface GovernanceConfig {
  config_key: string;
  chain_id: number;
  display_name: string;
  description: string;
  value_wei: string | null;
  value_number: number | null;
  value_percent: number | null;
  value_string: string | null;
  value_unit: string;
  is_synced_to_contract: boolean;
  last_synced_at: string | null;
  last_sync_tx_hash: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  updated_by: string | null;
}

export interface GovernanceConfigUpdate {
  value_wei?: string;
  value_number?: number;
  value_percent?: number;
  value_string?: string;
  is_active?: boolean;
  updated_by: string;
}

export interface GovernanceConfigHistoryEntry {
  id: string;
  config_key: string;
  chain_id: number;
  old_value_wei: string | null;
  new_value_wei: string | null;
  old_value_number: number | null;
  new_value_number: number | null;
  old_value_percent: number | null;
  new_value_percent: number | null;
  old_value_string: string | null;
  new_value_string: string | null;
  changed_by: string;
  changed_at: string;
  change_reason: string | null;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

interface UseGovernanceConfigOptions {
  autoRefresh?: boolean;
  refreshInterval?: number;
}

export function useGovernanceConfig(options: UseGovernanceConfigOptions = {}) {
  const { autoRefresh = false, refreshInterval = 30000 } = options;
  const { address } = useAccount();
  const { addresses, chainId, isContractsLoading } = useContractAddresses();

  // State
  const [configs, setConfigs] = useState<GovernanceConfig[]>([]);
  const [configHistory, setConfigHistory] = useState<Record<string, GovernanceConfigHistoryEntry[]>>({});
  const [isLoading, setIsLoading] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Contract write hooks
  const { data: writeHash, writeContract, isPending: isWritePending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isWriteSuccess } = useWaitForTransactionReceipt({
    hash: writeHash,
  });

  // Clear error
  const clearError = useCallback(() => {
    setError(null);
  }, []);

  // Fetch all governance configs
  const fetchConfigs = useCallback(async (activeOnly = true) => {
    setIsLoading(true);
    setError(null);

    try {
      // Include chainId in the request for the Supabase Edge Function
      const targetChainId = chainId || 11155111; // Default to Sepolia
      const response = await fetch(
        `${API_BASE_URL}/api/v1/governance/config?active_only=${activeOnly}&chainId=${targetChainId}`
      );
      const data: ApiResponse<{ configs: GovernanceConfig[]; chain_id: number; total: number }> & {
        configs?: GovernanceConfig[];
        chain_id?: number;
        total?: number;
      } = await response.json();

      // Handle both nested and flat response formats
      if (data.success) {
        const configsList = data.data?.configs || data.configs || [];
        setConfigs(configsList);
      } else {
        setError(data.error || data.message || 'Failed to fetch governance configs');
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Network error';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, [chainId]);

  // Fetch single config
  const fetchConfigByKey = useCallback(async (configKey: string): Promise<GovernanceConfig | null> => {
    try {
      const targetChainId = chainId || 11155111;
      const response = await fetch(`${API_BASE_URL}/api/v1/governance/config/${configKey}?chainId=${targetChainId}`);
      const data: ApiResponse<GovernanceConfig> & { config?: GovernanceConfig } = await response.json();

      if (data.success) {
        return data.data || data.config || null;
      }
      return null;
    } catch {
      return null;
    }
  }, [chainId]);

  // Update config in database
  const updateConfig = useCallback(
    async (configKey: string, update: Omit<GovernanceConfigUpdate, 'updated_by'>): Promise<boolean> => {
      if (!address) {
        setError('Wallet not connected');
        return false;
      }

      setIsUpdating(true);
      setError(null);

      try {
        const targetChainId = chainId || 11155111;
        const response = await fetch(`${API_BASE_URL}/api/v1/governance/config/${configKey}?chainId=${targetChainId}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            ...update,
            updated_by: address,
          }),
        });

        const data: ApiResponse<GovernanceConfig> & { config?: GovernanceConfig } = await response.json();

        if (data.success) {
          // Update local state
          const updatedConfig = data.data || data.config;
          if (updatedConfig) {
            setConfigs((prev) =>
              prev.map((c) => (c.config_key === configKey ? updatedConfig : c))
            );
          }
          return true;
        } else {
          setError(data.error || data.message || 'Failed to update config');
          return false;
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Network error';
        setError(message);
        return false;
      } finally {
        setIsUpdating(false);
      }
    },
    [address, chainId]
  );

  // Fetch config history
  const fetchConfigHistory = useCallback(
    async (configKey: string, limit = 20): Promise<GovernanceConfigHistoryEntry[]> => {
      try {
        const response = await fetch(
          `${API_BASE_URL}/api/v1/governance/config/${configKey}/history?limit=${limit}`
        );
        const data: ApiResponse<{ history: GovernanceConfigHistoryEntry[] }> & {
          history?: GovernanceConfigHistoryEntry[];
        } = await response.json();

        if (data.success) {
          const historyList = data.data?.history || data.history || [];
          setConfigHistory((prev) => ({
            ...prev,
            [configKey]: historyList,
          }));
          return historyList;
        }
        return [];
      } catch {
        return [];
      }
    },
    []
  );

  // Mark config as synced in database
  const markConfigSynced = useCallback(
    async (configKey: string, txHash: string): Promise<boolean> => {
      try {
        const response = await fetch(`${API_BASE_URL}/api/v1/governance/config/${configKey}/sync`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ tx_hash: txHash }),
        });

        const data: ApiResponse<GovernanceConfig> & { config?: GovernanceConfig } = await response.json();

        if (data.success) {
          // Update local state
          const updatedConfig = data.data || data.config;
          if (updatedConfig) {
            setConfigs((prev) =>
              prev.map((c) => (c.config_key === configKey ? updatedConfig : c))
            );
          }
          return true;
        }
        return false;
      } catch {
        return false;
      }
    },
    []
  );

  // Sync proposal threshold to smart contract
  const syncProposalThreshold = useCallback(
    async (newThreshold: bigint): Promise<string | null> => {
      if (!addresses?.NexusGovernor) {
        setError('Governor contract address not available');
        return null;
      }

      setIsSyncing(true);
      setError(null);

      try {
        writeContract({
          address: addresses.NexusGovernor as `0x${string}`,
          abi: GOVERNOR_ADMIN_ABI,
          functionName: 'setProposalThresholdAdmin',
          args: [newThreshold],
        });

        return 'pending'; // Transaction is pending
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to sync to contract';
        setError(message);
        setIsSyncing(false);
        return null;
      }
    },
    [addresses, writeContract]
  );

  // Sync voting delay to smart contract
  const syncVotingDelay = useCallback(
    async (newVotingDelay: number): Promise<string | null> => {
      if (!addresses?.NexusGovernor) {
        setError('Governor contract address not available');
        return null;
      }

      setIsSyncing(true);
      setError(null);

      try {
        writeContract({
          address: addresses.NexusGovernor as `0x${string}`,
          abi: GOVERNOR_ADMIN_ABI,
          functionName: 'setVotingDelayAdmin',
          args: [newVotingDelay],
        });

        return 'pending';
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to sync to contract';
        setError(message);
        setIsSyncing(false);
        return null;
      }
    },
    [addresses, writeContract]
  );

  // Sync voting period to smart contract
  const syncVotingPeriod = useCallback(
    async (newVotingPeriod: number): Promise<string | null> => {
      if (!addresses?.NexusGovernor) {
        setError('Governor contract address not available');
        return null;
      }

      setIsSyncing(true);
      setError(null);

      try {
        writeContract({
          address: addresses.NexusGovernor as `0x${string}`,
          abi: GOVERNOR_ADMIN_ABI,
          functionName: 'setVotingPeriodAdmin',
          args: [newVotingPeriod],
        });

        return 'pending';
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to sync to contract';
        setError(message);
        setIsSyncing(false);
        return null;
      }
    },
    [addresses, writeContract]
  );

  // Helper: Convert display value to wei for threshold
  const displayToWei = useCallback((displayValue: number): bigint => {
    return BigInt(Math.floor(displayValue * 10 ** 18));
  }, []);

  // Helper: Convert wei to display value
  const weiToDisplay = useCallback((weiValue: string | null): number => {
    if (!weiValue) return 0;
    return Number(BigInt(weiValue) / BigInt(10 ** 18));
  }, []);

  // Get config by key from local state
  const getConfigByKey = useCallback(
    (configKey: string): GovernanceConfig | undefined => {
      return configs.find((c) => c.config_key === configKey);
    },
    [configs]
  );

  // Reload configs from database
  const reloadConfigs = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/v1/governance/config/reload`, {
        method: 'POST',
      });
      const data = await response.json();
      if (data.success) {
        await fetchConfigs();
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }, [fetchConfigs]);

  // Refresh all data
  const refresh = useCallback(async () => {
    await fetchConfigs();
  }, [fetchConfigs]);

  // Handle write success - mark as synced and reset syncing state
  useEffect(() => {
    if (isWriteSuccess && writeHash) {
      setIsSyncing(false);
      // Note: The caller should use markConfigSynced with the tx hash
    }
  }, [isWriteSuccess, writeHash]);

  // Initial fetch
  useEffect(() => {
    fetchConfigs();
  }, [fetchConfigs]);

  // Auto refresh
  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      refresh();
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, refreshInterval, refresh]);

  return {
    // Data
    configs,
    configHistory,
    chainId,
    governorAddress: addresses?.NexusGovernor,

    // Actions
    fetchConfigs,
    fetchConfigByKey,
    updateConfig,
    fetchConfigHistory,
    markConfigSynced,
    syncProposalThreshold,
    syncVotingDelay,
    syncVotingPeriod,
    getConfigByKey,
    reloadConfigs,
    refresh,

    // Helpers
    displayToWei,
    weiToDisplay,

    // State
    isLoading,
    isUpdating,
    isSyncing,
    isContractsLoading,
    isWritePending,
    isConfirming,
    writeHash,
    isWriteSuccess,
    error,
    clearError,
  };
}
