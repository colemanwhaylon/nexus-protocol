'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { ScrollText, User, Clock, ExternalLink } from 'lucide-react';

type EventType = 'role_granted' | 'role_revoked' | 'kyc_approved' | 'kyc_rejected' | 'paused' | 'unpaused' | 'emergency' | 'transfer' | 'other';

interface AuditEvent {
  id: string;
  type: EventType;
  actor: string;
  target?: string;
  details?: string;
  timestamp: number;
  txHash?: string;
}

interface AuditLogProps {
  events?: AuditEvent[];
  chainId?: number;
  isLoading?: boolean;
  maxItems?: number;
}

export function AuditLog({
  events = [],
  chainId,
  isLoading,
  maxItems = 10,
}: AuditLogProps) {
  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const formatDate = (timestamp: number) =>
    new Date(timestamp * 1000).toLocaleString();

  const getExplorerUrl = (txHash: string) => {
    switch (chainId) {
      case 1:
        return `https://etherscan.io/tx/${txHash}`;
      case 11155111:
        return `https://sepolia.etherscan.io/tx/${txHash}`;
      default:
        return '#';
    }
  };

  const getEventBadge = (type: EventType) => {
    switch (type) {
      case 'role_granted':
        return <Badge className="bg-green-500">Role Granted</Badge>;
      case 'role_revoked':
        return <Badge variant="destructive">Role Revoked</Badge>;
      case 'kyc_approved':
        return <Badge className="bg-blue-500">KYC Approved</Badge>;
      case 'kyc_rejected':
        return <Badge variant="destructive">KYC Rejected</Badge>;
      case 'paused':
        return <Badge variant="secondary">Paused</Badge>;
      case 'unpaused':
        return <Badge variant="outline">Unpaused</Badge>;
      case 'emergency':
        return <Badge variant="destructive">Emergency</Badge>;
      case 'transfer':
        return <Badge variant="outline">Transfer</Badge>;
      default:
        return <Badge variant="outline">Event</Badge>;
    }
  };

  const getEventDescription = (event: AuditEvent) => {
    switch (event.type) {
      case 'role_granted':
        return `Granted role to ${event.target ? shortenAddress(event.target) : 'unknown'}`;
      case 'role_revoked':
        return `Revoked role from ${event.target ? shortenAddress(event.target) : 'unknown'}`;
      case 'kyc_approved':
        return `Approved KYC for ${event.target ? shortenAddress(event.target) : 'unknown'}`;
      case 'kyc_rejected':
        return `Rejected KYC for ${event.target ? shortenAddress(event.target) : 'unknown'}`;
      case 'paused':
        return 'Protocol paused';
      case 'unpaused':
        return 'Protocol unpaused';
      case 'emergency':
        return 'Emergency mode triggered';
      default:
        return event.details || 'Event occurred';
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ScrollText className="h-5 w-5" />
          Audit Log
        </CardTitle>
        <CardDescription>
          Recent protocol activity and changes
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-3">
            {[...Array(5)].map((_, i) => (
              <Skeleton key={i} className="h-16 w-full" />
            ))}
          </div>
        ) : events.length === 0 ? (
          <p className="text-center py-8 text-muted-foreground">
            No audit events found
          </p>
        ) : (
          <div className="space-y-3">
            {events.slice(0, maxItems).map((event) => (
              <div
                key={event.id}
                className="flex items-start gap-3 p-3 rounded-lg border"
              >
                <div className="flex-1 space-y-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    {getEventBadge(event.type)}
                    <span className="text-sm">{getEventDescription(event)}</span>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-muted-foreground">
                    <span className="flex items-center gap-1">
                      <User className="h-3 w-3" />
                      {shortenAddress(event.actor)}
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock className="h-3 w-3" />
                      {formatDate(event.timestamp)}
                    </span>
                  </div>
                </div>
                {event.txHash && (
                  <a
                    href={getExplorerUrl(event.txHash)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-2 hover:bg-muted rounded"
                  >
                    <ExternalLink className="h-4 w-4" />
                  </a>
                )}
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
