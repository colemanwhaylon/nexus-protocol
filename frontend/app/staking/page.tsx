'use client';

import { useState, useEffect, useRef } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAccount, useChainId } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { CheckCircle2 } from 'lucide-react';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { useStaking } from '@/hooks/useStaking';
import { useTokenBalance } from '@/hooks/useTokenBalance';
import { useTokenApproval } from '@/hooks/useTokenApproval';
import { useContractAddresses } from '@/hooks/useContractAddresses';
import { DelegationForm } from '@/components/features/Staking/DelegationForm';
import { useNotifications } from '@/hooks/useNotifications';
import type { Address } from 'viem';

type StakingAction = 'stake' | 'unstake' | 'delegate';

export default function StakingPage() {
  const { address, isConnected } = useAccount();
  const [stakeAmount, setStakeAmount] = useState('');
  const [unstakeAmount, setUnstakeAmount] = useState('');
  const [showApprovalSuccess, setShowApprovalSuccess] = useState(false);
  const [lastAction, setLastAction] = useState<{ type: StakingAction; value: string } | null>(null);

  // Notifications
  const { notifyApproval, notifyStake, notifyUnstake, notifyDelegate, notifyError } = useNotifications();

  // Get contract addresses from database
  const { addresses, isLoading: addressesLoading, hasContract } = useContractAddresses();
  const tokenAddress = addresses.nexusToken;
  const stakingAddress = addresses.nexusStaking;
  const isReady = hasContract('nexusToken') && hasContract('nexusStaking');

  // Hooks
  const { balance: tokenBalance, refetch: refetchBalance } = useTokenBalance({
    tokenAddress,
  });

  const {
    allowance,
    approve,
    isPending: isApprovePending,
    isConfirmed: isApproveConfirmed,
    refetch: refetchAllowance,
  } = useTokenApproval({
    tokenAddress,
    spender: stakingAddress,
  });

  const {
    stake,
    unstake,
    delegate,
    stakedBalance,
    currentDelegatee,
    votingPower,
    totalStaked,
    hash: stakingHash,
    isPending: isStakePending,
    isConfirming,
    isSuccess,
    error: stakingError,
    reset: resetStaking,
    refetch: refetchStaking,
  } = useStaking();

  // Track processed transaction hashes to avoid duplicate refetches
  const processedHashRef = useRef<string | null>(null);

  // Refetch after successful approve and show success message
  useEffect(() => {
    if (isApproveConfirmed) {
      refetchAllowance();
      setShowApprovalSuccess(true);
      notifyApproval(stakeAmount || '0');
      // Hide success message after 3 seconds
      const timer = setTimeout(() => setShowApprovalSuccess(false), 3000);
      return () => clearTimeout(timer);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isApproveConfirmed, refetchAllowance]);

  // Refetch after successful stake/unstake/delegate
  useEffect(() => {
    if (isSuccess && stakingHash && stakingHash !== processedHashRef.current) {
      processedHashRef.current = stakingHash;

      // Send notification based on last action
      if (lastAction) {
        switch (lastAction.type) {
          case 'stake':
            notifyStake(lastAction.value, stakingHash);
            break;
          case 'unstake':
            notifyUnstake(lastAction.value, stakingHash);
            break;
          case 'delegate':
            notifyDelegate(lastAction.value, stakingHash);
            break;
        }
        setLastAction(null);
      }

      // Delay to ensure blockchain state is updated, then refetch
      setTimeout(async () => {
        await refetchBalance();
        await refetchStaking();
        await refetchAllowance();
        setStakeAmount('');
        setUnstakeAmount('');
      }, 2000);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, stakingHash, refetchBalance, refetchStaking, refetchAllowance]);

  // Handle staking errors
  useEffect(() => {
    if (stakingError) {
      // Extract user-friendly error message
      let errorMessage = 'Transaction failed. Please try again.';
      const errorString = stakingError.message || String(stakingError);

      if (errorString.includes('User rejected') || errorString.includes('user rejected')) {
        errorMessage = 'Transaction was rejected by user.';
      } else if (errorString.includes('nonce too low')) {
        errorMessage = 'Nonce mismatch. Please reset your wallet activity (MetaMask → Settings → Advanced → Clear activity tab data).';
      } else if (errorString.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for transaction.';
      } else if (errorString.includes('execution reverted')) {
        errorMessage = 'Contract execution reverted. Check staking requirements.';
      }

      // Notify based on last action or generic error
      if (lastAction) {
        switch (lastAction.type) {
          case 'stake':
            notifyStake(lastAction.value, undefined, false);
            break;
          case 'unstake':
            notifyUnstake(lastAction.value, undefined, false);
            break;
          case 'delegate':
            notifyDelegate(lastAction.value, undefined, false);
            break;
        }
        setLastAction(null);
      } else {
        notifyError('Transaction Failed', errorMessage);
      }

      // Reset the error state
      resetStaking();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stakingError]);

  // Format numbers for display
  const formatTokens = (value: bigint | undefined) => {
    if (!value) return '0';
    return parseFloat(formatUnits(value, 18)).toLocaleString(undefined, {
      maximumFractionDigits: 2,
    });
  };

  // Check if approval is needed
  const stakeAmountBigInt = stakeAmount ? parseUnits(stakeAmount, 18) : BigInt(0);
  const needsApproval = allowance !== undefined && stakeAmountBigInt > allowance;

  // Handle stake
  const handleStake = () => {
    if (!stakeAmount) return;
    const amount = parseUnits(stakeAmount, 18);
    setLastAction({ type: 'stake', value: stakeAmount });
    stake(amount);
  };

  // Handle approve
  const handleApprove = () => {
    if (!stakeAmount) return;
    const amount = parseUnits(stakeAmount, 18);
    approve(stakingAddress, amount);
  };

  // Handle unstake
  const handleUnstake = () => {
    if (!unstakeAmount) return;
    const amount = parseUnits(unstakeAmount, 18);
    setLastAction({ type: 'unstake', value: unstakeAmount });
    unstake(amount);
  };

  // Handle max stake
  const handleMaxStake = () => {
    if (tokenBalance) {
      setStakeAmount(formatUnits(tokenBalance, 18));
    }
  };

  // Handle max unstake
  const handleMaxUnstake = () => {
    if (stakedBalance) {
      setUnstakeAmount(formatUnits(stakedBalance, 18));
    }
  };

  const isLoading = isStakePending || isConfirming || isApprovePending;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Staking</h1>
        <p className="text-muted-foreground">
          Stake your NEXUS tokens to earn rewards and participate in governance
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Staked</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{formatTokens(totalStaked)} NEXUS</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">APY</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold text-green-500">12.5%</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Your Stake</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{formatTokens(stakedBalance)} NEXUS</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Voting Power</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">{formatTokens(votingPower)} NEXUS</p>
            {stakedBalance && stakedBalance > 0n && votingPower === 0n && currentDelegatee && (
              <p className="text-xs text-muted-foreground mt-1">
                Delegated to {currentDelegatee.slice(0, 6)}...{currentDelegatee.slice(-4)}
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Wallet Balance */}
      {isConnected && (
        <Card className="mb-6">
          <CardContent className="pt-6">
            <p className="text-sm text-muted-foreground">
              Your Wallet Balance: <span className="font-bold text-foreground">{formatTokens(tokenBalance)} NEXUS</span>
            </p>
          </CardContent>
        </Card>
      )}

      {/* Staking Actions */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Stake Card */}
        <Card>
          <CardHeader>
            <CardTitle>Stake Tokens</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {!isConnected ? (
              <p className="text-muted-foreground">
                Connect your wallet to stake tokens.
              </p>
            ) : (
              <>
                <div className="space-y-2">
                  <Label htmlFor="stakeAmount">Amount to Stake</Label>
                  <div className="flex gap-2">
                    <Input
                      id="stakeAmount"
                      type="number"
                      placeholder="0.0"
                      value={stakeAmount}
                      onChange={(e) => setStakeAmount(e.target.value)}
                      disabled={isLoading}
                    />
                    <Button
                      variant="outline"
                      onClick={handleMaxStake}
                      disabled={isLoading}
                    >
                      MAX
                    </Button>
                  </div>
                </div>

                {showApprovalSuccess && (
                  <Alert className="border-green-500 bg-green-50 dark:bg-green-950">
                    <CheckCircle2 className="h-4 w-4 text-green-600" />
                    <AlertDescription className="text-green-700 dark:text-green-300">
                      Approval successful! You can now stake your tokens.
                    </AlertDescription>
                  </Alert>
                )}

                {needsApproval ? (
                  <Button
                    className="w-full"
                    onClick={handleApprove}
                    disabled={!stakeAmount || isLoading}
                    suppressHydrationWarning
                  >
                    <span suppressHydrationWarning>
                      {isApprovePending ? 'Approving...' : 'Approve NEXUS'}
                    </span>
                  </Button>
                ) : (
                  <Button
                    className="w-full"
                    onClick={handleStake}
                    disabled={!stakeAmount || isLoading}
                    suppressHydrationWarning
                  >
                    <span suppressHydrationWarning>
                      {isStakePending || isConfirming ? 'Staking...' : 'Stake NEXUS'}
                    </span>
                  </Button>
                )}
              </>
            )}
          </CardContent>
        </Card>

        {/* Unstake Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              Unstake Tokens
              <Badge variant="outline">7-day unbonding</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {!isConnected ? (
              <p className="text-muted-foreground">
                Connect your wallet to unstake tokens.
              </p>
            ) : (
              <>
                <div className="space-y-2">
                  <Label htmlFor="unstakeAmount">Amount to Unstake</Label>
                  <div className="flex gap-2">
                    <Input
                      id="unstakeAmount"
                      type="number"
                      placeholder="0.0"
                      value={unstakeAmount}
                      onChange={(e) => setUnstakeAmount(e.target.value)}
                      disabled={isLoading || !stakedBalance || stakedBalance === BigInt(0)}
                    />
                    <Button
                      variant="outline"
                      onClick={handleMaxUnstake}
                      disabled={isLoading || !stakedBalance || stakedBalance === BigInt(0)}
                    >
                      MAX
                    </Button>
                  </div>
                </div>

                <Button
                  className="w-full"
                  onClick={handleUnstake}
                  disabled={!unstakeAmount || isLoading || !stakedBalance || stakedBalance === BigInt(0)}
                  suppressHydrationWarning
                >
                  <span suppressHydrationWarning>
                    {isStakePending || isConfirming ? 'Unstaking...' : 'Unstake NEXUS'}
                  </span>
                </Button>

                <p className="text-xs text-muted-foreground">
                  Note: Unstaked tokens have a 7-day unbonding period before they can be withdrawn.
                </p>
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Delegation Section */}
      {isConnected && (
        <div className="mt-6">
          <DelegationForm
            userAddress={address}
            currentDelegate={currentDelegatee}
            onDelegate={async (delegatee: Address) => {
              setLastAction({ type: 'delegate', value: delegatee });
              delegate(delegatee);
            }}
            isLoading={isLoading}
            disabled={!stakedBalance || stakedBalance === BigInt(0)}
          />
        </div>
      )}
    </div>
  );
}
