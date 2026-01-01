'use client';

import { useChainId } from 'wagmi';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { getContractAddresses } from '@/lib/contracts/addresses';
import { ProtocolStatus, AuditLog } from '@/components/features/Admin';

export default function AdminDashboard() {
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);

  // Contract status data
  const contracts = [
    { 
      name: 'NexusToken', 
      address: addresses.nexusToken || '0x...', 
      isPaused: false,
      version: '1.0.0'
    },
    { 
      name: 'NexusNFT', 
      address: addresses.nexusNFT || '0x...', 
      isPaused: false,
      version: '1.0.0'
    },
    { 
      name: 'NexusStaking', 
      address: addresses.nexusStaking || '0x...', 
      isPaused: false,
      version: '1.0.0'
    },
    { 
      name: 'RewardsDistributor', 
      address: addresses.rewardsDistributor || '0x...', 
      isPaused: false,
      version: '1.0.0'
    },
  ];

  // Mock audit events for demo
  const auditEvents = [
    {
      id: '1',
      type: 'role_granted' as const,
      actor: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      target: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      timestamp: Math.floor(Date.now() / 1000) - 3600,
      txHash: '0x1234567890abcdef...',
    },
    {
      id: '2',
      type: 'kyc_approved' as const,
      actor: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      target: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      timestamp: Math.floor(Date.now() / 1000) - 7200,
      txHash: '0xabcdef1234567890...',
    },
    {
      id: '3',
      type: 'paused' as const,
      actor: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      details: 'Scheduled maintenance',
      timestamp: Math.floor(Date.now() / 1000) - 86400,
    },
    {
      id: '4',
      type: 'unpaused' as const,
      actor: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      details: 'Maintenance completed',
      timestamp: Math.floor(Date.now() / 1000) - 82800,
    },
  ];

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Admin Dashboard</h1>
        <p className="text-muted-foreground">
          Protocol administration and compliance management
        </p>
      </div>

      {/* Quick Stats */}
      <div className="grid gap-6 md:grid-cols-3 mb-8">
        <Card>
          <CardHeader>
            <CardTitle>Pending KYC</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">0</p>
            <p className="text-muted-foreground">Requests awaiting review</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Active Roles</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">4</p>
            <p className="text-muted-foreground">Role assignments</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Total Users</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">127</p>
            <p className="text-muted-foreground">Verified users</p>
          </CardContent>
        </Card>
      </div>

      {/* Protocol Status and Audit Log */}
      <div className="grid gap-6 lg:grid-cols-2">
        <ProtocolStatus
          contracts={contracts}
          isEmergencyMode={false}
          lastUpdated={Math.floor(Date.now() / 1000)}
          isLoading={false}
        />

        <AuditLog
          events={auditEvents}
          chainId={chainId}
          isLoading={false}
          maxItems={5}
        />
      </div>
    </div>
  );
}
