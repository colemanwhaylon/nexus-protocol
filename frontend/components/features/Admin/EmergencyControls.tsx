'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Loader2, AlertTriangle, ShieldOff, Shield, Pause, Play } from 'lucide-react';
import { useState } from 'react';

interface EmergencyControlsProps {
  isPaused?: boolean;
  isEmergencyMode?: boolean;
  canPause?: boolean;
  canTriggerEmergency?: boolean;
  onPause?: () => Promise<void>;
  onUnpause?: () => Promise<void>;
  onTriggerEmergency?: () => Promise<void>;
  onResolveEmergency?: () => Promise<void>;
  isLoading?: boolean;
}

export function EmergencyControls({
  isPaused = false,
  isEmergencyMode = false,
  canPause = false,
  canTriggerEmergency = false,
  onPause,
  onUnpause,
  onTriggerEmergency,
  onResolveEmergency,
  isLoading,
}: EmergencyControlsProps) {
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [confirmAction, setConfirmAction] = useState<string | null>(null);

  const handleAction = async (action: string, fn?: () => Promise<void>) => {
    if (!fn) return;
    
    if (!confirmAction) {
      setConfirmAction(action);
      return;
    }

    setConfirmAction(null);
    setActionLoading(action);
    try {
      await fn();
    } catch (error) {
      console.error(`${action} failed:`, error);
    } finally {
      setActionLoading(null);
    }
  };

  const cancelConfirm = () => setConfirmAction(null);

  return (
    <Card className={isEmergencyMode ? 'border-destructive' : ''}>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <AlertTriangle className={isEmergencyMode ? 'h-5 w-5 text-destructive' : 'h-5 w-5'} />
          Emergency Controls
        </CardTitle>
        <CardDescription>
          Critical protocol safety controls
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {isEmergencyMode && (
          <Alert variant="destructive">
            <ShieldOff className="h-4 w-4" />
            <AlertTitle>Emergency Mode Active</AlertTitle>
            <AlertDescription>
              The protocol is in emergency mode. Most operations are disabled.
            </AlertDescription>
          </Alert>
        )}

        {confirmAction && (
          <Alert>
            <AlertTriangle className="h-4 w-4" />
            <AlertTitle>Confirm Action</AlertTitle>
            <AlertDescription className="space-y-2">
              <p>Are you sure you want to {confirmAction}? This action affects the entire protocol.</p>
              <div className="flex gap-2">
                <Button size="sm" variant="destructive" onClick={() => handleAction(confirmAction, 
                  confirmAction === 'pause' ? onPause :
                  confirmAction === 'unpause' ? onUnpause :
                  confirmAction === 'emergency' ? onTriggerEmergency :
                  onResolveEmergency
                )}>
                  Confirm
                </Button>
                <Button size="sm" variant="outline" onClick={cancelConfirm}>
                  Cancel
                </Button>
              </div>
            </AlertDescription>
          </Alert>
        )}

        <div className="grid gap-3 sm:grid-cols-2">
          {/* Pause/Unpause */}
          {canPause && (
            <Button
              variant={isPaused ? 'default' : 'secondary'}
              className="w-full"
              disabled={isLoading || actionLoading !== null || isEmergencyMode}
              onClick={() => handleAction(isPaused ? 'unpause' : 'pause', isPaused ? onUnpause : onPause)}
            >
              {actionLoading === 'pause' || actionLoading === 'unpause' ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : isPaused ? (
                <Play className="mr-2 h-4 w-4" />
              ) : (
                <Pause className="mr-2 h-4 w-4" />
              )}
              {isPaused ? 'Unpause Protocol' : 'Pause Protocol'}
            </Button>
          )}

          {/* Emergency Mode */}
          {canTriggerEmergency && (
            <Button
              variant={isEmergencyMode ? 'default' : 'destructive'}
              className="w-full"
              disabled={isLoading || actionLoading !== null}
              onClick={() => handleAction(
                isEmergencyMode ? 'resolve' : 'emergency',
                isEmergencyMode ? onResolveEmergency : onTriggerEmergency
              )}
            >
              {actionLoading === 'emergency' || actionLoading === 'resolve' ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : isEmergencyMode ? (
                <Shield className="mr-2 h-4 w-4" />
              ) : (
                <ShieldOff className="mr-2 h-4 w-4" />
              )}
              {isEmergencyMode ? 'Resolve Emergency' : 'Trigger Emergency'}
            </Button>
          )}
        </div>

        <p className="text-xs text-muted-foreground">
          Only authorized ADMIN or EMERGENCY_ROLE holders can use these controls.
        </p>
      </CardContent>
    </Card>
  );
}
