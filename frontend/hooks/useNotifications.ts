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

  return {
    notify,
    notifyPending,
    notifySuccess,
    notifyError,
    notifyStake,
    notifyUnstake,
    notifyDelegate,
    notifyApproval,
    notifyMint,
    notifications,
    unreadCount: unreadCount(),
    openNotifications: () => setIsOpen(true),
  };
}
