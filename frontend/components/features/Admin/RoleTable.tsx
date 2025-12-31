'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import { ShieldCheck, UserMinus, ExternalLink, Copy, Check } from 'lucide-react';
import { useState } from 'react';

interface RoleAssignment {
  role: string;
  roleName: string;
  account: string;
  grantedAt?: number;
  grantedBy?: string;
}

interface RoleTableProps {
  assignments?: RoleAssignment[];
  chainId?: number;
  onRevoke?: (role: string, account: string) => Promise<void>;
  isLoading?: boolean;
  canRevoke?: boolean;
}

export function RoleTable({
  assignments = [],
  chainId,
  onRevoke,
  isLoading,
  canRevoke = false,
}: RoleTableProps) {
  const [copiedAddress, setCopiedAddress] = useState<string | null>(null);
  const [revokingId, setRevokingId] = useState<string | null>(null);

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const formatDate = (timestamp?: number) =>
    timestamp ? new Date(timestamp * 1000).toLocaleDateString() : 'Unknown';

  const getExplorerUrl = (address: string) => {
    switch (chainId) {
      case 1:
        return `https://etherscan.io/address/${address}`;
      case 11155111:
        return `https://sepolia.etherscan.io/address/${address}`;
      default:
        return '#';
    }
  };

  const copyAddress = async (address: string) => {
    await navigator.clipboard.writeText(address);
    setCopiedAddress(address);
    setTimeout(() => setCopiedAddress(null), 2000);
  };

  const handleRevoke = async (role: string, account: string) => {
    if (!onRevoke) return;
    const id = `${role}-${account}`;
    setRevokingId(id);
    try {
      await onRevoke(role, account);
    } catch (error) {
      console.error('Revoke failed:', error);
    } finally {
      setRevokingId(null);
    }
  };

  const getRoleBadgeVariant = (roleName: string): "default" | "secondary" | "destructive" | "outline" => {
    switch (roleName.toLowerCase()) {
      case 'admin':
        return 'destructive';
      case 'operator':
        return 'default';
      case 'compliance':
        return 'secondary';
      case 'pauser':
        return 'outline';
      default:
        return 'outline';
    }
  };

  // Group by role
  const groupedByRole = assignments.reduce((acc, assignment) => {
    if (!acc[assignment.roleName]) {
      acc[assignment.roleName] = [];
    }
    acc[assignment.roleName].push(assignment);
    return acc;
  }, {} as Record<string, RoleAssignment[]>);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ShieldCheck className="h-5 w-5" />
          Current Role Assignments
        </CardTitle>
        <CardDescription>
          View all accounts with protocol roles
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="space-y-2">
                <Skeleton className="h-6 w-24" />
                <Skeleton className="h-12 w-full" />
              </div>
            ))}
          </div>
        ) : assignments.length === 0 ? (
          <p className="text-center py-8 text-muted-foreground">
            No role assignments found
          </p>
        ) : (
          <div className="space-y-6">
            {Object.entries(groupedByRole).map(([roleName, roleAssignments]) => (
              <div key={roleName} className="space-y-2">
                <div className="flex items-center gap-2">
                  <Badge variant={getRoleBadgeVariant(roleName)}>
                    {roleName}
                  </Badge>
                  <span className="text-sm text-muted-foreground">
                    ({roleAssignments.length} {roleAssignments.length === 1 ? 'member' : 'members'})
                  </span>
                </div>
                <div className="space-y-2">
                  {roleAssignments.map((assignment) => (
                    <div
                      key={`${assignment.role}-${assignment.account}`}
                      className="flex items-center justify-between p-3 rounded-lg border"
                    >
                      <div className="flex items-center gap-3">
                        <code className="font-mono text-sm">
                          {shortenAddress(assignment.account)}
                        </code>
                        <button
                          onClick={() => copyAddress(assignment.account)}
                          className="p-1 hover:bg-muted rounded"
                        >
                          {copiedAddress === assignment.account ? (
                            <Check className="h-3 w-3 text-green-500" />
                          ) : (
                            <Copy className="h-3 w-3" />
                          )}
                        </button>
                        <a
                          href={getExplorerUrl(assignment.account)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1 hover:bg-muted rounded"
                        >
                          <ExternalLink className="h-3 w-3" />
                        </a>
                      </div>
                      <div className="flex items-center gap-3">
                        {assignment.grantedAt && (
                          <span className="text-xs text-muted-foreground">
                            Granted: {formatDate(assignment.grantedAt)}
                          </span>
                        )}
                        {canRevoke && onRevoke && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleRevoke(assignment.role, assignment.account)}
                            disabled={revokingId === `${assignment.role}-${assignment.account}`}
                          >
                            <UserMinus className="h-4 w-4 text-destructive" />
                          </Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
