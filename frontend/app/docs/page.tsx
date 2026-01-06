import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import Link from "next/link";
import { BookOpen, Coins, Shield, Vote, Layers, Server, Lock, Code } from "lucide-react";

const docSections = [
  {
    title: "Getting Started",
    description: "Learn the basics of Nexus Protocol",
    icon: BookOpen,
    links: [
      { name: "What is Nexus Protocol?", href: "#overview" },
      { name: "Connect Your Wallet", href: "#connect" },
      { name: "Get Testnet Tokens", href: "#faucet" },
    ],
  },
  {
    title: "Staking",
    description: "Stake tokens and earn rewards",
    icon: Coins,
    links: [
      { name: "How Staking Works", href: "#staking-overview" },
      { name: "Delegation", href: "#delegation" },
      { name: "Unbonding Period", href: "#unbonding" },
    ],
  },
  {
    title: "Governance",
    description: "Participate in protocol decisions",
    icon: Vote,
    links: [
      { name: "Creating Proposals", href: "#proposals" },
      { name: "Voting Process", href: "#voting" },
      { name: "Execution & Timelock", href: "#timelock" },
    ],
  },
  {
    title: "NFT Collection",
    description: "Mint and manage NFTs",
    icon: Layers,
    links: [
      { name: "Minting NFTs", href: "#minting" },
      { name: "NFT Metadata", href: "#metadata" },
      { name: "Gallery", href: "#gallery" },
    ],
  },
  {
    title: "Security",
    description: "Security measures and audits",
    icon: Shield,
    links: [
      { name: "Smart Contract Security", href: "/security" },
      { name: "Access Control", href: "#access-control" },
      { name: "Emergency Procedures", href: "#emergency" },
    ],
  },
  {
    title: "Technical",
    description: "Developer resources",
    icon: Code,
    links: [
      { name: "Smart Contracts", href: "#contracts" },
      { name: "API Reference", href: "#api" },
      { name: "GitHub Repository", href: "https://github.com/colemanwhaylon/nexus-protocol" },
    ],
  },
];

