'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { EmergencyControls, ProtocolStatus } from '@/components/features/Admin';
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  usePublicClient
} from 'wagmi';
import { type Address, parseAbiItem } from 'viem';
import { useContractAddresses } from '@/hooks/useContractAddresses';
import { useNotifications } from '@/hooks/useNotifications';
import { useAdmin } from '@/hooks/useAdmin';
import { AlertTriangle, Shield, Activity, Clock, History, Zap } from 'lucide-react';

// NexusEmergency ABI - comprehensive ABI for emergency functionality
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
    name: 'pauseInitiatedAt',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'contractPaused',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'isPaused',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'isRescueAvailable',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'timeUntilRescue',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
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
  {
    name: 'pauseContract',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [],
  },
  {
    name: 'unpauseContract',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'target', type: 'address' }],
    outputs: [],
  },
] as const;

// Event signatures for log parsing
const eventSignatures = {
  GlobalPauseInitiated: parseAbiItem('event GlobalPauseInitiated(address indexed initiator, uint256 timestamp)'),
  GlobalPauseLifted: parseAbiItem('event GlobalPauseLifted(address indexed lifter)'),
  ContractPaused: parseAbiItem('event ContractPaused(address indexed contractAddress, address indexed pauser)'),
  ContractUnpaused: parseAbiItem('event ContractUnpaused(address indexed contractAddress, address indexed unpauser)'),
  RecoveryModeActivated: parseAbiItem('event RecoveryModeActivated(address indexed activator)'),
  RecoveryModeDeactivated: parseAbiItem('event RecoveryModeDeactivated(address indexed deactivator)'),
};

// Track last action for notification purposes
type EmergencyAction = 'pause' | 'unpause' | 'emergency' | 'resolve' | null;

interface EmergencyEvent {
  id: string;
  type: 'pause' | 'unpause' | 'emergency_activated' | 'emergency_deactivated' | 'contract_paused' | 'contract_unpaused';
  actor: string;
  timestamp: number;
  blockNumber: bigint;
  txHash: string;
  contractAddress?: string;
}

interface CircuitBreaker {
  name: string;
  feature: string;
  isPaused: boolean;
  contractAddress: Address;
}

