'use client';

import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import type { Address } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';

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
    name: 'pause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
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

type HexString = ;

// Common role hashes
export const ROLES = {
  ADMIN_ROLE: '0x0000000000000000000000000000000000000000000000000000000000000000' as HexString,
  OPERATOR_ROLE: '0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929' as HexString,
  COMPLIANCE_ROLE: '0x4a4d4c70c054f5e14b5fbf5e5c648d67d5fbd02f02d0f5f5c6f75d5d5c5f4d4c' as HexString,
  PAUSER_ROLE: '0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a' as HexString,
};

export function useAdmin(chainId?: number) {
  const { address } = useAccount();
  const addresses = getContractAddresses(chainId);
  const accessControlAddress = addresses.nexusAccessControl as Address;

  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data: isPaused, refetch: refetchPaused } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'paused',
  });

  const { data: isAdmin } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.ADMIN_ROLE, address] : undefined,
    query: { enabled: !!address },
  });

  const { data: isOperator } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.OPERATOR_ROLE, address] : undefined,
    query: { enabled: !!address },
  });

  const { data: isPauser } = useReadContract({
    address: accessControlAddress,
    abi: accessControlAbi,
    functionName: 'hasRole',
    args: address ? [ROLES.PAUSER_ROLE, address] : undefined,
    query: { enabled: !!address },
  });

  const grantRole = (role: HexString, account: Address) => {
    writeContract({
      address: accessControlAddress,
      abi: accessControlAbi,
      functionName: 'grantRole',
      args: [role, account],
    });
  };

  const revokeRole = (role: HexString, account: Address) => {
    writeContract({
      address: accessControlAddress,
      abi: accessControlAbi,
      functionName: 'revokeRole',
      args: [role, account],
    });
  };

  const pause = () => {
    writeContract({
      address: accessControlAddress,
      abi: accessControlAbi,
      functionName: 'pause',
    });
  };

  const unpause = () => {
    writeContract({
      address: accessControlAddress,
      abi: accessControlAbi,
      functionName: 'unpause',
    });
  };

  return {
    grantRole,
    revokeRole,
    pause,
    unpause,
    isPaused: isPaused as boolean | undefined,
    isAdmin: isAdmin as boolean | undefined,
    isOperator: isOperator as boolean | undefined,
    isPauser: isPauser as boolean | undefined,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error: writeError,
    reset,
    refetchPaused,
  };
}