export default function DocsPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Documentation</h1>
        <p className="text-muted-foreground">
          Learn how to use Nexus Protocol
        </p>
      </div>

      {/* Quick Links */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-12">
        {docSections.map((section) => (
          <Card key={section.title} className="hover:shadow-lg transition-shadow">
            <CardHeader>
              <section.icon className="h-8 w-8 text-primary mb-2" />
              <CardTitle>{section.title}</CardTitle>
              <CardDescription>{section.description}</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2">
                {section.links.map((link) => (
                  <li key={link.name}>
                    <Link
                      href={link.href}
                      className="text-sm text-muted-foreground hover:text-primary transition-colors"
                      target={link.href.startsWith("http") ? "_blank" : undefined}
                      rel={link.href.startsWith("http") ? "noopener noreferrer" : undefined}
                    >
                      {link.name}
                    </Link>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Overview Section */}
      <section id="overview" className="mb-12">
        <h2 className="text-2xl font-bold mb-4">What is Nexus Protocol?</h2>
        <Card>
          <CardContent className="pt-6 prose dark:prose-invert max-w-none">
            <p>
              Nexus Protocol is a comprehensive DeFi platform combining staking, NFTs, and decentralized
              governance. Built for the future of finance, it provides enterprise-grade security with
              KYC/AML compliance capabilities.
            </p>
            <h3>Key Features</h3>
            <ul>
              <li><strong>Staking</strong>: Stake NEXUS tokens to earn rewards and participate in governance</li>
              <li><strong>NFT Collection</strong>: Mint exclusive Nexus Genesis NFTs</li>
              <li><strong>Governance</strong>: Vote on proposals and shape the protocol&apos;s future</li>
              <li><strong>Security</strong>: Enterprise-grade security with multi-sig and timelock controls</li>
            </ul>
          </CardContent>
        </Card>
      </section>

      {/* Architecture Section */}
      <section id="architecture" className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Architecture Overview</h2>
        <Card>
          <CardContent className="pt-6">
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <h3 className="font-semibold mb-2">Smart Contracts</h3>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>NexusToken (ERC-20 with governance)</li>
                  <li>NexusNFT (ERC-721A)</li>
                  <li>NexusStaking (stake/delegate)</li>
                  <li>NexusGovernor (OpenZeppelin Governor)</li>
                  <li>NexusTimelock (48-hour delay)</li>
                  <li>NexusKYCRegistry (compliance)</li>
                </ul>
              </div>
              <div>
                <h3 className="font-semibold mb-2">Technology Stack</h3>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>Solidity 0.8.24 / Foundry</li>
                  <li>Next.js 14 / React</li>
                  <li>wagmi / viem</li>
                  <li>Go API Backend</li>
                  <li>PostgreSQL / Redis</li>
                </ul>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Staking Section */}
      <section id="staking-overview" className="mb-12">
        <h2 className="text-2xl font-bold mb-4">How Staking Works</h2>
        <Card>
          <CardContent className="pt-6 prose dark:prose-invert max-w-none">
            <p>
              Staking NEXUS tokens allows you to earn rewards and participate in protocol governance.
              When you stake, your tokens are locked in the staking contract.
            </p>
            <h3 id="delegation">Delegation</h3>
            <p>
              You can delegate your voting power to another address while keeping your tokens staked.
              This is useful if you want someone else to vote on your behalf.
            </p>
            <h3 id="unbonding">Unbonding Period</h3>
            <p>
              When you unstake tokens, there is a 7-day unbonding period before you can withdraw them.
              This helps ensure protocol stability and prevents governance attacks.
            </p>
          </CardContent>
        </Card>
      </section>

      {/* Governance Section */}
      <section id="proposals" className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Governance</h2>
        <Card>
          <CardContent className="pt-6 prose dark:prose-invert max-w-none">
            <h3>Creating Proposals</h3>
            <p>
              Any token holder with sufficient voting power can create governance proposals.
              Proposals can include actions like updating protocol parameters, spending treasury funds,
              or upgrading contracts.
            </p>
            <h3 id="voting">Voting Process</h3>
            <ul>
              <li>Voting delay: 1 block after proposal creation</li>
              <li>Voting period: ~20 minutes (100 blocks on testnet)</li>
              <li>Quorum required: 4% of total supply</li>
            </ul>
            <h3 id="timelock">Execution & Timelock</h3>
            <p>
              Passed proposals enter a timelock period (60 seconds on testnet, 48 hours on mainnet)
              before they can be executed. This gives the community time to review and react to
              approved changes.
            </p>
          </CardContent>
        </Card>
      </section>

      {/* Contracts Section */}
      <section id="contracts" className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Smart Contracts</h2>
        <Card>
          <CardContent className="pt-6">
            <p className="text-muted-foreground mb-4">
              All contracts are deployed on Ethereum Sepolia testnet and verified on Etherscan.
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2">Contract</th>
                    <th className="text-left py-2">Purpose</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b">
                    <td className="py-2">NexusToken</td>
                    <td className="py-2">ERC-20 governance token with voting</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2">NexusNFT</td>
                    <td className="py-2">ERC-721A NFT collection</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2">NexusStaking</td>
                    <td className="py-2">Staking and delegation</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2">NexusGovernor</td>
                    <td className="py-2">Proposal and voting management</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2">NexusTimelock</td>
                    <td className="py-2">Delayed execution of proposals</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2">NexusKYCRegistry</td>
                    <td className="py-2">Whitelist/blacklist management</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Links */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Additional Resources</h2>
        <div className="grid gap-4 md:grid-cols-3">
          <Link href="/whitepaper">
            <Card className="hover:shadow-lg transition-shadow cursor-pointer h-full">
              <CardHeader>
                <CardTitle className="text-lg">Whitepaper</CardTitle>
                <CardDescription>Technical overview of the protocol</CardDescription>
              </CardHeader>
            </Card>
          </Link>
          <Link href="/tokenomics">
            <Card className="hover:shadow-lg transition-shadow cursor-pointer h-full">
              <CardHeader>
                <CardTitle className="text-lg">Tokenomics</CardTitle>
                <CardDescription>Token distribution and economics</CardDescription>
              </CardHeader>
            </Card>
          </Link>
          <Link href="/security">
            <Card className="hover:shadow-lg transition-shadow cursor-pointer h-full">
              <CardHeader>
                <CardTitle className="text-lg">Security</CardTitle>
                <CardDescription>Audit reports and security measures</CardDescription>
              </CardHeader>
            </Card>
          </Link>
        </div>
      </section>
    </div>
  );
}
