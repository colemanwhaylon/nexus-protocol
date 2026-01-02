'use client';

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { KYCTable } from '@/components/features/Admin';
import { useAdminKYC } from '@/hooks/useAdminKYC';
import { Users, CheckCircle, XCircle, Clock, RefreshCw, AlertCircle } from 'lucide-react';

export default function CompliancePage() {
  const {
    formattedRequests,
    stats,
    approveKYC,
    rejectKYC,
    refresh,
    isLoading,
    isProcessing,
    error,
    clearError,
  } = useAdminKYC({
    autoRefresh: true,
    refreshInterval: 30000, // Refresh every 30 seconds
  });

  const handleView = (id: string) => {
    // Find the request by id (which is the address)
    const request = formattedRequests.find(r => r.id === id);
    if (request) {
      // Open a modal or navigate to details page
      console.log('View KYC request', request);
      // TODO: Implement modal with full KYC details
    }
  };

  const handleApprove = async (id: string) => {
    // The id is the address in our case
    await approveKYC(id);
  };

  const handleReject = async (id: string) => {
    // The id is the address in our case
    await rejectKYC(id, 'Verification requirements not met');
  };

  const handleRefresh = () => {
    refresh();
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">KYC Compliance</h1>
          <p className="text-muted-foreground">
            Manage KYC requests and whitelist status
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={handleRefresh}
          disabled={isLoading}
        >
          <RefreshCw className={`h-4 w-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Error Alert */}
      {error && (
        <div className="mb-6 p-4 bg-destructive/10 border border-destructive rounded-lg flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertCircle className="h-5 w-5 text-destructive" />
            <span className="text-destructive">{error}</span>
          </div>
          <Button variant="ghost" size="sm" onClick={clearError}>
            Dismiss
          </Button>
        </div>
      )}

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
            <p className="text-2xl font-bold">
              {isLoading ? '-' : stats.total}
            </p>
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
            <p className="text-2xl font-bold">
              {isLoading ? '-' : stats.pending}
            </p>
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
            <p className="text-2xl font-bold">
              {isLoading ? '-' : stats.approved}
            </p>
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
            <p className="text-2xl font-bold">
              {isLoading ? '-' : stats.rejected}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* KYC Table */}
      <KYCTable
        requests={formattedRequests}
        onView={handleView}
        onApprove={handleApprove}
        onReject={handleReject}
        isLoading={isLoading || isProcessing}
      />

      {/* Empty State */}
      {!isLoading && formattedRequests.length === 0 && !error && (
        <div className="text-center py-12">
          <Users className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
          <h3 className="text-lg font-medium mb-2">No KYC Requests</h3>
          <p className="text-muted-foreground mb-4">
            There are currently no pending KYC verification requests.
          </p>
          <Button variant="outline" onClick={handleRefresh}>
            <RefreshCw className="h-4 w-4 mr-2" />
            Check Again
          </Button>
        </div>
      )}
    </div>
  );
}
