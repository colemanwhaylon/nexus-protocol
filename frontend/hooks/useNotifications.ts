'use client';

import { useNotificationStore, type NotificationCategory, type NotificationType } from '@/stores/notificationStore';

interface NotifyOptions {
  title: string;
  message: string;
  type?: NotificationType;
  category?: NotificationCategory;
  txHash?: string;
  metadata?: Record<string, string | number | boolean>;
}

export function useNotifications() {
  const { addNotification, notifications, unreadCount, setIsOpen } = useNotificationStore();

  const notify = ({
    title,
    message,
    type = 'info',
    category = 'system',
    txHash,
    metadata,
  }: NotifyOptions) => {
    addNotification({
      type,
      category,
      title,
      message,
      txHash,
      metadata,
    });
  };

  // Convenience methods for common transaction types
  const notifyPending = (title: string, message: string, category: NotificationCategory = 'transaction') => {
    notify({ title, message, type: 'pending', category });
  };

  const notifySuccess = (title: string, message: string, category: NotificationCategory = 'transaction', txHash?: string) => {
    notify({ title, message, type: 'success', category, txHash });
  };

  const notifyError = (title: string, message: string, category: NotificationCategory = 'transaction') => {
    notify({ title, message, type: 'error', category });
  };

  // Staking-specific notifications
  const notifyStake = (amount: string, txHash?: string, success = true) => {
    if (success) {
      notifySuccess(
        'Stake Successful',
        `Successfully staked ${amount} NEXUS tokens`,
        'stake',
        txHash
      );
    } else {
      notifyError('Stake Failed', `Failed to stake ${amount} NEXUS tokens`, 'stake');
    }
  };

  const notifyUnstake = (amount: string, txHash?: string, success = true) => {
    if (success) {
      notifySuccess(
        'Unstake Initiated',
        `Initiated unbonding of ${amount} NEXUS tokens (7-day period)`,
        'unstake',
        txHash
      );
    } else {
      notifyError('Unstake Failed', `Failed to unstake ${amount} NEXUS tokens`, 'unstake');
    }
  };

  const notifyDelegate = (delegatee: string, txHash?: string, success = true) => {
    const shortAddress = `${delegatee.slice(0, 6)}...${delegatee.slice(-4)}`;
    if (success) {
      notifySuccess(
        'Delegation Successful',
        `Successfully delegated voting power to ${shortAddress}`,
        'delegate',
        txHash
      );
    } else {
      notifyError('Delegation Failed', `Failed to delegate to ${shortAddress}`, 'delegate');
    }
  };

  const notifyApproval = (amount: string, txHash?: string, success = true) => {
    if (success) {
      notifySuccess(
        'Approval Successful',
        `Approved ${amount} NEXUS for staking`,
        'approval',
        txHash
      );
    } else {
      notifyError('Approval Failed', `Failed to approve NEXUS tokens`, 'approval');
    }
  };

  // NFT-specific notifications
  const notifyMint = (tokenId: string, txHash?: string, success = true) => {
    if (success) {
      notifySuccess(
        'NFT Minted',
        `Successfully minted Nexus NFT #${tokenId}`,
        'mint',
        txHash
      );
    } else {
      notifyError('Mint Failed', 'Failed to mint NFT', 'mint');
    }
  };

  const notifyNFTTransfer = (tokenId: string, to: string, txHash?: string, success = true) => {
    const shortAddress = `${to.slice(0, 6)}...${to.slice(-4)}`;
    if (success) {
      notify({
        title: 'NFT Transferred',
        message: `Successfully transferred NFT #${tokenId} to ${shortAddress}`,
        type: 'success',
        category: 'nft',
        txHash,
        metadata: { tokenId, recipient: to },
      });
    } else {
      notify({
        title: 'Transfer Failed',
        message: `Failed to transfer NFT #${tokenId}`,
        type: 'error',
        category: 'nft',
      });
    }
  };

  const notifyNFTReveal = (tokenId: string, success = true) => {
    if (success) {
      notify({
        title: 'NFT Revealed',
        message: `NFT #${tokenId} has been revealed! Check out your new artwork.`,
        type: 'success',
        category: 'nft',
        metadata: { tokenId },
      });
    } else {
      notify({
        title: 'Reveal Failed',
        message: `Failed to reveal NFT #${tokenId}`,
        type: 'error',
        category: 'nft',
      });
    }
  };

  // KYC-specific notifications
  const notifyKYCStarted = () => {
    notify({
      title: 'KYC Verification Started',
      message: 'Your identity verification is in progress. This may take a few minutes.',
      type: 'pending',
      category: 'kyc',
    });
  };

  const notifyKYCApproved = () => {
    notify({
      title: 'KYC Approved',
      message: 'Congratulations! Your identity has been verified. You now have full platform access.',
      type: 'success',
      category: 'kyc',
    });
  };

  const notifyKYCRejected = (reason?: string) => {
    notify({
      title: 'KYC Verification Failed',
      message: reason || 'Your identity verification was not approved. Please contact support.',
      type: 'error',
      category: 'kyc',
      metadata: reason ? { reason } : undefined,
    });
  };

  const notifyPaymentRequired = (service: string, amount: string, currency: string) => {
    notify({
      title: 'Payment Required',
      message: `${service} requires payment of ${amount} ${currency} to proceed.`,
      type: 'warning',
      category: 'kyc',
      metadata: { service, amount, currency },
    });
  };

  // Admin-specific notifications
  const notifyRoleGranted = (role: string, address: string, txHash?: string) => {
    const shortAddress = `${address.slice(0, 6)}...${address.slice(-4)}`;
    notify({
      title: 'Role Granted',
      message: `${role} role has been granted to ${shortAddress}`,
      type: 'success',
      category: 'admin',
      txHash,
      metadata: { role, address },
    });
  };

  const notifyRoleRevoked = (role: string, address: string, txHash?: string) => {
    const shortAddress = `${address.slice(0, 6)}...${address.slice(-4)}`;
    notify({
      title: 'Role Revoked',
      message: `${role} role has been revoked from ${shortAddress}`,
      type: 'warning',
      category: 'admin',
      txHash,
      metadata: { role, address },
    });
  };

  // Emergency-specific notifications
  const notifyEmergencyPause = (contract: string, txHash?: string) => {
    notify({
      title: 'Emergency Pause Activated',
      message: `${contract} has been paused due to emergency protocol activation.`,
      type: 'error',
      category: 'emergency',
      txHash,
      metadata: { contract, action: 'pause' },
    });
  };

  const notifyEmergencyUnpause = (contract: string, txHash?: string) => {
    notify({
      title: 'Emergency Pause Lifted',
      message: `${contract} has been unpaused. Normal operations have resumed.`,
      type: 'success',
      category: 'emergency',
      txHash,
      metadata: { contract, action: 'unpause' },
    });
  };

  // Payment-specific notifications
  const notifyPaymentPending = (method: string, amount: string, currency: string) => {
    notify({
      title: 'Payment Processing',
      message: `Your ${method} payment of ${amount} ${currency} is being processed.`,
      type: 'pending',
      category: 'payment',
      metadata: { method, amount, currency },
    });
  };

  const notifyPaymentCompleted = (method: string, amount: string, currency: string, txHash?: string) => {
    notify({
      title: 'Payment Successful',
      message: `Your ${method} payment of ${amount} ${currency} has been completed.`,
      type: 'success',
      category: 'payment',
      txHash,
      metadata: { method, amount, currency },
    });
  };

  const notifyPaymentFailed = (method: string, reason?: string) => {
    notify({
      title: 'Payment Failed',
      message: reason || `Your ${method} payment could not be processed. Please try again.`,
      type: 'error',
      category: 'payment',
      metadata: { method, reason: reason || 'unknown' },
    });
  };

  // Governance-specific notifications
  const notifyProposalCreated = (proposalId: string, title: string, txHash?: string) => {
    notify({
      title: 'Proposal Created',
      message: `Your proposal "${title}" has been submitted successfully.`,
      type: 'success',
      category: 'governance',
      txHash,
      metadata: { proposalId, title },
    });
  };

  const notifyVoteCast = (proposalId: string, support: 'for' | 'against' | 'abstain', txHash?: string) => {
    notify({
      title: 'Vote Cast',
      message: `Your vote (${support}) on proposal #${proposalId} has been recorded.`,
      type: 'success',
      category: 'governance',
      txHash,
      metadata: { proposalId, support },
    });
  };

  return {
    notify,
    notifyPending,
    notifySuccess,
    notifyError,
    // Staking
    notifyStake,
    notifyUnstake,
    notifyDelegate,
    notifyApproval,
    // NFT
    notifyMint,
    notifyNFTTransfer,
    notifyNFTReveal,
    // KYC
    notifyKYCStarted,
    notifyKYCApproved,
    notifyKYCRejected,
    notifyPaymentRequired,
    // Admin
    notifyRoleGranted,
    notifyRoleRevoked,
    // Emergency
    notifyEmergencyPause,
    notifyEmergencyUnpause,
    // Payment
    notifyPaymentPending,
    notifyPaymentCompleted,
    notifyPaymentFailed,
    // Governance
    notifyProposalCreated,
    notifyVoteCast,
    // State
    notifications,
    unreadCount: unreadCount(),
    openNotifications: () => setIsOpen(true),
  };
}
