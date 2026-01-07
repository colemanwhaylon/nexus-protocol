'use client';

import Link from 'next/link';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  Shield,
  Code,
  Server,
  Lock,
  Building2,
  GitBranch,
  ExternalLink,
  Mail,
  Github,
  CheckCircle2
} from 'lucide-react';

const skillCategories = [
  {
    title: 'Smart Contract Security',
    icon: Shield,
    skills: [
      { name: 'Foundry/Hardhat proficiency', covered: true, target: 'TechChain/Eigen' },
      { name: 'Fuzz testing (Echidna/Medusa)', covered: true, target: 'TechChain/Eigen' },
      { name: 'Formal verification (Certora/Halmos)', covered: true, target: 'TechChain/Eigen' },
      { name: 'Static analysis (Slither)', covered: true, target: 'TechChain/Eigen' },
      { name: 'Custom security detectors', covered: true, target: 'TechChain/Eigen' },
      { name: 'Staking/Slashing contracts', covered: true, target: 'TechChain/Eigen' },
      { name: 'Reward distribution mechanisms', covered: true, target: 'TechChain/Eigen' },
      { name: 'Gas optimization patterns', covered: true, target: 'All Roles' },
    ],
  },
  {
    title: 'Blockchain Infrastructure',
    icon: Server,
    skills: [
      { name: 'EVM deep knowledge', covered: true, target: 'All Roles' },
      { name: 'ERC-20 implementation', covered: true, target: 'All Roles' },
      { name: 'ERC-721/721A implementation', covered: true, target: 'Morgan Stanley' },
      { name: 'ERC-1400 (Security Tokens)', covered: true, target: 'Morgan Stanley' },
      { name: 'Multi-sig wallet', covered: true, target: 'All Roles' },
      { name: 'Timelock/Governance', covered: true, target: 'All Roles' },
      { name: 'Upgradeable contracts (UUPS/Proxy)', covered: true, target: 'Morgan Stanley' },
      { name: 'Oracle integration (Chainlink)', covered: true, target: 'Morgan Stanley' },
    ],
  },
  {
    title: 'Wallet & Key Management',
    icon: Lock,
    skills: [
      { name: 'Custodial wallet patterns', covered: true, target: 'Morgan Stanley' },
      { name: 'Secure key management (HSM patterns)', covered: true, target: 'Morgan Stanley' },
      { name: 'Non-custodial wallet integration', covered: true, target: 'All Roles' },
      { name: 'Meta-transactions (ERC-2771)', covered: true, target: 'All Roles' },
      { name: 'Secure signing implementations', covered: true, target: 'Morgan Stanley' },
    ],
  },
  {
    title: 'Enterprise & Compliance',
    icon: Building2,
    skills: [
      { name: 'RBAC (Role-based access)', covered: true, target: 'All Roles' },
      { name: 'KYC/AML whitelist', covered: true, target: 'Morgan Stanley' },
      { name: 'Audit trail/Event logging', covered: true, target: 'All Roles' },
      { name: 'DvP (Delivery vs Payment)', covered: true, target: 'Morgan Stanley' },
      { name: 'Regulatory compliance docs', covered: true, target: 'Morgan Stanley' },
      { name: 'Circuit breaker/Emergency pause', covered: true, target: 'All Roles' },
    ],
  },
  {
    title: 'Backend & Infrastructure',
    icon: Code,
    skills: [
      { name: 'Go backend development', covered: true, target: 'Morgan Stanley' },
      { name: 'Python scripting', covered: true, target: 'All Roles' },
      { name: 'Rust (for tooling)', covered: true, target: 'Morgan Stanley' },
      { name: 'Cloud deployment (AWS/GCP/Azure)', covered: true, target: 'Morgan Stanley' },
      { name: 'Docker/Kubernetes', covered: true, target: 'All Roles' },
      { name: 'CI/CD pipelines', covered: true, target: 'All Roles' },
      { name: 'Monitoring/Alerting', covered: true, target: 'All Roles' },
    ],
  },
  {
    title: 'Security Process',
    icon: GitBranch,
    skills: [
      { name: 'Threat modeling', covered: true, target: 'All Roles' },
      { name: 'Self-audit report', covered: true, target: 'TechChain/Eigen' },
      { name: 'Incident response plan', covered: true, target: 'All Roles' },
      { name: 'Tokenomics design', covered: true, target: 'All Roles' },
      { name: 'NFT metadata/IPFS', covered: true, target: 'All Roles' },
      { name: 'Airdrop mechanics', covered: true, target: 'All Roles' },
    ],
  },
];

