'use client';

import { useCallback, useEffect, useRef } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { keccak256, toBytes } from 'viem';
import { useContractAddresses } from '@/hooks/useContractAddresses';
import { useNotifications } from '@/hooks/useNotifications';

const accessControlAbi = [
  {
    name: 'grantRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  {
    name: 'revokeRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  {
    name: 'hasRole',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'getRoleMemberCount',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getRoleMember',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'index', type: 'uint256' },
    ],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'getRoleAdmin',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
    ],
    outputs: [{ type: 'bytes32' }],
  },
  {
    name: 'pause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'reason', type: 'string' }],
    outputs: [],
  },
  {
    name: 'unpause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'paused',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
] as const;

// Role event signatures for log fetching
export const ROLE_EVENTS = {
  RoleGranted: 'event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)',
  RoleRevoked: 'event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)',
} as const;

const emergencyAbi = [
  {
    name: 'pauseContract',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [],
  },
  {
    name: 'unpauseContract',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [],
  },
  {
    name: 'contractPaused',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'globalPause',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'initiateGlobalPause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'liftGlobalPause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const;

export { accessControlAbi, emergencyAbi };

type HexString = `0x${string}`;

// Operation types for tracking pending operations
type AdminOperation =
  | { type: 'grantRole'; role: HexString; account: Address }
  | { type: 'revokeRole'; role: HexString; account: Address }
  | { type: 'emergencyPause'; contract: Address; contractName: string }
  | { type: 'emergencyUnpause'; contract: Address; contractName: string }
  | { type: 'pause'; reason: string }
  | { type: 'unpause' };

// Role hashes matching NexusAccessControl.sol
export const ROLES = {
  DEFAULT_ADMIN_ROLE: '0x0000000000000000000000000000000000000000000000000000000000000000' as HexString,
  ADMIN_ROLE: keccak256(toBytes('ADMIN_ROLE')) as HexString,
  OPERATOR_ROLE: keccak256(toBytes('OPERATOR_ROLE')) as HexString,
  COMPLIANCE_ROLE: keccak256(toBytes('COMPLIANCE_ROLE')) as HexString,
  PAUSER_ROLE: keccak256(toBytes('PAUSER_ROLE')) as HexString,
  GUARDIAN_ROLE: keccak256(toBytes('GUARDIAN_ROLE')) as HexString,
  UPGRADER_ROLE: keccak256(toBytes('UPGRADER_ROLE')) as HexString,
  SLASHER_ROLE: keccak256(toBytes('SLASHER_ROLE')) as HexString,
};

// Role metadata for UI display
export const ROLE_METADATA: Record<HexString, { id: string; name: string; description: string }> = {
  [ROLES.DEFAULT_ADMIN_ROLE]: { id: 'DEFAULT_ADMIN_ROLE', name: 'Default Admin', description: 'Full administrative access' },
  [ROLES.ADMIN_ROLE]: { id: 'ADMIN_ROLE', name: 'Admin', description: 'Protocol administration' },
  [ROLES.OPERATOR_ROLE]: { id: 'OPERATOR_ROLE', name: 'Operator', description: 'Day-to-day operations' },
  [ROLES.COMPLIANCE_ROLE]: { id: 'COMPLIANCE_ROLE', name: 'Compliance', description: 'KYC/AML management' },
  [ROLES.PAUSER_ROLE]: { id: 'PAUSER_ROLE', name: 'Pauser', description: 'Emergency pause capability' },
  [ROLES.GUARDIAN_ROLE]: { id: 'GUARDIAN_ROLE', name: 'Guardian', description: 'Time-limited emergency powers' },
  [ROLES.UPGRADER_ROLE]: { id: 'UPGRADER_ROLE', name: 'Upgrader', description: 'Contract upgrade authorization' },
  [ROLES.SLASHER_ROLE]: { id: 'SLASHER_ROLE', name: 'Slasher', description: 'Stake slashing authorization' },
};

// Convert role ID to hash
export function getRoleHash(roleId: string): HexString {
  const entry = Object.entries(ROLES).find(([key]) => key === roleId);
  if (entry) {
    return entry[1];
  }
  // If already a hash, return as is
  if (roleId.startsWith('0x')) {
    return roleId as HexString;
  }
  throw new Error(`Unknown role: ${roleId}`);
}

// Get role name from hash
export function getRoleName(roleHash: HexString): string {
  const metadata = ROLE_METADATA[roleHash];
  return metadata?.name || 'Unknown Role';
}

export function useAdmin() {
  const { address } = useAccount();
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const accessControlAddress = addresses.nexusAccessControl as Address;
  const emergencyAddress = addresses.nexusEmergency as Address;
  const isReady = hasContract('nexusAccessControl');

  // Notifications
  const { notifyRoleGranted, notifyRoleRevoked, notifyEmergencyPause, notifyEmergencyUnpause } =
    useNotifications();

  // Track pending operation for notification after success
  const pendingOperationRef = useRef<AdminOperation | null>(null);

  // Access Control write operations
  const {
    writeContractAsync: writeAccessControlAsync,
    data: accessControlHash,
    isPending: isAccessControlPending,
    error: accessControlError,
    reset: resetAccessControl,
  } = useWriteContract();

  const {
    isLoading: isAccessControlConfirming,
    isSuccess: isAccessControlSuccess,
  } = useWaitForTransactionReceipt({ hash: accessControlHash });

  // Emergency write operations
  const {
    writeContractAsync: writeEmergencyAsync,
    data: emergencyHash,
    isPending: isEmergencyPending,
    error: emergencyError,
    reset: resetEmergency,
  } = useWriteContract();

  const {
    isLoading: isEmergencyConfirming,
    isSuccess: isEmergencySuccess,
  } = useWaitForTransactionReceipt({ hash: emergencyHash });

  // Combined states
  const hash = accessControlHash || emergencyHash;
  const isPending = isAccessControlPending || isEmergencyPending;
  const isConfirming = isAccessControlConfirming || isEmergencyConfirming;
  const isSuccess = isAccessControlSuccess || isEmergencySuccess;
  const writeError = accessControlError || emergencyError;

  // Notification effect - fires when transaction succeeds
  useEffect(() => {
    if (isSuccess && pendingOperationRef.current && hash) {
      const op = pendingOperationRef.current;
      const txHash = hash;

      switch (op.type) {
        case 'grantRole':
          notifyRoleGranted(getRoleName(op.role), op.account, txHash);
          break;
        case 'revokeRole':
          notifyRoleRevoked(getRoleName(op.role), op.account, txHash);
          break;
        case 'emergencyPause':
          notifyEmergencyPause(op.contractName, txHash);
          break;
        case 'emergencyUnpause':
          notifyEmergencyUnpause(op.contractName, txHash);
          break;
        case 'pause':
          notifyEmergencyPause('Protocol', txHash);
          break;
        case 'unpause':
          notifyEmergencyUnpause('Protocol', txHash);
          break;
      }

      pendingOperationRef.current = null;
    }
  }, [isSuccess, hash, notifyRoleGranted, notifyRoleRevoked, notifyEmergencyPause, notifyEmergencyUnpause]);

  // Reset all write states
  const reset = useCallback(() => {
    resetAccessControl();
    resetEmergency();
    pendingOperationRef.current = null;
  }, [resetAccessControl, resetEmergency]);

  const { data: isPaused, refetch: refetchPaused } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'paused',
    query: { enabled: isReady },
  });

  const { data: isDefaultAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.DEFAULT_ADMIN_ROLE, address] : undefined,
    query: { enabled: isReady && !!address },
  });

  const { data: isAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.ADMIN_ROLE, address] : undefined,
    query: { enabled: isReady && !!address },
  });

  const { data: isOperator } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.OPERATOR_ROLE, address] : undefined,
    query: { enabled: isReady && !!address },
  });

  const { data: isPauser } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.PAUSER_ROLE, address] : undefined,
    query: { enabled: isReady && !!address },
  });

  /**
   * Grant a role to an address
   */
  const grantRole = useCallback(
    async (role: HexString, account: Address): Promise<`0x${string}`> => {
      pendingOperationRef.current = { type: 'grantRole', role, account };
      const txHash = await writeAccessControlAsync({
        address: accessControlAddress,
        abi: accessControlAbi,
        functionName: 'grantRole',
        args: [role, account],
      });
      return txHash;
    },
    [accessControlAddress, writeAccessControlAsync]
  );

  /**
   * Revoke a role from an address
   */
  const revokeRole = useCallback(
    async (role: HexString, account: Address): Promise<`0x${string}`> => {
      pendingOperationRef.current = { type: 'revokeRole', role, account };
      const txHash = await writeAccessControlAsync({
        address: accessControlAddress,
        abi: accessControlAbi,
        functionName: 'revokeRole',
        args: [role, account],
      });
      return txHash;
    },
    [accessControlAddress, writeAccessControlAsync]
  );

  /**
   * Pause the protocol with a reason
   */
  const pause = useCallback(
    async (reason: string = 'Emergency pause'): Promise<`0x${string}`> => {
      pendingOperationRef.current = { type: 'pause', reason };
      const txHash = await writeAccessControlAsync({
        address: accessControlAddress,
        abi: accessControlAbi,
        functionName: 'pause',
        args: [reason],
      });
      return txHash;
    },
    [accessControlAddress, writeAccessControlAsync]
  );

  /**
   * Unpause the protocol
   */
  const unpause = useCallback(async (): Promise<`0x${string}`> => {
    pendingOperationRef.current = { type: 'unpause' };
    const txHash = await writeAccessControlAsync({
      address: accessControlAddress,
      abi: accessControlAbi,
      functionName: 'unpause',
    });
    return txHash;
  }, [accessControlAddress, writeAccessControlAsync]);

  /**
   * Emergency pause a specific contract
   */
  const emergencyPause = useCallback(
    async (contractAddress: Address, contractName: string = 'Contract'): Promise<`0x${string}`> => {
      pendingOperationRef.current = { type: 'emergencyPause', contract: contractAddress, contractName };
      const txHash = await writeEmergencyAsync({
        address: emergencyAddress,
        abi: emergencyAbi,
        functionName: 'pauseContract',
        args: [contractAddress],
      });
      return txHash;
    },
    [emergencyAddress, writeEmergencyAsync]
  );

  /**
   * Unpause a specific contract
   */
  const emergencyUnpause = useCallback(
    async (contractAddress: Address, contractName: string = 'Contract'): Promise<`0x${string}`> => {
      pendingOperationRef.current = { type: 'emergencyUnpause', contract: contractAddress, contractName };
      const txHash = await writeEmergencyAsync({
        address: emergencyAddress,
        abi: emergencyAbi,
        functionName: 'unpauseContract',
        args: [contractAddress],
      });
      return txHash;
    },
    [emergencyAddress, writeEmergencyAsync]
  );

  return {
    // Loading state from contract addresses
    isAddressesLoading: addressesLoading,
    isReady,

    // Contract addresses
    accessControlAddress,
    emergencyAddress,

    // Write functions
    grantRole,
    revokeRole,
    pause,
    unpause,
    emergencyPause,
    emergencyUnpause,

    // Current user role status
    isDefaultAdmin: isDefaultAdmin as boolean | undefined,
    isAdmin: isAdmin as boolean | undefined,
    isOperator: isOperator as boolean | undefined,
    isPauser: isPauser as boolean | undefined,
    canManageRoles: (isDefaultAdmin || isAdmin) as boolean | undefined,

    // Protocol status
    isPaused: isPaused as boolean | undefined,

    // Transaction state
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,

    // Refetch functions
    refetchPaused,
  };
}

