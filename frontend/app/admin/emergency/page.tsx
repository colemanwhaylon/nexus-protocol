'use client';

import { useEffect, useRef } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { EmergencyControls, ProtocolStatus } from '@/components/features/Admin';
import { useChainId, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { useNotifications } from '@/hooks/useNotifications';
import { AlertTriangle, Shield, Activity } from 'lucide-react';

// NexusEmergency ABI - minimal ABI for pause/unpause/emergency functionality
const nexusEmergencyAbi = [
  {
    name: 'globalPause',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'recoveryMode',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'initiateGlobalPause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'liftGlobalPause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'activateRecoveryMode',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'deactivateRecoveryMode',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const;

// Track last action for notification purposes
type EmergencyAction = 'pause' | 'unpause' | 'emergency' | 'resolve' | null;

export default function EmergencyPage() {
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);
  const { notifyEmergencyPause, notifyEmergencyUnpause, notifyError } = useNotifications();

  // Track the last action for proper notifications
  const lastActionRef = useRef<EmergencyAction>(null);

  // Read global pause status from contract
  const { data: isPausedData, refetch: refetchPaused } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'globalPause',
  });

  // Read recovery mode status from contract
  const { data: isEmergencyModeData, refetch: refetchRecoveryMode } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'recoveryMode',
  });

  // Coerce to booleans for consistent handling
  const isPaused = !!isPausedData;
  const isEmergencyMode = !!isEmergencyModeData;

  // Write contract hook for all emergency operations
  const {
    writeContract,
    data: txHash,
    isPending,
    error: writeError,
    reset
  } = useWriteContract();

  // Wait for transaction receipt
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  // Refetch data and show notification after successful transaction
  useEffect(() => {
    if (isSuccess && txHash) {
      refetchPaused();
      refetchRecoveryMode();

      // Show appropriate notification based on the action
      if (lastActionRef.current === 'pause' || lastActionRef.current === 'emergency') {
        const label = lastActionRef.current === 'pause' ? 'Protocol' : 'Recovery Mode';
        notifyEmergencyPause(label, txHash);
      } else if (lastActionRef.current === 'unpause' || lastActionRef.current === 'resolve') {
        const label = lastActionRef.current === 'unpause' ? 'Protocol' : 'Recovery Mode';
        notifyEmergencyUnpause(label, txHash);
      }

      lastActionRef.current = null;
      reset();
    }
  }, [isSuccess, txHash, refetchPaused, refetchRecoveryMode, notifyEmergencyPause, notifyEmergencyUnpause, reset]);

  // Handle write errors
  useEffect(() => {
    if (writeError) {
      notifyError('Transaction Failed', writeError.message || 'An error occurred');
      lastActionRef.current = null;
      reset();
    }
  }, [writeError, notifyError, reset]);

  const isLoading = isPending || isConfirming;

  // Contract status data
  const contracts = [
    {
      name: 'NexusToken',
      address: addresses.nexusToken || '0x...',
      isPaused: isPaused,
      version: '1.0.0'
    },
    {
      name: 'NexusNFT',
      address: addresses.nexusNFT || '0x...',
      isPaused: isPaused,
      version: '1.0.0'
    },
    {
      name: 'NexusStaking',
      address: addresses.nexusStaking || '0x...',
      isPaused: isPaused,
      version: '1.0.0'
    },
    {
      name: 'NexusEmergency',
      address: addresses.nexusEmergency || '0x...',
      isPaused: isPaused,
      version: '1.0.0'
    },
  ];

  const handlePause = async () => {
    lastActionRef.current = 'pause';
    writeContract({
      address: addresses.nexusEmergency,
      abi: nexusEmergencyAbi,
      functionName: 'initiateGlobalPause',
    });
  };

  const handleUnpause = async () => {
    lastActionRef.current = 'unpause';
    writeContract({
      address: addresses.nexusEmergency,
      abi: nexusEmergencyAbi,
      functionName: 'liftGlobalPause',
    });
  };

  const handleTriggerEmergency = async () => {
    lastActionRef.current = 'emergency';
    writeContract({
      address: addresses.nexusEmergency,
      abi: nexusEmergencyAbi,
      functionName: 'activateRecoveryMode',
    });
  };

  const handleResolveEmergency = async () => {
    lastActionRef.current = 'resolve';
    writeContract({
      address: addresses.nexusEmergency,
      abi: nexusEmergencyAbi,
      functionName: 'deactivateRecoveryMode',
    });
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Emergency Controls</h1>
        <p className="text-muted-foreground">
          Protocol pause and circuit breaker management
        </p>
      </div>

      {/* Status Overview */}
      <div className="grid gap-4 md:grid-cols-3 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Activity className="h-4 w-4" />
              Protocol Status
            </CardTitle>
          </CardHeader>
          <CardContent className="flex items-center justify-between">
            <p className="text-lg font-semibold">
              {isEmergencyMode ? 'Emergency' : isPaused ? 'Paused' : 'Active'}
            </p>
            <Badge variant={isEmergencyMode ? 'destructive' : isPaused ? 'secondary' : 'default'}>
              {isEmergencyMode ? 'Emergency' : isPaused ? 'Paused' : 'Operational'}
            </Badge>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Shield className="h-4 w-4" />
              Circuit Breaker
            </CardTitle>
          </CardHeader>
          <CardContent className="flex items-center justify-between">
            <p className="text-lg font-semibold">Normal</p>
            <Badge variant="outline">Active</Badge>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <AlertTriangle className="h-4 w-4" />
              Threat Level
            </CardTitle>
          </CardHeader>
          <CardContent className="flex items-center justify-between">
            <p className="text-lg font-semibold">Low</p>
            <Badge variant="outline" className="bg-green-500/10 text-green-600">Safe</Badge>
          </CardContent>
        </Card>
      </div>

      {/* Main Controls */}
      <div className="grid gap-6 lg:grid-cols-2">
        <EmergencyControls
          isPaused={isPaused}
          isEmergencyMode={isEmergencyMode}
          canPause={true}
          canTriggerEmergency={true}
          onPause={handlePause}
          onUnpause={handleUnpause}
          onTriggerEmergency={handleTriggerEmergency}
          onResolveEmergency={handleResolveEmergency}
          isLoading={isLoading}
        />

        <ProtocolStatus
          contracts={contracts}
          isEmergencyMode={isEmergencyMode}
          lastUpdated={Math.floor(Date.now() / 1000)}
          isLoading={false}
        />
      </div>
    </div>
  );
}
