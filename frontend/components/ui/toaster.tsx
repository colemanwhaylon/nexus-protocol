'use client';

import { Toaster as SonnerToaster } from 'sonner';

export function Toaster() {
  return (
    <SonnerToaster
      position="bottom-right"
      toastOptions={{
        classNames: {
          toast: 'group toast bg-background text-foreground border-border shadow-lg',
          description: 'text-muted-foreground',
          actionButton: 'bg-primary text-primary-foreground',
          cancelButton: 'bg-muted text-muted-foreground',
          error: 'border-destructive/50 bg-destructive/10',
          success: 'border-green-500/50 bg-green-500/10',
          warning: 'border-yellow-500/50 bg-yellow-500/10',
          info: 'border-blue-500/50 bg-blue-500/10',
        },
      }}
    />
  );
}
