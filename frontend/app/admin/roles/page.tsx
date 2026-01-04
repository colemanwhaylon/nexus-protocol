'use client';

import { useState, useEffect, useCallback } from 'react';
import { useChainId, useReadContracts, useAccount, usePublicClient } from 'wagmi';
import { parseAbiItem } from 'viem';
import { RoleManager, RoleTable } from '@/components/features/Admin';
import {
  useAdmin,
  useRoleMembers,
  useAllRoleAdmins,
  ROLES,
  ROLE_METADATA,
  getRoleHash,
  getRoleName,
  accessControlAbi,
  ROLE_EVENTS,
} from '@/hooks/useAdmin';
import { useNotifications } from '@/hooks/useNotifications';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { AlertCircle, ShieldAlert, History, Shield, Clock } from 'lucide-react';
import type { Address } from 'viem';

interface RoleAssignment {
  role: string;
  roleName: string;
  account: string;
  grantedAt?: number;
  grantedBy?: string;
}

interface RoleEvent {
  type: 'granted' | 'revoked';
  role: string;
  roleName: string;
  account: string;
  sender: string;
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
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

// Helper to shorten addresses
function shortenAddress(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export default function RolesPage() {
  const chainId = useChainId();
  const { address: connectedAddress } = useAccount();
  const publicClient = usePublicClient();
  const [roleAssignments, setRoleAssignments] = useState<RoleAssignment[]>([]);
  const [roleEvents, setRoleEvents] = useState<RoleEvent[]>([]);
  const [isLoadingMembers, setIsLoadingMembers] = useState(true);
  const [isLoadingEvents, setIsLoadingEvents] = useState(true);

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

  const { roleAdmins } = useAllRoleAdmins(chainId);

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

  // Fetch role events from contract logs
  const fetchRoleEvents = useCallback(async () => {
    if (!publicClient || !isContractDeployed || !accessControlAddress) {
      setIsLoadingEvents(false);
      return;
    }

    setIsLoadingEvents(true);

    try {
      // Fetch RoleGranted events
      const grantedLogs = await publicClient.getLogs({
        address: accessControlAddress as Address,
        event: parseAbiItem(ROLE_EVENTS.RoleGranted),
        fromBlock: 'earliest',
        toBlock: 'latest',
      });

      // Fetch RoleRevoked events
      const revokedLogs = await publicClient.getLogs({
        address: accessControlAddress as Address,
        event: parseAbiItem(ROLE_EVENTS.RoleRevoked),
        fromBlock: 'earliest',
        toBlock: 'latest',
      });

      // Process granted events
      const grantedEvents: RoleEvent[] = grantedLogs.map((log) => {
        const role = log.args.role as string;
        return {
          type: 'granted' as const,
          role,
          roleName: getRoleName(role as `0x${string}`),
          account: log.args.account as string,
          sender: log.args.sender as string,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        };
      });

      // Process revoked events
      const revokedEvents: RoleEvent[] = revokedLogs.map((log) => {
        const role = log.args.role as string;
        return {
          type: 'revoked' as const,
          role,
          roleName: getRoleName(role as `0x${string}`),
          account: log.args.account as string,
          sender: log.args.sender as string,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
        };
      });

      // Combine and sort by block number (newest first)
      const allEvents = [...grantedEvents, ...revokedEvents].sort(
        (a, b) => Number(b.blockNumber - a.blockNumber)
      );

      // Try to get block timestamps for the most recent events
      const recentEvents = allEvents.slice(0, 20);
      const eventsWithTimestamps = await Promise.all(
        recentEvents.map(async (event) => {
          try {
            const block = await publicClient.getBlock({ blockNumber: event.blockNumber });
            return { ...event, timestamp: Number(block.timestamp) };
          } catch {
            return event;
          }
        })
      );

      // Replace recent events with timestamped versions
      const finalEvents = [
        ...eventsWithTimestamps,
        ...allEvents.slice(20),
      ];

      setRoleEvents(finalEvents);
    } catch (error) {
      console.error('Error fetching role events:', error);
      setRoleEvents([]);
    } finally {
      setIsLoadingEvents(false);
    }
  }, [publicClient, isContractDeployed, accessControlAddress]);

  // Fetch events on mount
  useEffect(() => {
    fetchRoleEvents();
  }, [fetchRoleEvents]);

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

            // Find grant event for this assignment to get timestamp and sender
            const grantEvent = roleEvents.find(
              (e) => e.type === 'granted' &&
                     e.role === hash &&
                     e.account.toLowerCase() === (result.result as string).toLowerCase()
            );

            assignments.push({
              role: id,
              roleName: metadata?.name || id,
              account: result.result as string,
              grantedAt: grantEvent?.timestamp,
              grantedBy: grantEvent?.sender,
            });
          }
          queryIndex++;
        }
      }
    }

    setRoleAssignments(assignments);
    setIsLoadingMembers(false);
  }, [memberResults, isLoadingMemberResults, roleCounts, isContractDeployed, memberQueries.length, roleEvents]);

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
        fetchRoleEvents();
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
        fetchRoleEvents();
      }, 2000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      notifyError('Revoke Role Failed', errorMessage);
      throw error;
    }
  };

  // Format timestamp for display
  const formatEventTime = (timestamp?: number) => {
    if (!timestamp) return 'Unknown';
    return new Date(timestamp * 1000).toLocaleString();
  };

  // Get explorer URL for transaction
  const getExplorerTxUrl = (txHash: string) => {
    switch (chainId) {
      case 1:
        return `https://etherscan.io/tx/${txHash}`;
      case 11155111:
        return `https://sepolia.etherscan.io/tx/${txHash}`;
      default:
        return '#';
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

      {/* Role Hierarchy Overview */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Role Hierarchy
          </CardTitle>
          <CardDescription>
            Each role is administered by its parent role
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            {AVAILABLE_ROLES.map((role) => {
              const roleHash = getRoleHash(role.id);
              const adminRoleHash = roleAdmins[roleHash as keyof typeof roleAdmins];
              const adminRoleName = adminRoleHash ? getRoleName(adminRoleHash) : 'Loading...';
              const memberCount = roleCounts[roleHash as keyof typeof roleCounts];

              return (
                <div key={role.id} className="p-3 rounded-lg border space-y-2">
                  <div className="flex items-center justify-between">
                    <Badge variant={role.id === 'DEFAULT_ADMIN_ROLE' ? 'destructive' : 'secondary'}>
                      {role.name}
                    </Badge>
                    <span className="text-sm font-medium">
                      {memberCount !== undefined ? Number(memberCount) : '-'}
                    </span>
                  </div>
                  <p className="text-xs text-muted-foreground">{role.description}</p>
                  <p className="text-xs">
                    <span className="text-muted-foreground">Admin: </span>
                    <span className="font-medium">{adminRoleName}</span>
                  </p>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      <Tabs defaultValue="manage" className="space-y-6">
        <TabsList>
          <TabsTrigger value="manage">Manage Roles</TabsTrigger>
          <TabsTrigger value="history">
            <History className="h-4 w-4 mr-2" />
            Event History
          </TabsTrigger>
        </TabsList>

        <TabsContent value="manage">
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
        </TabsContent>

        <TabsContent value="history">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <History className="h-5 w-5" />
                Role Event History
              </CardTitle>
              <CardDescription>
                Recent role grants and revocations from the blockchain
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoadingEvents ? (
                <div className="space-y-3">
                  {[...Array(5)].map((_, i) => (
                    <Skeleton key={i} className="h-16 w-full" />
                  ))}
                </div>
              ) : roleEvents.length === 0 ? (
                <p className="text-center py-8 text-muted-foreground">
                  No role events found
                </p>
              ) : (
                <div className="space-y-3">
                  {roleEvents.slice(0, 20).map((event, index) => (
                    <div
                      key={`${event.transactionHash}-${index}`}
                      className="flex items-start justify-between p-3 rounded-lg border"
                    >
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <Badge variant={event.type === 'granted' ? 'default' : 'destructive'}>
                            {event.type === 'granted' ? 'Granted' : 'Revoked'}
                          </Badge>
                          <Badge variant="outline">{event.roleName}</Badge>
                        </div>
                        <p className="text-sm">
                          <span className="text-muted-foreground">Account: </span>
                          <code className="font-mono text-xs">{shortenAddress(event.account)}</code>
                        </p>
                        <p className="text-sm">
                          <span className="text-muted-foreground">By: </span>
                          <code className="font-mono text-xs">{shortenAddress(event.sender)}</code>
                        </p>
                      </div>
                      <div className="text-right space-y-1">
                        {event.timestamp && (
                          <p className="text-xs text-muted-foreground flex items-center gap-1 justify-end">
                            <Clock className="h-3 w-3" />
                            {formatEventTime(event.timestamp)}
                          </p>
                        )}
                        <a
                          href={getExplorerTxUrl(event.transactionHash)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-xs text-primary hover:underline"
                        >
                          View Tx
                        </a>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
