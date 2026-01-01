'use client';

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { KYCTable } from '@/components/features/Admin';
import { Users, CheckCircle, XCircle, Clock } from 'lucide-react';

export default function CompliancePage() {
  const isLoading = false;

  // Mock KYC requests for demo
  const kycRequests = [
    {
      id: '1',
      address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      submittedAt: Math.floor(Date.now() / 1000) - 3600,
      status: 'pending' as const,
      riskLevel: 'low' as const,
    },
    {
      id: '2',
      address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      submittedAt: Math.floor(Date.now() / 1000) - 7200,
      status: 'approved' as const,
      riskLevel: 'low' as const,
    },
    {
      id: '3',
      address: '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
      submittedAt: Math.floor(Date.now() / 1000) - 14400,
      status: 'pending' as const,
      riskLevel: 'medium' as const,
    },
    {
      id: '4',
      address: '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65',
      submittedAt: Math.floor(Date.now() / 1000) - 86400,
      status: 'rejected' as const,
      riskLevel: 'high' as const,
    },
    {
      id: '5',
      address: '0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc',
      submittedAt: Math.floor(Date.now() / 1000) - 172800,
      status: 'approved' as const,
      riskLevel: 'low' as const,
    },
  ];

  const handleView = (id: string) => {
    console.log('View KYC request', id);
    // TODO: Open modal with full KYC details
  };

  const handleApprove = async (id: string) => {
    console.log('Approve KYC request', id);
    // TODO: Call smart contract to approve KYC
  };

  const handleReject = async (id: string) => {
    console.log('Reject KYC request', id);
    // TODO: Call smart contract to reject KYC
  };

  // Calculate stats
  const pendingCount = kycRequests.filter(r => r.status === 'pending').length;
  const approvedCount = kycRequests.filter(r => r.status === 'approved').length;
  const rejectedCount = kycRequests.filter(r => r.status === 'rejected').length;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">KYC Compliance</h1>
        <p className="text-muted-foreground">
          Manage KYC requests and whitelist status
        </p>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Users className="h-4 w-4" />
              Total Requests
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{kycRequests.length}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Clock className="h-4 w-4 text-yellow-500" />
              Pending
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{pendingCount}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              Approved
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{approvedCount}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <XCircle className="h-4 w-4 text-destructive" />
              Rejected
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{rejectedCount}</p>
          </CardContent>
        </Card>
      </div>

      {/* KYC Table */}
      <KYCTable
        requests={kycRequests}
        onView={handleView}
        onApprove={handleApprove}
        onReject={handleReject}
        isLoading={isLoading}
      />
    </div>
  );
}
