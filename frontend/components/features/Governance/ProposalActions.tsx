'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Loader2, Clock, Play, XCircle, AlertTriangle } from 'lucide-react';
import { useState } from 'react';

type ProposalState = 'Pending' | 'Active' | 'Canceled' | 'Defeated' | 'Succeeded' | 'Queued' | 'Expired' | 'Executed';

interface ProposalActionsProps {
  state: ProposalState;
  proposer: string;
  currentUser?: string;
  eta?: number;
  isAdmin?: boolean;
  onQueue?: () => Promise<void>;
  onExecute?: () => Promise<void>;
  onCancel?: () => Promise<void>;
  isLoading?: boolean;
}

export function ProposalActions({
  state,
  proposer,
  currentUser,
  eta,
  isAdmin,
  onQueue,
  onExecute,
  onCancel,
  isLoading,
}: ProposalActionsProps) {
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const isProposer = currentUser?.toLowerCase() === proposer.toLowerCase();
  const canQueue = state === 'Succeeded' && onQueue;
  const canExecute = state === 'Queued' && eta && Date.now() / 1000 >= eta && onExecute;
  const canCancel = ['Pending', 'Active', 'Succeeded', 'Queued'].includes(state) && 
    (isProposer || isAdmin) && onCancel;

  const timeUntilExecution = eta ? Math.max(0, eta - Date.now() / 1000) : 0;
  const formattedTime = () => {
    const hours = Math.floor(timeUntilExecution / 3600);
    const minutes = Math.floor((timeUntilExecution % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const handleAction = async (action: string, fn?: () => Promise<void>) => {
    if (!fn) return;
    setActionLoading(action);
    try {
      await fn();
    } catch (error) {
      console.error(`${action} failed:`, error);
    } finally {
      setActionLoading(null);
    }
  };

  if (!canQueue && !canExecute && !canCancel) {
    return null;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Actions</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {state === 'Queued' && timeUntilExecution > 0 && (
          <Alert>
            <Clock className="h-4 w-4" />
            <AlertDescription>
              Execution available in {formattedTime()}
            </AlertDescription>
          </Alert>
        )}

        <div className="flex flex-col gap-2">
          {canQueue && (
            <Button
              onClick={() => handleAction('queue', onQueue)}
              disabled={isLoading || actionLoading !== null}
            >
              {actionLoading === 'queue' ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Queueing...
                </>
              ) : (
                <>
                  <Clock className="mr-2 h-4 w-4" />
                  Queue for Execution
                </>
              )}
            </Button>
          )}

          {canExecute && (
            <Button
              onClick={() => handleAction('execute', onExecute)}
              disabled={isLoading || actionLoading !== null}
            >
              {actionLoading === 'execute' ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Executing...
                </>
              ) : (
                <>
                  <Play className="mr-2 h-4 w-4" />
                  Execute Proposal
                </>
              )}
            </Button>
          )}

          {canCancel && (
            <Button
              variant="destructive"
              onClick={() => handleAction('cancel', onCancel)}
              disabled={isLoading || actionLoading !== null}
            >
              {actionLoading === 'cancel' ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Canceling...
                </>
              ) : (
                <>
                  <XCircle className="mr-2 h-4 w-4" />
                  Cancel Proposal
                </>
              )}
            </Button>
          )}
        </div>

        {canCancel && (
          <p className="text-xs text-muted-foreground flex items-center gap-1">
            <AlertTriangle className="h-3 w-3" />
            Canceling a proposal cannot be undone
          </p>
        )}
      </CardContent>
    </Card>
  );
}
