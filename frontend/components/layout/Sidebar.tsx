'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Coins,
  Image,
  Vote,
  Shield,
  Settings,
  Users,
  AlertTriangle,
  DollarSign,
  type LucideIcon,
} from 'lucide-react';
import { cn } from '@/lib/utils';

type NavItem = {
  name: string;
  href: string;
  icon: LucideIcon;
  badge?: string;
};

type SidebarProps = {
  variant?: 'default' | 'admin';
};

const defaultNavItems: NavItem[] = [
  { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { name: 'Staking', href: '/staking', icon: Coins },
  { name: 'NFT Gallery', href: '/nft/gallery', icon: Image },
  { name: 'Governance', href: '/governance', icon: Vote },
];

const adminNavItems: NavItem[] = [
  { name: 'Overview', href: '/admin', icon: LayoutDashboard },
  { name: 'Compliance', href: '/admin/compliance', icon: Shield },
  { name: 'Pricing', href: '/admin/pricing', icon: DollarSign },
  { name: 'Users', href: '/admin/users', icon: Users },
  { name: 'Emergency', href: '/admin/emergency', icon: AlertTriangle },
  { name: 'Roles', href: '/admin/roles', icon: Settings },
];

export function Sidebar({ variant = 'default' }: SidebarProps) {
  const pathname = usePathname();
  const navItems = variant === 'admin' ? adminNavItems : defaultNavItems;

  return (
    <aside className="hidden w-64 flex-shrink-0 border-r bg-card lg:block">
      <div className="flex h-full flex-col">
        <div className="flex-1 overflow-y-auto py-6">
          <nav className="space-y-1 px-3">
            {navItems.map((item) => {
              const isActive = pathname === item.href || pathname.startsWith(item.href + '/');
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={cn(
                    'group flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-primary text-primary-foreground'
                      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                  )}
                >
                  <item.icon className="h-5 w-5 flex-shrink-0" />
                  <span className="flex-1">{item.name}</span>
                  {item.badge && (
                    <span
                      className={cn(
                        'rounded-full px-2 py-0.5 text-xs font-medium',
                        isActive
                          ? 'bg-primary-foreground/20 text-primary-foreground'
                          : 'bg-muted text-muted-foreground'
                      )}
                    >
                      {item.badge}
                    </span>
                  )}
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Sidebar footer */}
        <div className="border-t p-4">
          <div className="rounded-md bg-muted p-3">
            <p className="text-xs font-medium text-muted-foreground">Network Status</p>
            <div className="mt-1 flex items-center gap-2">
              <span className="h-2 w-2 rounded-full bg-green-500" />
              <span className="text-sm font-medium">Connected</span>
            </div>
          </div>
        </div>
      </div>
    </aside>
  );
}
