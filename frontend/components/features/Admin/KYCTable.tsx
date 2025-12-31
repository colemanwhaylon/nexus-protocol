'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Input } from '@/components/ui/input';
import { Users, Search, Eye, CheckCircle, XCircle } from 'lucide-react';
import { useState } from 'react';

type KYCStatus = 'pending' | 'approved' | 'rejected';

interface KYCRequest {
  id: string;
  address: string;
  submittedAt: number;
  status: KYCStatus;
  riskLevel?: 'low' | 'medium' | 'high';
}

interface KYCTableProps {
  requests?: KYCRequest[];
  onView?: (id: string) => void;
  onApprove?: (id: string) => void;
  onReject?: (id: string) => void;
  isLoading?: boolean;
}

export function KYCTable({
  requests = [],
  onView,
  onApprove,
  onReject,
  isLoading,
}: KYCTableProps) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<KYCStatus | 'all'>('all');

  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const formatDate = (timestamp: number) =>
    new Date(timestamp * 1000).toLocaleDateString();

  const getStatusBadge = (status: KYCStatus) => {
    switch (status) {
      case 'approved':
        return <Badge className="bg-green-500">Approved</Badge>;
      case 'rejected':
        return <Badge variant="destructive">Rejected</Badge>;
      default:
        return <Badge variant="secondary">Pending</Badge>;
    }
  };

  const getRiskBadge = (risk?: string) => {
    switch (risk) {
      case 'high':
        return <Badge variant="destructive">High Risk</Badge>;
      case 'medium':
        return <Badge variant="secondary">Medium Risk</Badge>;
      case 'low':
        return <Badge variant="outline">Low Risk</Badge>;
      default:
        return null;
    }
  };

  const filteredRequests = requests.filter((req) => {
    const matchesSearch = req.address.toLowerCase().includes(search.toLowerCase()) ||
      req.id.toLowerCase().includes(search.toLowerCase());
    const matchesFilter = filter === 'all' || req.status === filter;
    return matchesSearch && matchesFilter;
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Users className="h-5 w-5" />
          KYC Requests
        </CardTitle>
        <CardDescription>
          Manage user verification requests
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex gap-2">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search by address or ID..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-9"
            />
          </div>
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value as KYCStatus | 'all')}
            className="px-3 border rounded-md bg-background"
          >
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>

        {isLoading ? (
          <div className="space-y-2">
            {[...Array(5)].map((_, i) => (
              <Skeleton key={i} className="h-16 w-full" />
            ))}
          </div>
        ) : filteredRequests.length === 0 ? (
          <p className="text-center py-8 text-muted-foreground">
            No KYC requests found
          </p>
        ) : (
          <div className="space-y-2">
            {filteredRequests.map((request) => (
              <div
                key={request.id}
                className="flex items-center justify-between p-3 rounded-lg border"
              >
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <code className="font-mono text-sm">
                      {shortenAddress(request.address)}
                    </code>
                    {getStatusBadge(request.status)}
                    {getRiskBadge(request.riskLevel)}
                  </div>
                  <p className="text-xs text-muted-foreground">
                    Submitted: {formatDate(request.submittedAt)}
                  </p>
                </div>
                <div className="flex gap-1">
                  {onView && (
                    <Button variant="ghost" size="sm" onClick={() => onView(request.id)}>
                      <Eye className="h-4 w-4" />
                    </Button>
                  )}
                  {request.status === 'pending' && (
                    <>
                      {onApprove && (
                        <Button variant="ghost" size="sm" onClick={() => onApprove(request.id)}>
                          <CheckCircle className="h-4 w-4 text-green-500" />
                        </Button>
                      )}
                      {onReject && (
                        <Button variant="ghost" size="sm" onClick={() => onReject(request.id)}>
                          <XCircle className="h-4 w-4 text-destructive" />
                        </Button>
                      )}
                    </>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
