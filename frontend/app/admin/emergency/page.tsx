'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { EmergencyControls, ProtocolStatus } from '@/components/features/Admin';
import { useChainId } from 'wagmi';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { AlertTriangle, Shield, Activity } from 'lucide-react';

export default function EmergencyPage() {
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);
  
  const [isPaused, setIsPaused] = useState(false);
  const [isEmergencyMode, setIsEmergencyMode] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

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
      name: 'RewardsDistributor', 
      address: addresses.rewardsDistributor || '0x...', 
      isPaused: isPaused,
      version: '1.0.0'
    },
  ];

  const handlePause = async () => {
    setIsLoading(true);
    try {
      // TODO: Call smart contract pause function
      await new Promise(resolve => setTimeout(resolve, 1000));
      setIsPaused(true);
      console.log('Protocol paused');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUnpause = async () => {
    setIsLoading(true);
    try {
      // TODO: Call smart contract unpause function
      await new Promise(resolve => setTimeout(resolve, 1000));
      setIsPaused(false);
      console.log('Protocol unpaused');
    } finally {
      setIsLoading(false);
    }
  };

  const handleTriggerEmergency = async () => {
    setIsLoading(true);
    try {
      // TODO: Call smart contract emergency function
      await new Promise(resolve => setTimeout(resolve, 1000));
      setIsEmergencyMode(true);
      setIsPaused(true);
      console.log('Emergency mode triggered');
    } finally {
      setIsLoading(false);
    }
  };

  const handleResolveEmergency = async () => {
    setIsLoading(true);
    try {
      // TODO: Call smart contract resolve emergency function
      await new Promise(resolve => setTimeout(resolve, 1000));
      setIsEmergencyMode(false);
      setIsPaused(false);
      console.log('Emergency mode resolved');
    } finally {
      setIsLoading(false);
    }
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