export default function EmergencyPage() {
  const { addresses, hasContract } = useContractAddresses();
  const publicClient = usePublicClient();
  const { notifyEmergencyPause, notifyEmergencyUnpause, notifyError } = useNotifications();

  // Use the useAdmin hook for role checks
  const { isAdmin, isPauser, isDefaultAdmin } = useAdmin();

  // Track the last action for proper notifications
  const lastActionRef = useRef<EmergencyAction>(null);

  // State for emergency events history
  const [emergencyEvents, setEmergencyEvents] = useState<EmergencyEvent[]>([]);
  const [isLoadingEvents, setIsLoadingEvents] = useState(true);
  const [eventsError, setEventsError] = useState<string | null>(null);

  // Check if emergency contract is deployed
  const isEmergencyDeployed = hasContract('nexusEmergency');

  // Read global pause status from contract
  const { data: isPausedData, refetch: refetchPaused, isLoading: isPausedLoading } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'globalPause',
    query: { enabled: isEmergencyDeployed },
  });

  // Read recovery mode status from contract
  const { data: isRecoveryModeData, refetch: refetchRecoveryMode, isLoading: isRecoveryLoading } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'recoveryMode',
    query: { enabled: isEmergencyDeployed },
  });

  // Read pause initiated timestamp
  const { data: pauseInitiatedAtData, refetch: refetchPauseTime } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'pauseInitiatedAt',
    query: { enabled: isEmergencyDeployed },
  });

  // Read rescue availability
  const { data: isRescueAvailableData } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'isRescueAvailable',
    query: { enabled: isEmergencyDeployed },
  });

  // Read time until rescue
  const { data: timeUntilRescueData } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'timeUntilRescue',
    query: { enabled: isEmergencyDeployed },
  });

  // Read contract-specific pause states for circuit breakers
  const { data: stakingPausedData, refetch: refetchStakingPaused } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'contractPaused',
    args: [addresses.nexusStaking],
    query: { enabled: isEmergencyDeployed && hasContract('nexusStaking') },
  });

  const { data: nftPausedData, refetch: refetchNFTPaused } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'contractPaused',
    args: [addresses.nexusNFT],
    query: { enabled: isEmergencyDeployed && hasContract('nexusNFT') },
  });

  const { data: tokenPausedData, refetch: refetchTokenPaused } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'contractPaused',
    args: [addresses.nexusToken],
    query: { enabled: isEmergencyDeployed && hasContract('nexusToken') },
  });

  const { data: governorPausedData, refetch: refetchGovernorPaused } = useReadContract({
    address: addresses.nexusEmergency,
    abi: nexusEmergencyAbi,
    functionName: 'contractPaused',
    args: [addresses.nexusGovernor],
    query: { enabled: isEmergencyDeployed && hasContract('nexusGovernor') },
  });

  // Coerce to booleans for consistent handling
  const isPaused = !!isPausedData;
  const isEmergencyMode = !!isRecoveryModeData;
  const pauseInitiatedAt = pauseInitiatedAtData ? Number(pauseInitiatedAtData) : 0;
  const isRescueAvailable = !!isRescueAvailableData;
  const timeUntilRescue = timeUntilRescueData ? Number(timeUntilRescueData) : 0;

  // Determine if user can perform emergency actions
  const canPause = !!(isDefaultAdmin || isAdmin || isPauser);
  const canTriggerEmergency = !!(isDefaultAdmin || isAdmin);

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

  // Fetch emergency event history
  const fetchEmergencyEvents = useCallback(async () => {
    if (!publicClient || !isEmergencyDeployed) {
      setIsLoadingEvents(false);
      return;
    }

    try {
      setIsLoadingEvents(true);
      setEventsError(null);

      // Get current block
      const currentBlock = await publicClient.getBlockNumber();
      // Look back ~7 days worth of blocks (assuming 12s block time)
      const fromBlock = currentBlock > 50400n ? currentBlock - 50400n : 0n;

      const events: EmergencyEvent[] = [];

      // Fetch GlobalPauseInitiated events
      try {
        const pauseInitLogs = await publicClient.getLogs({
          address: addresses.nexusEmergency,
          event: eventSignatures.GlobalPauseInitiated,
          fromBlock,
          toBlock: 'latest',
        });

        for (const log of pauseInitLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          events.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: 'pause',
            actor: log.args.initiator || '0x',
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
          });
        }
      } catch {
        // Event may not exist if never triggered
      }

      // Fetch GlobalPauseLifted events
      try {
        const pauseLiftLogs = await publicClient.getLogs({
          address: addresses.nexusEmergency,
          event: eventSignatures.GlobalPauseLifted,
          fromBlock,
          toBlock: 'latest',
        });

        for (const log of pauseLiftLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          events.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: 'unpause',
            actor: log.args.lifter || '0x',
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
          });
        }
      } catch {
        // Event may not exist if never triggered
      }

      // Fetch RecoveryModeActivated events
      try {
        const recoveryActivatedLogs = await publicClient.getLogs({
          address: addresses.nexusEmergency,
          event: eventSignatures.RecoveryModeActivated,
          fromBlock,
          toBlock: 'latest',
        });

        for (const log of recoveryActivatedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          events.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: 'emergency_activated',
            actor: log.args.activator || '0x',
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
          });
        }
      } catch {
        // Event may not exist if never triggered
      }

      // Fetch RecoveryModeDeactivated events
      try {
        const recoveryDeactivatedLogs = await publicClient.getLogs({
          address: addresses.nexusEmergency,
          event: eventSignatures.RecoveryModeDeactivated,
          fromBlock,
          toBlock: 'latest',
        });

        for (const log of recoveryDeactivatedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          events.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: 'emergency_deactivated',
            actor: log.args.deactivator || '0x',
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
          });
        }
      } catch {
        // Event may not exist if never triggered
      }

      // Fetch ContractPaused events
      try {
        const contractPausedLogs = await publicClient.getLogs({
          address: addresses.nexusEmergency,
          event: eventSignatures.ContractPaused,
          fromBlock,
          toBlock: 'latest',
        });

        for (const log of contractPausedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          events.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: 'contract_paused',
            actor: log.args.pauser || '0x',
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
            contractAddress: log.args.contractAddress || undefined,
          });
        }
      } catch {
        // Event may not exist if never triggered
      }

      // Fetch ContractUnpaused events
      try {
        const contractUnpausedLogs = await publicClient.getLogs({
          address: addresses.nexusEmergency,
          event: eventSignatures.ContractUnpaused,
          fromBlock,
          toBlock: 'latest',
        });

        for (const log of contractUnpausedLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber });
          events.push({
            id: `${log.transactionHash}-${log.logIndex}`,
            type: 'contract_unpaused',
            actor: log.args.unpauser || '0x',
            timestamp: Number(block.timestamp),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
            contractAddress: log.args.contractAddress || undefined,
          });
        }
      } catch {
        // Event may not exist if never triggered
      }

      // Sort events by timestamp descending (most recent first)
      events.sort((a, b) => b.timestamp - a.timestamp);
      setEmergencyEvents(events);
    } catch (error) {
      console.error('Failed to fetch emergency events:', error);
      setEventsError('Failed to load emergency event history');
    } finally {
      setIsLoadingEvents(false);
    }
  }, [publicClient, addresses.nexusEmergency, isEmergencyDeployed]);

  // Fetch events on mount and when contract changes
  useEffect(() => {
    fetchEmergencyEvents();
  }, [fetchEmergencyEvents]);

  // Refetch data and show notification after successful transaction
  useEffect(() => {
    if (isSuccess && txHash) {
      refetchPaused();
      refetchRecoveryMode();
      refetchPauseTime();
      refetchStakingPaused();
      refetchNFTPaused();
      refetchTokenPaused();
      refetchGovernorPaused();
      fetchEmergencyEvents();

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
  }, [isSuccess, txHash, refetchPaused, refetchRecoveryMode, refetchPauseTime, refetchStakingPaused, refetchNFTPaused, refetchTokenPaused, refetchGovernorPaused, fetchEmergencyEvents, notifyEmergencyPause, notifyEmergencyUnpause, reset]);

  // Handle write errors
  useEffect(() => {
    if (writeError) {
      notifyError('Transaction Failed', writeError.message || 'An error occurred');
      lastActionRef.current = null;
      reset();
    }
  }, [writeError, notifyError, reset]);

  const isLoading = isPending || isConfirming;
  const isDataLoading = isPausedLoading || isRecoveryLoading;

  // Circuit breaker data
  const circuitBreakers: CircuitBreaker[] = [
    {
      name: 'Staking',
      feature: 'Token staking and unstaking',
      isPaused: isPaused || !!stakingPausedData,
      contractAddress: addresses.nexusStaking,
    },
    {
      name: 'Governance',
      feature: 'Proposal creation and voting',
      isPaused: isPaused || !!governorPausedData,
      contractAddress: addresses.nexusGovernor,
    },
    {
      name: 'NFT Minting',
      feature: 'NFT minting operations',
      isPaused: isPaused || !!nftPausedData,
      contractAddress: addresses.nexusNFT,
    },
    {
      name: 'Transfers',
      feature: 'Token transfers',
      isPaused: isPaused || !!tokenPausedData,
      contractAddress: addresses.nexusToken,
    },
  ];

  // Contract status data for ProtocolStatus component
  const contracts = [
    {
      name: 'NexusToken',
      address: addresses.nexusToken || '0x...',
      isPaused: isPaused || !!tokenPausedData,
      version: '1.0.0'
    },
    {
      name: 'NexusNFT',
      address: addresses.nexusNFT || '0x...',
      isPaused: isPaused || !!nftPausedData,
      version: '1.0.0'
    },
    {
      name: 'NexusStaking',
      address: addresses.nexusStaking || '0x...',
      isPaused: isPaused || !!stakingPausedData,
      version: '1.0.0'
    },
    {
      name: 'NexusGovernor',
      address: addresses.nexusGovernor || '0x...',
      isPaused: isPaused || !!governorPausedData,
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

  // Helper to format time duration
  const formatDuration = (seconds: number): string => {
    if (seconds === 0) return 'Now';
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);

    const parts = [];
    if (days > 0) parts.push(`${days}d`);
    if (hours > 0) parts.push(`${hours}h`);
    if (mins > 0) parts.push(`${mins}m`);
    return parts.join(' ') || '< 1m';
  };

  // Helper to format event type for display
  const getEventLabel = (type: EmergencyEvent['type']): { label: string; variant: 'default' | 'destructive' | 'secondary' | 'outline' } => {
    switch (type) {
      case 'pause':
        return { label: 'Global Pause', variant: 'destructive' };
      case 'unpause':
        return { label: 'Global Unpause', variant: 'default' };
      case 'emergency_activated':
        return { label: 'Recovery Activated', variant: 'destructive' };
      case 'emergency_deactivated':
        return { label: 'Recovery Deactivated', variant: 'default' };
      case 'contract_paused':
        return { label: 'Contract Paused', variant: 'secondary' };
      case 'contract_unpaused':
        return { label: 'Contract Unpaused', variant: 'outline' };
      default:
        return { label: 'Unknown', variant: 'outline' };
    }
  };

  // Shortened address helper
  const shortenAddress = (address: string) =>
    `${address.slice(0, 6)}...${address.slice(-4)}`;

  // Determine threat level based on current state
  const getThreatLevel = (): { level: string; variant: 'default' | 'destructive' | 'secondary' | 'outline'; color: string } => {
    if (isEmergencyMode) {
      return { level: 'Critical', variant: 'destructive', color: 'text-red-600' };
    }
    if (isPaused) {
      return { level: 'High', variant: 'destructive', color: 'text-orange-600' };
    }
    const pausedBreakers = circuitBreakers.filter(cb => cb.isPaused).length;
    if (pausedBreakers > 0) {
      return { level: 'Elevated', variant: 'secondary', color: 'text-yellow-600' };
    }
    return { level: 'Low', variant: 'outline', color: 'text-green-600' };
  };

  const threatLevel = getThreatLevel();

  // Show not deployed message if contract not deployed
  if (!isEmergencyDeployed) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold">Emergency Controls</h1>
          <p className="text-muted-foreground">
            Protocol pause and circuit breaker management
          </p>
        </div>
        <Card>
          <CardContent className="py-8">
            <div className="text-center">
              <AlertTriangle className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-medium mb-2">Contract Not Deployed</h3>
              <p className="text-muted-foreground">
                The NexusEmergency contract is not deployed on this network.
                Please deploy the contract or switch to a network where it is available.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

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
            {isDataLoading ? (
              <Skeleton className="h-6 w-24" />
            ) : (
              <>
                <p className="text-lg font-semibold">
                  {isEmergencyMode ? 'Recovery Mode' : isPaused ? 'Paused' : 'Active'}
                </p>
                <Badge variant={isEmergencyMode ? 'destructive' : isPaused ? 'secondary' : 'default'}>
                  {isEmergencyMode ? 'Emergency' : isPaused ? 'Paused' : 'Operational'}
                </Badge>
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Clock className="h-4 w-4" />
              Pause Duration
            </CardTitle>
          </CardHeader>
          <CardContent className="flex items-center justify-between">
            {isDataLoading ? (
              <Skeleton className="h-6 w-24" />
            ) : (
              <>
                <p className="text-lg font-semibold">
                  {isPaused && pauseInitiatedAt > 0
                    ? formatDuration(Math.floor(Date.now() / 1000) - pauseInitiatedAt)
                    : 'N/A'}
                </p>
                {isPaused && (
                  <Badge variant={isRescueAvailable ? 'destructive' : 'outline'}>
                    {isRescueAvailable ? 'Rescue Available' : `Rescue in ${formatDuration(timeUntilRescue)}`}
                  </Badge>
                )}
              </>
            )}
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
            {isDataLoading ? (
              <Skeleton className="h-6 w-24" />
            ) : (
              <>
                <p className={`text-lg font-semibold ${threatLevel.color}`}>
                  {threatLevel.level}
                </p>
                <Badge variant={threatLevel.variant}>
                  {isEmergencyMode ? 'Critical' : isPaused ? 'Elevated' : 'Safe'}
                </Badge>
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Circuit Breaker Status */}
      <Card className="mb-8">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Zap className="h-5 w-5" />
            Circuit Breaker Status
          </CardTitle>
          <CardDescription>
            Feature-specific pause controls
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isDataLoading ? (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {[...Array(4)].map((_, i) => (
                <Skeleton key={i} className="h-20" />
              ))}
            </div>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {circuitBreakers.map((breaker) => (
                <div
                  key={breaker.name}
                  className={`p-4 rounded-lg border ${
                    breaker.isPaused ? 'border-destructive/50 bg-destructive/5' : 'border-border'
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium">{breaker.name}</span>
                    <Badge variant={breaker.isPaused ? 'destructive' : 'outline'}>
                      {breaker.isPaused ? 'Paused' : 'Active'}
                    </Badge>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {breaker.feature}
                  </p>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Main Controls */}
      <div className="grid gap-6 lg:grid-cols-2 mb-8">
        <EmergencyControls
          isPaused={isPaused}
          isEmergencyMode={isEmergencyMode}
          canPause={canPause}
          canTriggerEmergency={canTriggerEmergency}
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
          isLoading={isDataLoading}
        />
      </div>

      {/* Emergency Event History */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" />
            Emergency Event History
          </CardTitle>
          <CardDescription>
            Recent emergency actions (last 7 days)
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoadingEvents ? (
            <div className="space-y-3">
              {[...Array(3)].map((_, i) => (
                <Skeleton key={i} className="h-16" />
              ))}
            </div>
          ) : eventsError ? (
            <div className="text-center py-8 text-muted-foreground">
              <AlertTriangle className="h-8 w-8 mx-auto mb-2" />
              <p>{eventsError}</p>
            </div>
          ) : emergencyEvents.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Shield className="h-8 w-8 mx-auto mb-2" />
              <p>No emergency events recorded</p>
              <p className="text-sm mt-1">The protocol has been running smoothly</p>
            </div>
          ) : (
            <div className="space-y-3">
              {emergencyEvents.slice(0, 10).map((event) => {
                const { label, variant } = getEventLabel(event.type);
                return (
                  <div
                    key={event.id}
                    className="flex items-center justify-between p-3 rounded-lg border"
                  >
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <Badge variant={variant}>{label}</Badge>
                        {event.contractAddress && (
                          <span className="text-xs text-muted-foreground font-mono">
                            {shortenAddress(event.contractAddress)}
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-muted-foreground">
                        By {shortenAddress(event.actor)} at block {event.blockNumber.toString()}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm">
                        {new Date(event.timestamp * 1000).toLocaleDateString()}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {new Date(event.timestamp * 1000).toLocaleTimeString()}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
