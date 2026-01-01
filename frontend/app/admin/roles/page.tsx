'use client';

import { useState } from 'react';
import { useChainId } from 'wagmi';
import { RoleManager, RoleTable } from '@/components/features/Admin';
import type { Address } from 'viem';

export default function RolesPage() {
  const chainId = useChainId();
  const [isLoading, setIsLoading] = useState(false);

  // Define available roles
  const roles = [
    { id: 'DEFAULT_ADMIN_ROLE', name: 'Admin', description: 'Full administrative access' },
    { id: 'OPERATOR_ROLE', name: 'Operator', description: 'Operational management' },
    { id: 'COMPLIANCE_ROLE', name: 'Compliance', description: 'KYC and compliance management' },
    { id: 'PAUSER_ROLE', name: 'Pauser', description: 'Emergency pause capability' },
  ];

  // Mock role assignments for demo
  const [roleAssignments, setRoleAssignments] = useState([
    {
      role: 'DEFAULT_ADMIN_ROLE',
      roleName: 'Admin',
      account: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      grantedAt: Math.floor(Date.now() / 1000) - 604800,
      grantedBy: '0x0000000000000000000000000000000000000000',
    },
    {
      role: 'OPERATOR_ROLE',
      roleName: 'Operator',
      account: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      grantedAt: Math.floor(Date.now() / 1000) - 259200,
      grantedBy: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    },
    {
      role: 'COMPLIANCE_ROLE',
      roleName: 'Compliance',
      account: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      grantedAt: Math.floor(Date.now() / 1000) - 172800,
      grantedBy: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    },
    {
      role: 'PAUSER_ROLE',
      roleName: 'Pauser',
      account: '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
      grantedAt: Math.floor(Date.now() / 1000) - 86400,
      grantedBy: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    },
    {
      role: 'PAUSER_ROLE',
      roleName: 'Pauser',
      account: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      grantedAt: Math.floor(Date.now() / 1000) - 604800,
      grantedBy: '0x0000000000000000000000000000000000000000',
    },
  ]);

  const handleGrantRole = async (role: string, account: Address) => {
    setIsLoading(true);
    try {
      // TODO: Call smart contract to grant role
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const roleName = roles.find(r => r.id === role)?.name || role;
      setRoleAssignments(prev => [
        ...prev,
        {
          role,
          roleName,
          account,
          grantedAt: Math.floor(Date.now() / 1000),
          grantedBy: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        },
      ]);
      console.log('Role granted', role, 'to', account);
    } finally {
      setIsLoading(false);
    }
  };

  const handleRevokeRole = async (role: string, account: string) => {
    setIsLoading(true);
    try {
      // TODO: Call smart contract to revoke role
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setRoleAssignments(prev => 
        prev.filter(a => !(a.role === role && a.account === account))
      );
      console.log('Role revoked', role, 'from', account);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Role Management</h1>
        <p className="text-muted-foreground">
          Manage protocol roles and permissions
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Role Manager - Grant/Revoke */}
        <RoleManager
          roles={roles}
          onGrantRole={handleGrantRole}
          onRevokeRole={handleRevokeRole}
          isLoading={isLoading}
          disabled={false}
        />

        {/* Current Assignments */}
        <RoleTable
          assignments={roleAssignments}
          chainId={chainId}
          onRevoke={handleRevokeRole}
          isLoading={isLoading}
          canRevoke={true}
        />
      </div>
    </div>
  );
}