/**
 * Hook to check if an account has a specific role
 */
export function useHasRole(role: HexString, account: Address | undefined) {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const accessControlAddress = addresses.nexusAccessControl as Address;
  const isReady = hasContract('nexusAccessControl');

  const { data, refetch, isLoading, error } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: account ? [role, account] : undefined,
    query: { enabled: isReady && !!account },
  });

  return {
    hasRole: data as boolean | undefined,
    refetch,
    isLoading: addressesLoading || isLoading,
    isReady,
    error,
  };
}

/**
 * Hook to get a specific member of a role by index
 */
export function useRoleMember(role: HexString, index: number) {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const accessControlAddress = addresses.nexusAccessControl as Address;
  const isReady = hasContract('nexusAccessControl');

  const { data, refetch, isLoading, error } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleMember',
    args: [role, BigInt(index)],
    query: { enabled: isReady && index >= 0 },
  });

  return {
    member: data as Address | undefined,
    refetch,
    isLoading: addressesLoading || isLoading,
    isReady,
    error,
  };
}

/**
 * Hook to check if a specific contract is paused via Emergency contract
 */
export function useIsContractPaused(contractAddress: Address) {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const emergencyAddress = addresses.nexusEmergency as Address;
  const isReady = hasContract('nexusEmergency');

  const { data, refetch, isLoading, error } = useReadContract({
    address: emergencyAddress,
    abi: emergencyAbi,
    functionName: 'contractPaused',
    args: [contractAddress],
    query: { enabled: isReady },
  });

  return {
    isPaused: data as boolean | undefined,
    refetch,
    isLoading: addressesLoading || isLoading,
    isReady,
    error,
  };
}

