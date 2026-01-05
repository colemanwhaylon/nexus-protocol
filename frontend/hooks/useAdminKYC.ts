'use client';

import { useState, useCallback, useEffect, useMemo } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract, usePublicClient } from 'wagmi';
import type { Address, Log } from 'viem';
import { useContractAddresses } from '@/hooks/useContractAddresses';
import { useNotifications } from './useNotifications';

// ============ Types ============

export type KYCStatusType = 'pending' | 'approved' | 'rejected' | 'blacklisted';

// KYC Level enum matching contract
export enum KYCLevel {
  None = 0,
  Basic = 1,
  Enhanced = 2,
  Accredited = 3,
}

export interface KYCInfo {
  address: string;
  level: KYCLevel;
  verifiedAt: bigint;
  expiresAt: bigint;
  isWhitelisted: boolean;
  isBlacklisted: boolean;
}

export interface FormattedKYCRequest {
  id: string;
  address: string;
  submittedAt: number;
  expiresAt?: number;
  status: KYCStatusType;
  level: KYCLevel;
  levelName: string;
}

export interface KYCEvent {
  type: 'whitelisted' | 'whitelist_removed' | 'blacklisted' | 'blacklist_removed' | 'kyc_updated';
  account: string;
  timestamp: number;
  blockNumber: bigint;
  transactionHash: string;
  addedBy?: string;
  level?: KYCLevel;
  reason?: string;
}

// ============ Contract ABI ============

const kycRegistryAbi = [
  // Read functions
  {
    name: 'isWhitelisted',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'isBlacklisted',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'getKYCLevel',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint8' }],
  },
  {
    name: 'getKYCInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [
      { name: 'level', type: 'uint8' },
      { name: 'verifiedAt', type: 'uint256' },
      { name: 'expiresAt', type: 'uint256' },
      { name: 'countryCode', type: 'bytes32' },
      { name: 'isWhitelisted', type: 'bool' },
      { name: 'isBlacklisted', type: 'bool' },
    ],
  },
  {
    name: 'isKYCExpired',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'getWhitelistCount',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getBlacklistCount',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getWhitelistedAddresses',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'offset', type: 'uint256' },
      { name: 'limit', type: 'uint256' },
    ],
    outputs: [{ name: 'addresses', type: 'address[]' }],
  },
  {
    name: 'getBlacklistedAddresses',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'offset', type: 'uint256' },
      { name: 'limit', type: 'uint256' },
    ],
    outputs: [{ name: 'addresses', type: 'address[]' }],
  },
  // Write functions
  {
    name: 'addToWhitelist',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [],
  },
  {
    name: 'removeFromWhitelist',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [],
  },
  {
    name: 'addToBlacklist',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'reason', type: 'string' },
    ],
    outputs: [],
  },
  {
    name: 'removeFromBlacklist',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [],
  },
  {
    name: 'setKYC',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'level', type: 'uint8' },
      { name: 'countryCode', type: 'string' },
      { name: 'expiryDuration', type: 'uint256' },
      { name: 'kycProvider', type: 'string' },
      { name: 'kycHash', type: 'bytes32' },
    ],
    outputs: [],
  },
  {
    name: 'revokeKYC',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'reason', type: 'string' },
    ],
    outputs: [],
  },
] as const;

// Event signatures for filtering logs
const EVENT_SIGNATURES = {
  Whitelisted: '0x' + 'aab7954e9d246b167ef88aeddad35209ca2489d95a8aeb59e288d9b19fae5a54',
  WhitelistRemoved: '0x' + '5b1e27c5f7a7e5e32c9d6c8c7d3a6b5a4c3b2a1d0e0f0a0b0c0d0e0f0a0b0c0d',
  Blacklisted: '0x' + 'c8c7d3a6b5a4c3b2a1d0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b',
  BlacklistRemoved: '0x' + 'd0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e',
  KYCUpdated: '0x' + 'e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e0f0a0b0c0d0e0f',
};

// ============ Helper Functions ============

function getLevelName(level: KYCLevel): string {
  switch (level) {
    case KYCLevel.None:
      return 'None';
    case KYCLevel.Basic:
      return 'Basic';
    case KYCLevel.Enhanced:
      return 'Enhanced';
    case KYCLevel.Accredited:
      return 'Accredited';
    default:
      return 'Unknown';
  }
}

