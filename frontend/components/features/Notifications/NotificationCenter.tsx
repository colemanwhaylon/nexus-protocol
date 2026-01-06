'use client';

import { useEffect, useState } from 'react';
import { X, Bell, Check, Trash2, ExternalLink, CheckCheck, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  useNotificationStore,
  formatNotificationForClaude,
  formatAllNotificationsForClaude,
  type Notification,
  type NotificationType,
} from '@/stores/notificationStore';
import { cn } from '@/lib/utils';
import { useChainId } from 'wagmi';

function getExplorerUrl(chainId: number | undefined, txHash: string): string {
  switch (chainId) {
    case 1:
      return `https://etherscan.io/tx/${txHash}`;
    case 11155111:
      return `https://sepolia.etherscan.io/tx/${txHash}`;
    default:
      // Default to Sepolia for testnet development
      return `https://sepolia.etherscan.io/tx/${txHash}`;
  }
}

const typeStyles: Record<NotificationType, { bg: string; text: string; icon: string }> = {
  success: { bg: 'bg-green-500/10', text: 'text-green-500', icon: '✓' },
  error: { bg: 'bg-red-500/10', text: 'text-red-500', icon: '✕' },
  warning: { bg: 'bg-yellow-500/10', text: 'text-yellow-500', icon: '⚠' },
  info: { bg: 'bg-blue-500/10', text: 'text-blue-500', icon: 'ℹ' },
  pending: { bg: 'bg-purple-500/10', text: 'text-purple-500', icon: '◐' },
};

function NotificationItem({
  notification,
  onCopy,
  chainId,
}: {
  notification: Notification;
  onCopy: (text: string) => void;
  chainId: number | undefined;
}) {
  const { removeNotification } = useNotificationStore();
  const style = typeStyles[notification.type];
  const timeAgo = getTimeAgo(notification.timestamp);

  return (
    <div
      className={cn(
        'p-3 rounded-lg border transition-colors',
        notification.read ? 'bg-background' : 'bg-muted/50',
        'hover:bg-muted'
      )}
    >
      <div className="flex items-start gap-3">
        {/* Type Icon */}
        <div className={cn('w-8 h-8 rounded-full flex items-center justify-center text-sm', style.bg, style.text)}>
          {style.icon}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <span className="font-medium text-sm truncate">{notification.title}</span>
            <Badge variant="outline" className="text-xs">
              {notification.category}
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground line-clamp-2">{notification.message}</p>
          <div className="flex items-center gap-2 mt-2">
            <span className="text-xs text-muted-foreground">{timeAgo}</span>
            {notification.txHash && (
              <a
                href={getExplorerUrl(chainId, notification.txHash)}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-primary hover:underline flex items-center gap-1"
              >
                View Tx <ExternalLink className="h-3 w-3" />
              </a>
            )}
          </div>
        </div>

        {/* Actions */}
        <div className="flex flex-col gap-1">
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7"
            onClick={() => onCopy(formatNotificationForClaude(notification))}
            title="Copy for Claude"
          >
            <Sparkles className="h-3.5 w-3.5" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7 text-muted-foreground hover:text-destructive"
            onClick={() => removeNotification(notification.id)}
            title="Remove"
          >
            <X className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>
    </div>
  );
}

export function NotificationCenter() {
  const { notifications, isOpen, setIsOpen, clearAll, markAllAsRead } = useNotificationStore();
  const [copied, setCopied] = useState(false);
  const chainId = useChainId();

  // Close on escape
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        setIsOpen(false);
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [isOpen, setIsOpen]);

  const handleCopy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  const handleCopyAll = () => {
    handleCopy(formatAllNotificationsForClaude(notifications));
  };

  if (!isOpen) return null;

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/20 z-40"
        onClick={() => setIsOpen(false)}
      />

      {/* Panel */}
      <div className="fixed right-0 top-0 h-full w-full max-w-md bg-background border-l shadow-xl z-50 flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b">
          <div className="flex items-center gap-2">
            <Bell className="h-5 w-5" />
            <h2 className="font-semibold">Notifications</h2>
            <Badge variant="secondary">{notifications.length}</Badge>
          </div>
          <div className="flex items-center gap-1">
            <Button
              variant="ghost"
              size="sm"
              onClick={handleCopyAll}
              disabled={notifications.length === 0}
              title="Copy all for Claude"
            >
              {copied ? (
                <CheckCheck className="h-4 w-4 text-green-500" />
              ) : (
                <Sparkles className="h-4 w-4" />
              )}
              <span className="ml-1 text-xs">Copy for Claude</span>
            </Button>
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setIsOpen(false)}
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </div>

        {/* Actions Bar */}
        {notifications.length > 0 && (
          <div className="flex items-center justify-between px-4 py-2 border-b bg-muted/30">
            <Button
              variant="ghost"
              size="sm"
              onClick={markAllAsRead}
              className="text-xs"
            >
              <Check className="h-3 w-3 mr-1" />
              Mark all read
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={clearAll}
              className="text-xs text-destructive hover:text-destructive"
            >
              <Trash2 className="h-3 w-3 mr-1" />
              Clear all
            </Button>
          </div>
        )}

        {/* Notifications List */}
        <ScrollArea className="flex-1">
          <div className="p-4 space-y-3">
            {notifications.length === 0 ? (
              <div className="text-center py-12">
                <Bell className="h-12 w-12 mx-auto mb-4 text-muted-foreground/50" />
                <p className="text-muted-foreground">No notifications yet</p>
                <p className="text-xs text-muted-foreground mt-1">
                  Transaction updates will appear here
                </p>
              </div>
            ) : (
              notifications.map((notification) => (
                <NotificationItem
                  key={notification.id}
                  notification={notification}
                  onCopy={handleCopy}
                  chainId={chainId}
                />
              ))
            )}
          </div>
        </ScrollArea>

        {/* Footer */}
        <div className="p-4 border-t bg-muted/30">
          <p className="text-xs text-muted-foreground text-center">
            💡 Click <Sparkles className="h-3 w-3 inline" /> to copy notifications for Claude AI assistance
          </p>
        </div>
      </div>
    </>
  );
}

// Helper function
function getTimeAgo(timestamp: number): string {
  const seconds = Math.floor((Date.now() - timestamp) / 1000);

  if (seconds < 60) return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;

  return new Date(timestamp).toLocaleDateString();
}