const projectDemos = [
  {
    name: 'Nexus Protocol',
    url: 'https://nexus.dapp.academy/',
    description: 'Comprehensive DeFi, NFT, and enterprise tokenization platform',
    features: ['ERC-20/721A/1400', 'Staking', 'Governance', 'KYC Integration'],
  },
  {
    name: 'Decentralized IP Registry',
    url: 'https://dip.dapp.academy/',
    description: 'Blockchain-based intellectual property registration',
    features: ['On-chain timestamps', 'Ownership proof', 'Copyright protection'],
  },
  {
    name: 'PharmaChain',
    url: 'https://pharmachain.dapp.academy/',
    description: 'Supply chain traceability for pharmaceuticals',
    features: ['Regulatory compliance', 'Provenance tracking', 'Anti-counterfeit'],
  },
];

const featureLocations = [
  {
    feature: 'Token Standards Expertise',
    description: 'ERC-20 with governance, ERC-721A for NFTs, ERC-1400 for security tokens',
    files: [
      { name: 'NexusToken.sol', path: 'contracts/src/core/NexusToken.sol' },
      { name: 'NexusNFT.sol', path: 'contracts/src/core/NexusNFT.sol' },
      { name: 'NexusSecurityToken.sol', path: 'contracts/src/core/NexusSecurityToken.sol' },
    ],
  },
  {
    feature: 'Custodial Infrastructure',
    description: 'Multi-sig wallets, key management, meta-transactions',
    files: [
      { name: 'NexusMultiSig.sol', path: 'contracts/src/governance/NexusMultiSig.sol' },
      { name: 'relayer.go', path: 'backend/internal/handlers/relayer.go' },
    ],
  },
  {
    feature: 'DvP Settlement Patterns',
    description: 'Atomic cross-chain transfers, lock/mint patterns',
    files: [
      { name: 'NexusBridge.sol', path: 'contracts/src/bridge/NexusBridge.sol' },
    ],
  },
  {
    feature: 'Governance Systems',
    description: 'OpenZeppelin Governor, timelock, configurable voting',
    files: [
      { name: 'NexusGovernor.sol', path: 'contracts/src/governance/NexusGovernor.sol' },
      { name: 'NexusTimelock.sol', path: 'contracts/src/governance/NexusTimelock.sol' },
    ],
  },
];