function formatKYCInfo(address: string, info: readonly [number, bigint, bigint, `0x${string}`, boolean, boolean]): FormattedKYCRequest {
  const [level, verifiedAt, expiresAt, , isWhitelisted, isBlacklisted] = info;

  let status: KYCStatusType = 'pending';
  if (isBlacklisted) {
    status = 'blacklisted';
  } else if (isWhitelisted && level > KYCLevel.None) {
    status = 'approved';
  } else if (level === KYCLevel.None && !isWhitelisted) {
    status = 'pending';
  }

  return {
    id: address,
    address,
    submittedAt: Number(verifiedAt),
    expiresAt: expiresAt > 0n ? Number(expiresAt) : undefined,
    status,
    level: level as KYCLevel,
    levelName: getLevelName(level as KYCLevel),
  };
}

// ============ Hook Options ============

interface UseAdminKYCOptions {
  autoRefresh?: boolean;
  refreshInterval?: number;
  pageSize?: number;
}

// ============ Main Hook ============

export function useAdminKYC(options: UseAdminKYCOptions = {}) {
  const { autoRefresh = true, refreshInterval = 30000, pageSize = 100 } = options;

  const { address: userAddress } = useAccount();
  const publicClient = usePublicClient();
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const kycRegistryAddress = addresses.nexusKYC as Address;
  const isReady = hasContract('nexusKYC');

  const { notifySuccess, notifyError, notifyAdminAction } = useNotifications();

  // ============ State ============

  const [whitelistedAddresses, setWhitelistedAddresses] = useState<string[]>([]);
  const [blacklistedAddresses, setBlacklistedAddresses] = useState<string[]>([]);
  const [kycInfoMap, setKycInfoMap] = useState<Map<string, FormattedKYCRequest>>(new Map());
  const [events, setEvents] = useState<KYCEvent[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(0);

  // ============ Read Contract Calls ============

  const { data: whitelistCount, refetch: refetchWhitelistCount } = useReadContract({
    address: kycRegistryAddress,
    abi: kycRegistryAbi,
    functionName: 'getWhitelistCount',
    query: { enabled: isReady },
  });

  const { data: blacklistCount, refetch: refetchBlacklistCount } = useReadContract({
    address: kycRegistryAddress,
    abi: kycRegistryAbi,
    functionName: 'getBlacklistCount',
    query: { enabled: isReady },
  });

  // ============ Write Contract Setup ============

  const {
    writeContractAsync,
    data: txHash,
    isPending: isWritePending,
    error: writeError,
    reset: resetWrite,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // ============ Fetch Functions ============

  const fetchWhitelistedAddresses = useCallback(async () => {
    if (!isReady || !publicClient) return [];

    try {
      const count = whitelistCount as bigint | undefined;
      if (!count || count === 0n) return [];

      const addresses: string[] = [];
      let offset = 0n;
      const limit = BigInt(pageSize);

      while (offset < count) {
        const batch = await publicClient.readContract({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'getWhitelistedAddresses',
          args: [offset, limit],
        }) as Address[];

        addresses.push(...batch);
        offset += limit;
      }

      return addresses;
    } catch (err) {
      console.error('Error fetching whitelisted addresses:', err);
      return [];
    }
  }, [isReady, publicClient, kycRegistryAddress, whitelistCount, pageSize]);

  const fetchBlacklistedAddresses = useCallback(async () => {
    if (!isReady || !publicClient) return [];

    try {
      const count = blacklistCount as bigint | undefined;
      if (!count || count === 0n) return [];

      const addresses: string[] = [];
      let offset = 0n;
      const limit = BigInt(pageSize);

      while (offset < count) {
        const batch = await publicClient.readContract({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'getBlacklistedAddresses',
          args: [offset, limit],
        }) as Address[];

        addresses.push(...batch);
        offset += limit;
      }

      return addresses;
    } catch (err) {
      console.error('Error fetching blacklisted addresses:', err);
      return [];
    }
  }, [isReady, publicClient, kycRegistryAddress, blacklistCount, pageSize]);

  const fetchKYCInfo = useCallback(
    async (address: string): Promise<FormattedKYCRequest | null> => {
      if (!isReady || !publicClient) return null;

      try {
        const info = await publicClient.readContract({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'getKYCInfo',
          args: [address as Address],
        }) as readonly [number, bigint, bigint, `0x${string}`, boolean, boolean];

        return formatKYCInfo(address, info);
      } catch (err) {
        console.error(`Error fetching KYC info for ${address}:`, err);
        return null;
      }
    },
    [isReady, publicClient, kycRegistryAddress]
  );

  const fetchAllKYCInfo = useCallback(async () => {
    if (!isReady) return;

    setIsLoading(true);
    setError(null);

    try {
      // Refresh counts first
      await Promise.all([refetchWhitelistCount(), refetchBlacklistCount()]);

      // Fetch all addresses
      const [whitelist, blacklist] = await Promise.all([
        fetchWhitelistedAddresses(),
        fetchBlacklistedAddresses(),
      ]);

      setWhitelistedAddresses(whitelist);
      setBlacklistedAddresses(blacklist);

      // Fetch KYC info for all unique addresses
      const allAddresses = [...new Set([...whitelist, ...blacklist])];
      const infoMap = new Map<string, FormattedKYCRequest>();

      // Batch fetch in parallel (max 10 concurrent)
      const batchSize = 10;
      for (let i = 0; i < allAddresses.length; i += batchSize) {
        const batch = allAddresses.slice(i, i + batchSize);
        const results = await Promise.all(batch.map((addr) => fetchKYCInfo(addr)));

        results.forEach((info, idx) => {
          if (info) {
            infoMap.set(batch[idx], info);
          }
        });
      }

      setKycInfoMap(infoMap);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch KYC data';
      setError(message);
      console.error('Error fetching KYC data:', err);
    } finally {
      setIsLoading(false);
    }
  }, [
    isReady,
    refetchWhitelistCount,
    refetchBlacklistCount,
    fetchWhitelistedAddresses,
    fetchBlacklistedAddresses,
    fetchKYCInfo,
  ]);

  // ============ Check Single Address ============

  const checkAddress = useCallback(
    async (address: string): Promise<FormattedKYCRequest | null> => {
      return fetchKYCInfo(address);
    },
    [fetchKYCInfo]
  );

  const isWhitelisted = useCallback(
    async (address: string): Promise<boolean> => {
      if (!isReady || !publicClient) return false;

      try {
        return await publicClient.readContract({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'isWhitelisted',
          args: [address as Address],
        }) as boolean;
      } catch {
        return false;
      }
    },
    [isReady, publicClient, kycRegistryAddress]
  );

  const isBlacklisted = useCallback(
    async (address: string): Promise<boolean> => {
      if (!isReady || !publicClient) return false;

      try {
        return await publicClient.readContract({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'isBlacklisted',
          args: [address as Address],
        }) as boolean;
      } catch {
        return false;
      }
    },
    [isReady, publicClient, kycRegistryAddress]
  );

  // ============ Write Functions ============

  const approveKYC = useCallback(
    async (targetAddress: string, level: KYCLevel = KYCLevel.Basic): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Approval Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Approval Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        // First add to whitelist
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'addToWhitelist',
          args: [targetAddress as Address],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifySuccess(
          'KYC Approved',
          `Successfully approved KYC for ${shortAddress}`,
          'admin'
        );

        // Refresh data
        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to approve KYC';
        notifyError('Approval Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, notifySuccess, notifyError, fetchAllKYCInfo]
  );

  const rejectKYC = useCallback(
    async (targetAddress: string, reason: string = 'Verification requirements not met'): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Rejection Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Rejection Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        // Remove from whitelist if whitelisted
        const whitelisted = await isWhitelisted(targetAddress);
        if (whitelisted) {
          await writeContractAsync({
            address: kycRegistryAddress,
            abi: kycRegistryAbi,
            functionName: 'removeFromWhitelist',
            args: [targetAddress as Address],
          });
        }

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifySuccess(
          'KYC Rejected',
          `KYC rejected for ${shortAddress}`,
          'admin'
        );

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to reject KYC';
        notifyError('Rejection Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, isWhitelisted, notifySuccess, notifyError, fetchAllKYCInfo]
  );

  const addToWhitelist = useCallback(
    async (targetAddress: string): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Operation Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Operation Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'addToWhitelist',
          args: [targetAddress as Address],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifyAdminAction('Whitelist', `Added ${shortAddress} to whitelist`, txHash, true);

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to add to whitelist';
        notifyError('Whitelist Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, txHash, notifyAdminAction, notifyError, fetchAllKYCInfo]
  );

  const removeFromWhitelist = useCallback(
    async (targetAddress: string): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Operation Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Operation Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'removeFromWhitelist',
          args: [targetAddress as Address],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifyAdminAction('Whitelist', `Removed ${shortAddress} from whitelist`, txHash, true);

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to remove from whitelist';
        notifyError('Whitelist Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, txHash, notifyAdminAction, notifyError, fetchAllKYCInfo]
  );

  const addToBlacklist = useCallback(
    async (targetAddress: string, reason: string = 'Compliance violation'): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Operation Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Operation Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'addToBlacklist',
          args: [targetAddress as Address, reason],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifyAdminAction('Blacklist', `Added ${shortAddress} to blacklist`, txHash, true);

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to add to blacklist';
        notifyError('Blacklist Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, txHash, notifyAdminAction, notifyError, fetchAllKYCInfo]
  );

  const removeFromBlacklist = useCallback(
    async (targetAddress: string): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Operation Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Operation Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'removeFromBlacklist',
          args: [targetAddress as Address],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifyAdminAction('Blacklist', `Removed ${shortAddress} from blacklist`, txHash, true);

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to remove from blacklist';
        notifyError('Blacklist Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, txHash, notifyAdminAction, notifyError, fetchAllKYCInfo]
  );

  const setVerificationLevel = useCallback(
    async (
      targetAddress: string,
      level: KYCLevel,
      countryCode: string = 'USA',
      expiryDuration: bigint = 365n * 24n * 60n * 60n, // 1 year in seconds
      kycProvider: string = 'Sumsub',
      kycHash: `0x${string}` = '0x0000000000000000000000000000000000000000000000000000000000000000'
    ): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Operation Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Operation Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'setKYC',
          args: [targetAddress as Address, level, countryCode, expiryDuration, kycProvider, kycHash],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        const levelName = getLevelName(level);
        notifyAdminAction('KYC Level', `Set ${shortAddress} to ${levelName} level`, txHash, true);

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to set KYC level';
        notifyError('Set Level Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, txHash, notifyAdminAction, notifyError, fetchAllKYCInfo]
  );

  const revokeKYC = useCallback(
    async (targetAddress: string, reason: string = 'KYC revoked by compliance'): Promise<boolean> => {
      if (!userAddress) {
        notifyError('Operation Failed', 'Wallet not connected');
        return false;
      }

      if (!isReady) {
        notifyError('Operation Failed', 'KYC Registry contract not deployed');
        return false;
      }

      try {
        await writeContractAsync({
          address: kycRegistryAddress,
          abi: kycRegistryAbi,
          functionName: 'revokeKYC',
          args: [targetAddress as Address, reason],
        });

        const shortAddress = `${targetAddress.slice(0, 6)}...${targetAddress.slice(-4)}`;
        notifyAdminAction('KYC Revoked', `Revoked KYC for ${shortAddress}`, txHash, true);

        await fetchAllKYCInfo();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to revoke KYC';
        notifyError('Revoke Failed', message);
        return false;
      }
    },
    [userAddress, isReady, kycRegistryAddress, writeContractAsync, txHash, notifyAdminAction, notifyError, fetchAllKYCInfo]
  );

  // ============ Computed Values ============

  const formattedRequests = useMemo(() => {
    return Array.from(kycInfoMap.values());
  }, [kycInfoMap]);

  const stats = useMemo(() => {
    const approved = formattedRequests.filter((r) => r.status === 'approved').length;
    const pending = formattedRequests.filter((r) => r.status === 'pending').length;
    const rejected = formattedRequests.filter((r) => r.status === 'rejected').length;
    const blacklisted = blacklistedAddresses.length;

    return {
      total: formattedRequests.length,
      pending,
      approved,
      rejected,
      blacklisted,
      whitelisted: Number(whitelistCount || 0),
    };
  }, [formattedRequests, blacklistedAddresses, whitelistCount]);

  // ============ Effects ============

  // Initial fetch
  useEffect(() => {
    if (isReady) {
      fetchAllKYCInfo();
    } else {
      setIsLoading(false);
    }
  }, [isReady, fetchAllKYCInfo]);

  // Auto-refresh
  useEffect(() => {
    if (!autoRefresh || !isReady) return;

    const interval = setInterval(() => {
      fetchAllKYCInfo();
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, refreshInterval, isReady, fetchAllKYCInfo]);

  // ============ Return ============

  return {
    // Data
    formattedRequests,
    whitelistedAddresses,
    blacklistedAddresses,
    stats,
    events,

    // Single address operations
    checkAddress,
    isWhitelisted,
    isBlacklisted,

    // Admin actions
    approveKYC,
    rejectKYC,
    addToWhitelist,
    removeFromWhitelist,
    addToBlacklist,
    removeFromBlacklist,
    setVerificationLevel,
    revokeKYC,

    // Refresh
    refresh: fetchAllKYCInfo,

    // Loading states
    isLoading,
    isProcessing: isWritePending || isConfirming,
    isApproving: isWritePending,
    isRejecting: isWritePending,

    // Transaction state
    txHash,
    isTxSuccess,

    // Error
    error,
    writeError,
    clearError: () => setError(null),
    resetWrite,

    // Contract info
    isAddressesLoading: addressesLoading,
    isReady,
    kycRegistryAddress,

    // Pagination
    currentPage,
    setCurrentPage,
    pageSize,
  };
}
