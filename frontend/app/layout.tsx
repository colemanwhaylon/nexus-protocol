import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { Toaster } from '@/components/ui/toaster';
import { NotificationCenter } from '@/components/features/Notifications';
import { CookieConsentBanner } from '@/components/features/CookieConsent';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Nexus Protocol - Enterprise DeFi + NFT + Security Token Platform',
  description:
    'Enterprise DeFi platform with 23 smart contracts demonstrating institutional-grade security. Tokens: ERC-20 (Snapshots, Votes, Flash Mint), ERC-721A, ERC-1400 security tokens. DeFi: Staking with slashing (875 LOC), streaming rewards (1,076 LOC), vesting. Governance: OpenZeppelin Governor + 48-hour timelock + N-of-M MultiSig. Security: 0 Critical/High findings, 98.5% coverage, Echidna + Certora verification. Stack: Solidity 0.8.24 | Foundry | Go 1.24 | Next.js 14 | PostgreSQL | K8s',
  keywords: ['DeFi', 'NFT', 'Staking', 'Governance', 'ERC-1400', 'Security Tokens', 'Ethereum', 'Smart Contracts', 'Formal Verification', 'Echidna', 'Certora'],
  authors: [{ name: 'AnITConsultant, LLC' }],
  robots: 'index, follow',
  themeColor: '#1a1a2e',
  metadataBase: new URL('https://nexus.dapp.academy'),
  openGraph: {
    title: 'Nexus Protocol - Enterprise DeFi + NFT + Security Token Platform',
    description:
      'Enterprise DeFi platform with 23 smart contracts demonstrating institutional-grade security. Tokens: ERC-20 (Snapshots, Votes, Flash Mint), ERC-721A, ERC-1400 security tokens. DeFi: Staking with slashing (875 LOC), streaming rewards (1,076 LOC), vesting. Governance: OpenZeppelin Governor + 48-hour timelock + N-of-M MultiSig. Security: 0 Critical/High findings, 98.5% coverage, Echidna + Certora verification. Stack: Solidity 0.8.24 | Foundry | Go 1.24 | Next.js 14 | PostgreSQL | K8s',
    type: 'article',
    url: 'https://nexus.dapp.academy',
    siteName: 'Nexus Protocol',
    locale: 'en_US',
    images: [
      {
        url: 'https://nexus.dapp.academy/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Nexus Protocol - Enterprise DeFi + NFT + Security Token Platform',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Nexus Protocol - Enterprise DeFi + NFT + Security Token Platform',
    description:
      'Enterprise DeFi platform with 23 smart contracts demonstrating institutional-grade security. Tokens: ERC-20 (Snapshots, Votes, Flash Mint), ERC-721A, ERC-1400 security tokens. DeFi: Staking with slashing (875 LOC), streaming rewards (1,076 LOC), vesting. Governance: OpenZeppelin Governor + 48-hour timelock + N-of-M MultiSig. Security: 0 Critical/High findings, 98.5% coverage, Echidna + Certora verification. Stack: Solidity 0.8.24 | Foundry | Go 1.24 | Next.js 14 | PostgreSQL | K8s',
    images: ['https://nexus.dapp.academy/og-image.png'],
  },
  other: {
    'article:published_time': '2006-01-01',
    'article:modified_time': '2025-01-12',
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>
          <div className="flex min-h-screen flex-col">
            <Header />
            <main className="flex-1">{children}</main>
            <Footer />
          </div>
          <Toaster />
          <NotificationCenter />
          <CookieConsentBanner />
        </Providers>
      </body>
    </html>
  );
}