/**
 * Hook to get global pause status from Emergency contract
 */
export function useGlobalPause() {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const emergencyAddress = addresses.nexusEmergency as Address;
  const isReady = hasContract('nexusEmergency');

  const { data, refetch, isLoading, error } = useReadContract({
    address: emergencyAddress,
    abi: emergencyAbi,
    functionName: 'globalPause',
    query: { enabled: isReady },
  });

  return {
    isGlobalPause: data as boolean | undefined,
    refetch,
    isLoading: addressesLoading || isLoading,
    isReady,
    error,
  };
}

// Hook for fetching role members from the contract
export function useRoleMembers() {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const accessControlAddress = addresses.nexusAccessControl as Address;
  const isReady = hasContract('nexusAccessControl');

  // Get member counts for each role
  const { data: defaultAdminCount, refetch: refetchDefaultAdminCount } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleMemberCount',
    args: [ROLES.DEFAULT_ADMIN_ROLE],
    query: { enabled: isReady },
  });

  const { data: adminCount, refetch: refetchAdminCount } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleMemberCount',
    args: [ROLES.ADMIN_ROLE],
    query: { enabled: isReady },
  });

  const { data: operatorCount, refetch: refetchOperatorCount } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleMemberCount',
    args: [ROLES.OPERATOR_ROLE],
    query: { enabled: isReady },
  });

  const { data: complianceCount, refetch: refetchComplianceCount } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleMemberCount',
    args: [ROLES.COMPLIANCE_ROLE],
    query: { enabled: isReady },
  });

  const { data: pauserCount, refetch: refetchPauserCount } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleMemberCount',
    args: [ROLES.PAUSER_ROLE],
    query: { enabled: isReady },
  });

  const refetchAllCounts = useCallback(() => {
    refetchDefaultAdminCount();
    refetchAdminCount();
    refetchOperatorCount();
    refetchComplianceCount();
    refetchPauserCount();
  }, [refetchDefaultAdminCount, refetchAdminCount, refetchOperatorCount, refetchComplianceCount, refetchPauserCount]);

  return {
    isAddressesLoading: addressesLoading,
    isReady,
    accessControlAddress,
    roleCounts: {
      [ROLES.DEFAULT_ADMIN_ROLE]: defaultAdminCount as bigint | undefined,
      [ROLES.ADMIN_ROLE]: adminCount as bigint | undefined,
      [ROLES.OPERATOR_ROLE]: operatorCount as bigint | undefined,
      [ROLES.COMPLIANCE_ROLE]: complianceCount as bigint | undefined,
      [ROLES.PAUSER_ROLE]: pauserCount as bigint | undefined,
    },
    refetchAllCounts,
  };
}

