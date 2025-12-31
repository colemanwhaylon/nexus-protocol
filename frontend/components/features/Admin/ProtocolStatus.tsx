'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Activity, Shield, Pause, Play, AlertTriangle } from 'lucide-react';

interface ContractStatus {
  name: string;
  address: string;
  isPaused: boolean;
  version?: string;
}

interface ProtocolStatusProps {
  contracts?: ContractStatus[];
  isEmergencyMode?: boolean;
  lastUpdated?: number;
  isLoading?: boolean;
}

export function ProtocolStatus({
  contracts = [],
  isEmergencyMode = false,
  lastUpdated,
  isLoading,
}: ProtocolStatusProps) {
  const shortenAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`;

  const formatDate = (timestamp: number) =>
    new Date(timestamp * 1000).toLocaleString();

  const pausedCount = contracts.filter(c => c.isPaused).length;
  const allOperational = pausedCount === 0 && !isEmergencyMode;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Activity className="h-5 w-5" />
            Protocol Status
          </div>
          <Badge variant={allOperational ? 'default' : 'destructive'}>
            {isEmergencyMode ? 'Emergency Mode' : allOperational ? 'Operational' : `${pausedCount} Paused`}
          </Badge>
        </CardTitle>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="space-y-3">
            {[...Array(4)].map((_, i) => (
              <Skeleton key={i} className="h-12 w-full" />
            ))}
          </div>
        ) : (
          <div className="space-y-4">
            {isEmergencyMode && (
              <div className="p-3 bg-destructive/10 border border-destructive/20 rounded-lg flex items-center gap-2">
                <AlertTriangle className="h-5 w-5 text-destructive" />
                <div>
                  <p className="font-medium text-destructive">Emergency Mode Active</p>
                  <p className="text-sm text-muted-foreground">
                    Protocol operations are restricted
                  </p>
                </div>
              </div>
            )}

            <div className="space-y-2">
              {contracts.map((contract) => (
                <div
                  key={contract.address}
                  className="flex items-center justify-between p-3 rounded-lg border"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <Shield className="h-4 w-4 text-muted-foreground" />
                      <span className="font-medium">{contract.name}</span>
                      {contract.version && (
                        <Badge variant="outline" className="text-xs">
                          v{contract.version}
                        </Badge>
                      )}
                    </div>
                    <p className="text-xs font-mono text-muted-foreground">
                      {shortenAddress(contract.address)}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    {contract.isPaused ? (
                      <>
                        <Pause className="h-4 w-4 text-yellow-500" />
                        <Badge variant="secondary">Paused</Badge>
                      </>
                    ) : (
                      <>
                        <Play className="h-4 w-4 text-green-500" />
                        <Badge variant="outline">Active</Badge>
                      </>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {lastUpdated && (
              <p className="text-xs text-muted-foreground text-right">
                Last updated: {formatDate(lastUpdated)}
              </p>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
