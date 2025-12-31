import Link from 'next/link';
import { ArrowRight, Coins, Image, Vote, Shield } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

const features = [
  {
    title: 'Staking',
    description: 'Stake your NEXUS tokens to earn rewards with up to 20% APY',
    icon: Coins,
    href: '/staking',
    color: 'text-blue-500',
  },
  {
    title: 'NFT Collection',
    description: 'Mint exclusive Nexus Genesis NFTs with staking boost benefits',
    icon: Image,
    href: '/nft',
    color: 'text-purple-500',
  },
  {
    title: 'Governance',
    description: 'Vote on proposals and shape the future of the protocol',
    icon: Vote,
    href: '/governance',
    color: 'text-green-500',
  },
  {
    title: 'Security',
    description: 'Enterprise-grade security with KYC/AML compliance',
    icon: Shield,
    href: '/admin',
    color: 'text-orange-500',
  },
];

export default function Home() {
  return (
    <div className="container py-12">
      {/* Hero Section */}
      <section className="mb-16 text-center">
        <h1 className="mb-4 text-4xl font-bold tracking-tight sm:text-6xl">
          Welcome to{' '}
          <span className="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            Nexus Protocol
          </span>
        </h1>
        <p className="mx-auto mb-8 max-w-2xl text-lg text-muted-foreground">
          A comprehensive DeFi platform combining staking, NFTs, and decentralized governance.
          Built for the future of finance.
        </p>
        <div className="flex justify-center gap-4">
          <Button size="lg" asChild>
            <Link href="/staking">
              Start Staking <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
          <Button size="lg" variant="outline" asChild>
            <Link href="/governance">View Proposals</Link>
          </Button>
        </div>
      </section>

      {/* Stats Section */}
      <section className="mb-16 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Total Value Locked</CardDescription>
            <CardTitle className="text-3xl">$0.00</CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Staking APY</CardDescription>
            <CardTitle className="text-3xl">20%</CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardDescription>NFTs Minted</CardDescription>
            <CardTitle className="text-3xl">0 / 10,000</CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Active Proposals</CardDescription>
            <CardTitle className="text-3xl">0</CardTitle>
          </CardHeader>
        </Card>
      </section>

      {/* Features Section */}
      <section>
        <h2 className="mb-8 text-center text-3xl font-bold">Explore the Platform</h2>
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((feature) => (
            <Card key={feature.title} className="transition-shadow hover:shadow-lg">
              <CardHeader>
                <feature.icon className={`h-10 w-10 ${feature.color}`} />
                <CardTitle className="mt-4">{feature.title}</CardTitle>
                <CardDescription>{feature.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <Button variant="ghost" className="w-full" asChild>
                  <Link href={feature.href}>
                    Explore <ArrowRight className="ml-2 h-4 w-4" />
                  </Link>
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
}