/**
 * Hook to get the admin role for a specific role
 */
export function useRoleAdmin(role: HexString) {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const accessControlAddress = addresses.nexusAccessControl as Address;
  const isReady = hasContract('nexusAccessControl');

  const { data, refetch, isLoading, error } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleAdmin',
    args: [role],
    query: { enabled: isReady },
  });

  return {
    adminRole: data as HexString | undefined,
    adminRoleName: data ? getRoleName(data as HexString) : undefined,
    refetch,
    isLoading: addressesLoading || isLoading,
    isReady,
    error,
  };
}

/**
 * Hook to get all role admins for the standard roles
 */
export function useAllRoleAdmins() {
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const accessControlAddress = addresses.nexusAccessControl as Address;
  const isReady = hasContract('nexusAccessControl');

  const { data: defaultAdminAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleAdmin',
    args: [ROLES.DEFAULT_ADMIN_ROLE],
    query: { enabled: isReady },
  });

  const { data: adminAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleAdmin',
    args: [ROLES.ADMIN_ROLE],
    query: { enabled: isReady },
  });

  const { data: operatorAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleAdmin',
    args: [ROLES.OPERATOR_ROLE],
    query: { enabled: isReady },
  });

  const { data: complianceAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleAdmin',
    args: [ROLES.COMPLIANCE_ROLE],
    query: { enabled: isReady },
  });

  const { data: pauserAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'getRoleAdmin',
    args: [ROLES.PAUSER_ROLE],
    query: { enabled: isReady },
  });

  return {
    isAddressesLoading: addressesLoading,
    isReady,
    roleAdmins: {
      [ROLES.DEFAULT_ADMIN_ROLE]: defaultAdminAdmin as HexString | undefined,
      [ROLES.ADMIN_ROLE]: adminAdmin as HexString | undefined,
      [ROLES.OPERATOR_ROLE]: operatorAdmin as HexString | undefined,
      [ROLES.COMPLIANCE_ROLE]: complianceAdmin as HexString | undefined,
      [ROLES.PAUSER_ROLE]: pauserAdmin as HexString | undefined,
    },
  };
}
