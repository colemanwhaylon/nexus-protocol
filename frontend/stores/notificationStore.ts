'use client';

import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type NotificationType = 'success' | 'error' | 'warning' | 'info' | 'pending';
export type NotificationCategory =
  | 'transaction'
  | 'approval'
  | 'stake'
  | 'unstake'
  | 'delegate'
  | 'mint'
  | 'governance'
  | 'system'
  | 'kyc'        // KYC verification events
  | 'admin'      // Admin panel operations
  | 'emergency'  // Emergency pause/unpause events
  | 'nft'        // NFT transfer, reveal, burn, etc.
  | 'payment'    // Payment events (Stripe, crypto)
  | 'relay';     // Meta-transaction relay events

export interface Notification {
  id: string;
  type: NotificationType;
  category: NotificationCategory;
  title: string;
  message: string;
  timestamp: number;
  read: boolean;
  txHash?: string;
  metadata?: Record<string, string | number | boolean>;
}

interface NotificationState {
  notifications: Notification[];
  isOpen: boolean;

  // Actions
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
  removeNotification: (id: string) => void;
  clearAll: () => void;
  setIsOpen: (isOpen: boolean) => void;

  // Computed
  unreadCount: () => number;
}

// Generate unique ID
const generateId = () => `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

// Log to console for Claude Chrome extension to read
const logForClaude = (notification: Notification) => {
  const logData = {
    _nexusNotification: true,
    type: notification.type,
    category: notification.category,
    title: notification.title,
    message: notification.message,
    timestamp: new Date(notification.timestamp).toISOString(),
    txHash: notification.txHash,
    metadata: notification.metadata,
  };

  // Structured log that Claude can parse
  console.log('%c[Nexus Protocol]', 'color: #8b5cf6; font-weight: bold', logData);
};

export const useNotificationStore = create<NotificationState>()(
  persist(
    (set, get) => ({
      notifications: [],
      isOpen: false,

      addNotification: (notificationData) => {
        const notification: Notification = {
          ...notificationData,
          id: generateId(),
          timestamp: Date.now(),
          read: false,
        };

        // Deduplicate: Check if same txHash was added in last 5 seconds
        const existingNotifications = get().notifications;
        if (notification.txHash) {
          const recentDuplicate = existingNotifications.find(
            (n) => n.txHash === notification.txHash &&
                   Date.now() - n.timestamp < 5000
          );
          if (recentDuplicate) {
            console.log('[Nexus] Skipping duplicate notification for tx:', notification.txHash);
            return; // Skip duplicate
          }
        }

        // Log for Claude Chrome extension
        logForClaude(notification);

        set((state) => ({
          notifications: [notification, ...state.notifications].slice(0, 100), // Keep last 100
        }));
      },

      markAsRead: (id) => {
        set((state) => ({
          notifications: state.notifications.map((n) =>
            n.id === id ? { ...n, read: true } : n
          ),
        }));
      },

      markAllAsRead: () => {
        set((state) => ({
          notifications: state.notifications.map((n) => ({ ...n, read: true })),
        }));
      },

      removeNotification: (id) => {
        set((state) => ({
          notifications: state.notifications.filter((n) => n.id !== id),
        }));
      },

      clearAll: () => {
        set({ notifications: [] });
      },

      setIsOpen: (isOpen) => {
        set({ isOpen });
        // Mark all as read when opening
        if (isOpen) {
          get().markAllAsRead();
        }
      },

      unreadCount: () => {
        return get().notifications.filter((n) => !n.read).length;
      },
    }),
    {
      name: 'nexus-notifications',
      partialize: (state) => ({ notifications: state.notifications }),
    }
  )
);

// Helper to format notification for copying to Claude
export function formatNotificationForClaude(notification: Notification): string {
  const lines = [
    `## Nexus Protocol Notification`,
    ``,
    `**Type:** ${notification.type}`,
    `**Category:** ${notification.category}`,
    `**Title:** ${notification.title}`,
    `**Message:** ${notification.message}`,
    `**Time:** ${new Date(notification.timestamp).toLocaleString()}`,
  ];

  if (notification.txHash) {
    lines.push(`**Transaction:** ${notification.txHash}`);
  }

  if (notification.metadata && Object.keys(notification.metadata).length > 0) {
    lines.push(``, `**Details:**`);
    for (const [key, value] of Object.entries(notification.metadata)) {
      lines.push(`- ${key}: ${value}`);
    }
  }

  lines.push(
    ``,
    `---`,
    `*Please help me understand this notification or troubleshoot any issues.*`
  );

  return lines.join('\n');
}

// Helper to format all notifications for Claude
export function formatAllNotificationsForClaude(notifications: Notification[]): string {
  if (notifications.length === 0) {
    return 'No notifications to share.';
  }

  const lines = [
    `# Nexus Protocol Transaction History`,
    ``,
    `Here are my recent ${notifications.length} notification(s):`,
    ``,
  ];

  notifications.forEach((n, i) => {
    lines.push(
      `### ${i + 1}. ${n.title}`,
      `- **Status:** ${n.type}`,
      `- **Category:** ${n.category}`,
      `- **Message:** ${n.message}`,
      `- **Time:** ${new Date(n.timestamp).toLocaleString()}`,
      n.txHash ? `- **Tx:** ${n.txHash}` : '',
      ``
    );
  });

  lines.push(
    `---`,
    `*Please help me understand these transactions or troubleshoot any issues.*`
  );

  return lines.filter(Boolean).join('\n');
}
