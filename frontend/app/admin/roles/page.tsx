'use client';

import { useState, useEffect, useCallback } from 'react';
import { useChainId, useReadContracts, useAccount } from 'wagmi';
import { RoleManager, RoleTable } from '@/components/features/Admin';
import { useAdmin, useRoleMembers, ROLES, ROLE_METADATA, getRoleHash, accessControlAbi } from '@/hooks/useAdmin';
import { useNotifications } from '@/hooks/useNotifications';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { AlertCircle, ShieldAlert } from 'lucide-react';
import type { Address } from 'viem';

interface RoleAssignment {
  role: string;
  roleName: string;
  account: string;
  grantedAt?: number;
  grantedBy?: string;
}

// Define available roles for the UI
const AVAILABLE_ROLES = [
  { id: 'DEFAULT_ADMIN_ROLE', name: 'Default Admin', description: 'Full administrative access' },
  { id: 'ADMIN_ROLE', name: 'Admin', description: 'Protocol administration' },
  { id: 'OPERATOR_ROLE', name: 'Operator', description: 'Day-to-day operations' },
  { id: 'COMPLIANCE_ROLE', name: 'Compliance', description: 'KYC/AML management' },
  { id: 'PAUSER_ROLE', name: 'Pauser', description: 'Emergency pause capability' },
];

// Roles to enumerate members for
const ROLES_TO_ENUMERATE = [
  { hash: ROLES.DEFAULT_ADMIN_ROLE, id: 'DEFAULT_ADMIN_ROLE' },
  { hash: ROLES.ADMIN_ROLE, id: 'ADMIN_ROLE' },
  { hash: ROLES.OPERATOR_ROLE, id: 'OPERATOR_ROLE' },
  { hash: ROLES.COMPLIANCE_ROLE, id: 'COMPLIANCE_ROLE' },
  { hash: ROLES.PAUSER_ROLE, id: 'PAUSER_ROLE' },
];

export default function RolesPage() {
  const chainId = useChainId();
  const { address: connectedAddress } = useAccount();
  const [roleAssignments, setRoleAssignments] = useState<RoleAssignment[]>([]);
  const [isLoadingMembers, setIsLoadingMembers] = useState(true);

  // Get admin hooks
  const {
    grantRole,
    revokeRole,
    isPending,
    canManageRoles,
    accessControlAddress,
  } = useAdmin(chainId);

  const {
    isContractDeployed,
    roleCounts,
    refetchAllCounts,
  } = useRoleMembers(chainId);

  const { notifyRoleGranted, notifyRoleRevoked, notifyError } = useNotifications();

  // Build contract read calls to fetch all role members
  const buildMemberQueries = useCallback(() => {
    if (!isContractDeployed) return [];

    const queries: Array<{
      address: Address;
      abi: typeof accessControlAbi;
      functionName: 'getRoleMember';
      args: [string, bigint];
    }> = [];

    for (const { hash } of ROLES_TO_ENUMERATE) {
      const count = roleCounts[hash];
      if (count && count > 0n) {
        for (let i = 0n; i < count; i++) {
          queries.push({
            address: accessControlAddress as Address,
            abi: accessControlAbi,
            functionName: 'getRoleMember',
            args: [hash, i],
          });
        }
      }
    }

    return queries;
  }, [isContractDeployed, roleCounts, accessControlAddress]);

  // Fetch all role members using multicall
  const memberQueries = buildMemberQueries();
  const { data: memberResults, refetch: refetchMembers, isLoading: isLoadingMemberResults } = useReadContracts({
    contracts: memberQueries,
    query: {
      enabled: memberQueries.length > 0,
    },
  });

  // Process member results into role assignments
  useEffect(() => {
    if (!isContractDeployed) {
      setIsLoadingMembers(false);
      return;
    }

    if (memberQueries.length === 0) {
      // No members to fetch
      setRoleAssignments([]);
      setIsLoadingMembers(false);
      return;
    }

    if (!memberResults || isLoadingMemberResults) {
      return;
    }

    const assignments: RoleAssignment[] = [];
    let queryIndex = 0;

    for (const { hash, id } of ROLES_TO_ENUMERATE) {
      const count = roleCounts[hash];
      if (count && count > 0n) {
        for (let i = 0n; i < count; i++) {
          const result = memberResults[queryIndex];
          if (result?.status === 'success' && result.result) {
            const metadata = ROLE_METADATA[hash as keyof typeof ROLE_METADATA];
            assignments.push({
              role: id,
              roleName: metadata?.name || id,
              account: result.result as string,
              // Note: The contract doesn't store grant timestamps, so we omit them
            });
          }
          queryIndex++;
        }
      }
    }

    setRoleAssignments(assignments);
    setIsLoadingMembers(false);
  }, [memberResults, isLoadingMemberResults, roleCounts, isContractDeployed, memberQueries.length]);

  // Handle granting a role
  const handleGrantRole = async (roleId: string, account: Address) => {
    try {
      const roleHash = getRoleHash(roleId);
      const metadata = ROLE_METADATA[roleHash as keyof typeof ROLE_METADATA];
      const roleName = metadata?.name || roleId;

      const txHash = await grantRole(roleHash, account);
      notifyRoleGranted(roleName, account, txHash);

      // Refetch role data after successful grant
      setTimeout(() => {
        refetchAllCounts();
        refetchMembers();
      }, 2000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      notifyError('Grant Role Failed', errorMessage);
      throw error;
    }
  };

  // Handle revoking a role
  const handleRevokeRole = async (roleId: string, account: string) => {
    try {
      const roleHash = getRoleHash(roleId);
      const metadata = ROLE_METADATA[roleHash as keyof typeof ROLE_METADATA];
      const roleName = metadata?.name || roleId;

      const txHash = await revokeRole(roleHash, account as Address);
      notifyRoleRevoked(roleName, account, txHash);

      // Refetch role data after successful revoke
      setTimeout(() => {
        refetchAllCounts();
        refetchMembers();
      }, 2000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      notifyError('Revoke Role Failed', errorMessage);
      throw error;
    }
  };

  // Show warning if contract not deployed
  if (!isContractDeployed) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold">Role Management</h1>
          <p className="text-muted-foreground">
            Manage protocol roles and permissions
          </p>
        </div>
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Contract Not Deployed</AlertTitle>
          <AlertDescription>
            The NexusAccessControl contract is not deployed on this network (Chain ID: {chainId}).
            Please deploy the contract or switch to a network where it is deployed.
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  // Show warning if user doesn't have admin role
  const showNoPermissionWarning = connectedAddress && canManageRoles === false;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Role Management</h1>
        <p className="text-muted-foreground">
          Manage protocol roles and permissions
        </p>
      </div>

      {showNoPermissionWarning && (
        <Alert className="mb-6" variant="destructive">
          <ShieldAlert className="h-4 w-4" />
          <AlertTitle>Insufficient Permissions</AlertTitle>
          <AlertDescription>
            Your connected wallet does not have admin privileges.
            You can view role assignments but cannot grant or revoke roles.
          </AlertDescription>
        </Alert>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Role Manager - Grant/Revoke */}
        <RoleManager
          roles={AVAILABLE_ROLES}
          onGrantRole={handleGrantRole}
          onRevokeRole={handleRevokeRole}
          isLoading={isPending}
          disabled={!canManageRoles}
        />

        {/* Current Assignments */}
        <RoleTable
          assignments={roleAssignments}
          chainId={chainId}
          onRevoke={handleRevokeRole}
          isLoading={isLoadingMembers || isPending}
          canRevoke={!!canManageRoles}
        />
      </div>
    </div>
  );
}
