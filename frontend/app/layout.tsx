import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { Toaster } from '@/components/ui/toaster';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Nexus Protocol | DeFi + NFT + Governance Platform',
  description:
    'Stake tokens, mint NFTs, and participate in governance with Nexus Protocol - a comprehensive DeFi platform built on Ethereum.',
  keywords: ['DeFi', 'NFT', 'Staking', 'Governance', 'Ethereum', 'Web3'],
  authors: [{ name: 'Nexus Protocol Team' }],
  openGraph: {
    title: 'Nexus Protocol',
    description: 'DeFi + NFT + Governance Platform',
    type: 'website',
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
        </Providers>
      </body>
    </html>
  );
}
