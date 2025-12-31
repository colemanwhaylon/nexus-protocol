'use client';

import { Bell } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useNotificationStore } from '@/stores/notificationStore';
import { cn } from '@/lib/utils';

export function NotificationBell() {
  const { setIsOpen, unreadCount } = useNotificationStore();
  const count = unreadCount();

  return (
    <Button
      variant="ghost"
      size="icon"
      className="relative"
      onClick={() => setIsOpen(true)}
      aria-label={`Notifications${count > 0 ? ` (${count} unread)` : ''}`}
    >
      <Bell className="h-5 w-5" />
      {count > 0 && (
        <span
          className={cn(
            'absolute -top-1 -right-1 flex items-center justify-center',
            'min-w-[18px] h-[18px] px-1 rounded-full',
            'bg-destructive text-destructive-foreground',
            'text-xs font-medium',
            'animate-in zoom-in-50 duration-200'
          )}
        >
          {count > 99 ? '99+' : count}
        </span>
      )}
    </Button>
  );
}