export default function AboutPage() {
  return (
    <div className="container py-12">
      {/* Hero Section */}
      <div className="mx-auto max-w-4xl text-center mb-16">
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl mb-6">
          About the Developer
        </h1>
        <p className="text-xl text-muted-foreground mb-8">
          Building enterprise-grade blockchain infrastructure with over a decade of software engineering experience
          and progressive leadership across distributed teams.
        </p>
        <div className="flex justify-center gap-4">
          <a
            href="https://github.com/colemanwhaylon/nexus-protocol"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            <Github className="h-5 w-5" />
            View on GitHub
          </a>
          <a
            href="mailto:colemanwhaylon@yahoo.com"
            className="inline-flex items-center gap-2 px-6 py-3 border border-primary text-primary rounded-lg hover:bg-primary/10 transition-colors"
          >
            <Mail className="h-5 w-5" />
            Contact
          </a>
        </div>
      </div>

      {/* Project Portfolio */}
      <section className="mb-16">
        <h2 className="text-3xl font-bold mb-8 text-center">Project Portfolio</h2>
        <div className="grid gap-6 md:grid-cols-3">
          {projectDemos.map((project) => (
            <Card key={project.name} className="hover:shadow-lg transition-shadow">
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  {project.name}
                  <a
                    href={project.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary hover:text-primary/80"
                  >
                    <ExternalLink className="h-5 w-5" />
                  </a>
                </CardTitle>
                <CardDescription>{project.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-2">
                  {project.features.map((feature) => (
                    <Badge key={feature} variant="secondary">
                      {feature}
                    </Badge>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Feature Demonstration Locations */}
      <section className="mb-16">
        <h2 className="text-3xl font-bold mb-8 text-center">Feature Implementation Details</h2>
        <div className="grid gap-6 md:grid-cols-2">
          {featureLocations.map((item) => (
            <Card key={item.feature}>
              <CardHeader>
                <CardTitle className="text-lg">{item.feature}</CardTitle>
                <CardDescription>{item.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {item.files.map((file) => (
                    <div key={file.path} className="flex items-center gap-2 text-sm">
                      <CheckCircle2 className="h-4 w-4 text-green-500" />
                      <code className="bg-muted px-2 py-1 rounded text-xs">{file.path}</code>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Skills Matrix */}
      <section className="mb-16">
        <h2 className="text-3xl font-bold mb-4 text-center">46 Demonstrated Skills</h2>
        <p className="text-center text-muted-foreground mb-8">
          Comprehensive coverage across smart contract security, blockchain infrastructure, and enterprise compliance
        </p>
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {skillCategories.map((category) => (
            <Card key={category.title}>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <category.icon className="h-5 w-5 text-primary" />
                  {category.title}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  {category.skills.map((skill) => (
                    <li key={skill.name} className="flex items-start gap-2 text-sm">
                      <CheckCircle2 className="h-4 w-4 text-green-500 mt-0.5 shrink-0" />
                      <span>{skill.name}</span>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Technical Stack */}
      <section className="mb-16">
        <h2 className="text-3xl font-bold mb-8 text-center">Technical Stack</h2>
        <div className="overflow-x-auto">
          <table className="w-full border-collapse">
            <thead>
              <tr className="border-b">
                <th className="text-left py-3 px-4 font-semibold">Domain</th>
                <th className="text-left py-3 px-4 font-semibold">Capabilities</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Blockchain Architecture</td>
                <td className="py-3 px-4 text-muted-foreground">Consensus algorithms, cryptographic primitives, EVM internals, L1/L2 protocols</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Smart Contracts</td>
                <td className="py-3 px-4 text-muted-foreground">Solidity, Foundry, OpenZeppelin, ERC standards (20, 721, 1400)</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Languages</td>
                <td className="py-3 px-4 text-muted-foreground">Go (backend), Rust (tooling), Python (scripting), Solidity</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Security</td>
                <td className="py-3 px-4 text-muted-foreground">Formal verification (Certora), fuzzing (Echidna), static analysis (Slither)</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Wallet Infrastructure</td>
                <td className="py-3 px-4 text-muted-foreground">Custodial/non-custodial patterns, key management, secure signing</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Enterprise</td>
                <td className="py-3 px-4 text-muted-foreground">RBAC, KYC/AML, audit trails, incident response planning</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Infrastructure</td>
                <td className="py-3 px-4 text-muted-foreground">Docker, Kubernetes, Terraform, CI/CD, AWS/GCP/Azure</td>
              </tr>
              <tr className="border-b">
                <td className="py-3 px-4 font-medium">Compliance</td>
                <td className="py-3 px-4 text-muted-foreground">Tokenized securities, DvP workflows, on/off-chain settlement</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      {/* Contact */}
      <section className="text-center">
        <Card className="max-w-2xl mx-auto">
          <CardHeader>
            <CardTitle>Get in Touch</CardTitle>
            <CardDescription>
              Interested in collaboration or have questions about the project?
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center gap-6">
            <a
              href="https://github.com/colemanwhaylon/nexus-protocol"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
            >
              <Github className="h-5 w-5" />
              GitHub
            </a>
            <a
              href="mailto:colemanwhaylon@yahoo.com"
              className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
            >
              <Mail className="h-5 w-5" />
              colemanwhaylon@yahoo.com
            </a>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
