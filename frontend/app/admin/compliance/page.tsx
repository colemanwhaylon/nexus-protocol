'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { KYCTable } from '@/components/features/Admin';
import { useAdminKYC, type FormattedKYCRequest } from '@/hooks/useAdminKYC';
import {
  Users,
  CheckCircle,
  XCircle,
  Clock,
  RefreshCw,
  AlertCircle,
  Shield,
  Ban,
  UserCheck,
  Search,
  Plus,
} from 'lucide-react';
import { isAddress } from 'viem';

export default function CompliancePage() {
  const {
    formattedRequests,
    blacklistedAddresses,
    stats,
    approveKYC,
    rejectKYC,
    addToWhitelist,
    addToBlacklist,
    removeFromBlacklist,
    checkAddress,
    refresh,
    isLoading,
    isProcessing,
    error,
    clearError,
    isReady,
  } = useAdminKYC({
    autoRefresh: true,
    refreshInterval: 30000,
  });

  // Local state for address lookup
  const [lookupAddress, setLookupAddress] = useState('');
  const [lookupResult, setLookupResult] = useState<FormattedKYCRequest | null>(null);
  const [isLookingUp, setIsLookingUp] = useState(false);
  const [lookupError, setLookupError] = useState<string | null>(null);

  // New address actions
  const [newAddress, setNewAddress] = useState('');
  const [actionType, setActionType] = useState<'whitelist' | 'blacklist'>('whitelist');
  const [blacklistReason, setBlacklistReason] = useState('');

  const handleView = (id: string) => {
    const request = formattedRequests.find(r => r.id === id);
    if (request) {
      console.log('View KYC request', request);
      // TODO: Implement modal with full KYC details
    }
  };

  const handleApprove = async (id: string) => {
    await approveKYC(id);
  };

  const handleReject = async (id: string) => {
    await rejectKYC(id, 'Verification requirements not met');
  };

  const handleRefresh = () => {
    refresh();
  };

  const handleLookup = async () => {
    if (!lookupAddress) return;

    if (!isAddress(lookupAddress)) {
      setLookupError('Invalid Ethereum address');
      return;
    }

    setIsLookingUp(true);
    setLookupError(null);
    setLookupResult(null);

    try {
      const result = await checkAddress(lookupAddress);
      if (result) {
        setLookupResult(result);
      } else {
        setLookupError('No KYC data found for this address');
      }
    } catch {
      setLookupError('Failed to lookup address');
    } finally {
      setIsLookingUp(false);
    }
  };

  const handleAddAddress = async () => {
    if (!newAddress || !isAddress(newAddress)) {
      return;
    }

    if (actionType === 'whitelist') {
      await addToWhitelist(newAddress);
    } else {
      await addToBlacklist(newAddress, blacklistReason || 'Compliance violation');
    }

    setNewAddress('');
    setBlacklistReason('');
  };

  const handleRemoveFromBlacklist = async (address: string) => {
    await removeFromBlacklist(address);
  };

  // Convert formatted requests to KYCTable format
  const tableRequests = formattedRequests.map(r => ({
    id: r.id,
    address: r.address,
    submittedAt: r.submittedAt,
    status: r.status === 'blacklisted' ? 'rejected' as const : r.status === 'approved' ? 'approved' as const : 'pending' as const,
    riskLevel: undefined,
    level: r.level,
    levelName: r.levelName,
  }));

  // Contract not deployed warning
  if (!isReady) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold">KYC Compliance</h1>
          <p className="text-muted-foreground">
            Manage KYC requests and whitelist status
          </p>
        </div>

        <Card className="border-yellow-500">
          <CardContent className="pt-6">
            <div className="flex items-center gap-4">
              <AlertCircle className="h-8 w-8 text-yellow-500" />
              <div>
                <h3 className="font-semibold">Contract Not Deployed</h3>
                <p className="text-muted-foreground">
                  The NexusKYCRegistry contract is not deployed on this network.
                  Please deploy the contract or switch to a network where it is available.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">KYC Compliance</h1>
          <p className="text-muted-foreground">
            Manage KYC requests and whitelist status (on-chain)
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
      <div className="grid gap-4 md:grid-cols-5 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Users className="h-4 w-4" />
              Total Users
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">
              {isLoading ? <Skeleton className="h-8 w-16" /> : stats.total}
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
              {isLoading ? <Skeleton className="h-8 w-16" /> : stats.pending}
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
              {isLoading ? <Skeleton className="h-8 w-16" /> : stats.approved}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <UserCheck className="h-4 w-4 text-blue-500" />
              Whitelisted
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">
              {isLoading ? <Skeleton className="h-8 w-16" /> : stats.whitelisted}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Ban className="h-4 w-4 text-destructive" />
              Blacklisted
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">
              {isLoading ? <Skeleton className="h-8 w-16" /> : stats.blacklisted}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="grid gap-6 lg:grid-cols-2 mb-8">
        {/* Address Lookup */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Search className="h-5 w-5" />
              Address Lookup
            </CardTitle>
            <CardDescription>
              Check KYC status for any address
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex gap-2">
              <Input
                placeholder="0x..."
                value={lookupAddress}
                onChange={(e) => setLookupAddress(e.target.value)}
                className="font-mono"
              />
              <Button onClick={handleLookup} disabled={isLookingUp || !lookupAddress}>
                {isLookingUp ? 'Checking...' : 'Lookup'}
              </Button>
            </div>

            {lookupError && (
              <p className="text-sm text-destructive">{lookupError}</p>
            )}

            {lookupResult && (
              <div className="p-3 rounded-lg border space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Status</span>
                  {lookupResult.status === 'approved' && (
                    <Badge className="bg-green-500">Approved</Badge>
                  )}
                  {lookupResult.status === 'pending' && (
                    <Badge variant="secondary">Pending</Badge>
                  )}
                  {lookupResult.status === 'rejected' && (
                    <Badge variant="destructive">Rejected</Badge>
                  )}
                  {lookupResult.status === 'blacklisted' && (
                    <Badge variant="destructive">Blacklisted</Badge>
                  )}
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">KYC Level</span>
                  <span className="text-sm font-medium">{lookupResult.levelName}</span>
                </div>
                {lookupResult.expiresAt && (
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-muted-foreground">Expires</span>
                    <span className="text-sm">
                      {new Date(lookupResult.expiresAt * 1000).toLocaleDateString()}
                    </span>
                  </div>
                )}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Add Address */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Plus className="h-5 w-5" />
              Add Address
            </CardTitle>
            <CardDescription>
              Manually add an address to whitelist or blacklist
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Input
              placeholder="0x..."
              value={newAddress}
              onChange={(e) => setNewAddress(e.target.value)}
              className="font-mono"
            />

            <div className="flex gap-2">
              <Button
                variant={actionType === 'whitelist' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setActionType('whitelist')}
                className="flex-1"
              >
                <UserCheck className="h-4 w-4 mr-2" />
                Whitelist
              </Button>
              <Button
                variant={actionType === 'blacklist' ? 'destructive' : 'outline'}
                size="sm"
                onClick={() => setActionType('blacklist')}
                className="flex-1"
              >
                <Ban className="h-4 w-4 mr-2" />
                Blacklist
              </Button>
            </div>

            {actionType === 'blacklist' && (
              <Input
                placeholder="Reason for blacklisting..."
                value={blacklistReason}
                onChange={(e) => setBlacklistReason(e.target.value)}
              />
            )}

            <Button
              onClick={handleAddAddress}
              disabled={isProcessing || !newAddress || !isAddress(newAddress)}
              className="w-full"
              variant={actionType === 'blacklist' ? 'destructive' : 'default'}
            >
              {isProcessing ? 'Processing...' : `Add to ${actionType === 'whitelist' ? 'Whitelist' : 'Blacklist'}`}
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* KYC Table */}
      <KYCTable
        requests={tableRequests}
        onView={handleView}
        onApprove={handleApprove}
        onReject={handleReject}
        isLoading={isLoading || isProcessing}
      />

      {/* Blacklisted Addresses Section */}
      {blacklistedAddresses.length > 0 && (
        <Card className="mt-8">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5 text-destructive" />
              Blacklisted Addresses
            </CardTitle>
            <CardDescription>
              Addresses that are blocked from the protocol
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {blacklistedAddresses.map((address) => (
                <div
                  key={address}
                  className="flex items-center justify-between p-3 rounded-lg border border-destructive/20 bg-destructive/5"
                >
                  <div className="flex items-center gap-2">
                    <Ban className="h-4 w-4 text-destructive" />
                    <code className="font-mono text-sm">
                      {`${address.slice(0, 6)}...${address.slice(-4)}`}
                    </code>
                    <Badge variant="destructive" className="text-xs">Blacklisted</Badge>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleRemoveFromBlacklist(address)}
                    disabled={isProcessing}
                  >
                    <XCircle className="h-4 w-4 mr-1" />
                    Remove
                  </Button>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Empty State */}
      {!isLoading && formattedRequests.length === 0 && !error && (
        <div className="text-center py-12">
          <Users className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
          <h3 className="text-lg font-medium mb-2">No KYC Records</h3>
          <p className="text-muted-foreground mb-4">
            There are currently no KYC records on-chain. Use the form above to add addresses.
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
