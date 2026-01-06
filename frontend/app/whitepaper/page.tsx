import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function WhitepaperPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <h1 className="text-3xl font-bold">Nexus Protocol Whitepaper</h1>
          <Badge variant="outline">v1.0</Badge>
        </div>
        <p className="text-muted-foreground">
          A Comprehensive DeFi Platform for Staking, NFTs, and Decentralized Governance
        </p>
      </div>

      <div className="prose dark:prose-invert max-w-none">
        {/* Abstract */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle>Abstract</CardTitle>
          </CardHeader>
          <CardContent>
            <p>
              Nexus Protocol is a modular, enterprise-grade blockchain platform designed for security,
              scalability, and regulatory compliance. The protocol combines staking mechanisms, NFT
              collections, and decentralized governance into a unified ecosystem powered by the NEXUS
              token (NXS).
            </p>
            <p>
              This whitepaper outlines the technical architecture, tokenomics, governance model, and
              security measures that make Nexus Protocol suitable for both retail users and
              institutional participants.
            </p>
          </CardContent>
        </Card>

        {/* Introduction */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">1. Introduction</h2>
          <p>
            The decentralized finance (DeFi) ecosystem has grown exponentially, yet many protocols
            struggle to balance security, usability, and regulatory compliance. Nexus Protocol
            addresses these challenges through a layered architecture that separates concerns while
            maintaining interoperability.
          </p>
          <h3 className="text-xl font-semibold mt-6 mb-3">1.1 Vision</h3>
          <p>
            To create a comprehensive DeFi platform that demonstrates production-grade smart contract
            security, blockchain infrastructure, and full-stack development capabilities while
            remaining accessible to all participants.
          </p>
          <h3 className="text-xl font-semibold mt-6 mb-3">1.2 Key Objectives</h3>
          <ul className="list-disc pl-6 space-y-2">
            <li>Provide secure staking with transparent reward mechanisms</li>
            <li>Enable decentralized governance with proper checks and balances</li>
            <li>Offer NFT functionality with enterprise features</li>
            <li>Maintain regulatory compliance through KYC/AML integration</li>
            <li>Ensure upgradeability without sacrificing security</li>
          </ul>
        </section>

        {/* Architecture */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">2. Technical Architecture</h2>
          <h3 className="text-xl font-semibold mt-6 mb-3">2.1 Smart Contract Suite</h3>
          <p>
            The protocol consists of modular smart contracts built on Solidity 0.8.24, leveraging
            OpenZeppelin&apos;s battle-tested libraries for security-critical components.
          </p>
          <div className="my-6 overflow-x-auto">
            <table className="w-full text-sm border-collapse">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Contract</th>
                  <th className="text-left py-2 px-3">Purpose</th>
                  <th className="text-left py-2 px-3">Standard</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-b">
                  <td className="py-2 px-3">NexusToken</td>
                  <td className="py-2 px-3">Governance and utility token</td>
                  <td className="py-2 px-3">ERC-20 + Votes</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">NexusNFT</td>
                  <td className="py-2 px-3">Membership NFT collection</td>
                  <td className="py-2 px-3">ERC-721A</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">NexusStaking</td>
                  <td className="py-2 px-3">Token staking and delegation</td>
                  <td className="py-2 px-3">Custom</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">NexusGovernor</td>
                  <td className="py-2 px-3">Proposal and voting</td>
                  <td className="py-2 px-3">OZ Governor</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">NexusTimelock</td>
                  <td className="py-2 px-3">Delayed execution</td>
                  <td className="py-2 px-3">OZ Timelock</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">NexusKYCRegistry</td>
                  <td className="py-2 px-3">Compliance management</td>
                  <td className="py-2 px-3">Custom</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h3 className="text-xl font-semibold mt-6 mb-3">2.2 Multi-Chain Support</h3>
          <p>
            While currently deployed on Ethereum Sepolia testnet, the architecture supports deployment
            across multiple EVM-compatible chains including Arbitrum, Polygon, Base, and Optimism.
          </p>
        </section>

        {/* Tokenomics Summary */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">3. Tokenomics</h2>
          <p>
            The NEXUS token (NXS) serves as the primary governance and utility token within the ecosystem.
          </p>
          <Card className="my-6">
            <CardContent className="pt-6">
              <div className="grid gap-4 md:grid-cols-2">
                <div>
                  <h4 className="font-semibold mb-2">Token Specifications</h4>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>Symbol: NXS</li>
                    <li>Standard: ERC-20</li>
                    <li>Decimals: 18</li>
                    <li>Max Supply: 1,000,000,000</li>
                  </ul>
                </div>
                <div>
                  <h4 className="font-semibold mb-2">Distribution</h4>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>Community & Ecosystem: 40%</li>
                    <li>Treasury: 20%</li>
                    <li>Team & Advisors: 15%</li>
                    <li>Private Sale: 15%</li>
                    <li>Public Sale: 10%</li>
                  </ul>
                </div>
              </div>
            </CardContent>
          </Card>
          <p>
            For detailed tokenomics including vesting schedules, emission curves, and utility breakdown,
            see the <a href="/tokenomics" className="text-primary hover:underline">Tokenomics page</a>.
          </p>
        </section>

        {/* Governance */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">4. Governance Model</h2>
          <p>
            Nexus Protocol implements a decentralized governance model using OpenZeppelin&apos;s Governor
            pattern with modifications for enhanced security.
          </p>
          <h3 className="text-xl font-semibold mt-6 mb-3">4.1 Voting Power</h3>
          <p>
            Voting power is derived from staked NEXUS tokens. Token holders must delegate their votes
            (to themselves or others) to participate in governance.
          </p>
          <h3 className="text-xl font-semibold mt-6 mb-3">4.2 Proposal Lifecycle</h3>
          <ol className="list-decimal pl-6 space-y-2">
            <li><strong>Creation</strong>: Any holder with sufficient tokens can propose</li>
            <li><strong>Voting Delay</strong>: Brief period before voting begins</li>
            <li><strong>Voting Period</strong>: Token holders cast votes</li>
            <li><strong>Timelock</strong>: Approved proposals wait before execution</li>
            <li><strong>Execution</strong>: Proposal actions are executed on-chain</li>
          </ol>
          <h3 className="text-xl font-semibold mt-6 mb-3">4.3 Safety Mechanisms</h3>
          <ul className="list-disc pl-6 space-y-2">
            <li>48-hour timelock delay for mainnet (60s testnet)</li>
            <li>Quorum requirements prevent minority attacks</li>
            <li>Emergency pause capabilities for critical situations</li>
            <li>Multi-sig controls for treasury operations</li>
          </ul>
        </section>

        {/* Security */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">5. Security</h2>
          <p>
            Security is a core principle of Nexus Protocol, implemented through multiple layers:
          </p>
          <h3 className="text-xl font-semibold mt-6 mb-3">5.1 Smart Contract Security</h3>
          <ul className="list-disc pl-6 space-y-2">
            <li>OpenZeppelin battle-tested contracts</li>
            <li>Reentrancy guards on all external calls</li>
            <li>Role-based access control (RBAC)</li>
            <li>Upgradeable contracts with UUPS pattern</li>
          </ul>
          <h3 className="text-xl font-semibold mt-6 mb-3">5.2 Testing & Verification</h3>
          <ul className="list-disc pl-6 space-y-2">
            <li>Comprehensive unit tests with Foundry</li>
            <li>Fuzz testing with Echidna</li>
            <li>Static analysis with Slither</li>
            <li>Formal verification with Certora</li>
          </ul>
          <p className="mt-4">
            For full audit details, see the <a href="/security" className="text-primary hover:underline">Security page</a>.
          </p>
        </section>

        {/* Compliance */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">6. Compliance</h2>
          <p>
            Nexus Protocol includes enterprise-grade compliance features:
          </p>
          <ul className="list-disc pl-6 space-y-2">
            <li><strong>KYC Registry</strong>: On-chain whitelist/blacklist management</li>
            <li><strong>Transfer Restrictions</strong>: Jurisdiction-based controls</li>
            <li><strong>Audit Trails</strong>: Comprehensive event logging</li>
            <li><strong>GDPR Compliance</strong>: Privacy-focused data handling</li>
          </ul>
        </section>

        {/* Roadmap */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">7. Roadmap</h2>
          <div className="space-y-4">
            <Card>
              <CardContent className="pt-6">
                <div className="flex items-center gap-3 mb-2">
                  <Badge>Phase 1</Badge>
                  <span className="font-semibold">Foundation</span>
                </div>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>Core contract development and testing</li>
                  <li>Frontend dApp development</li>
                  <li>Testnet deployment and testing</li>
                </ul>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="pt-6">
                <div className="flex items-center gap-3 mb-2">
                  <Badge variant="outline">Phase 2</Badge>
                  <span className="font-semibold">Expansion</span>
                </div>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>Mainnet deployment</li>
                  <li>Third-party security audits</li>
                  <li>Multi-chain expansion</li>
                </ul>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="pt-6">
                <div className="flex items-center gap-3 mb-2">
                  <Badge variant="outline">Phase 3</Badge>
                  <span className="font-semibold">Growth</span>
                </div>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>Advanced DeFi features</li>
                  <li>Cross-chain bridging</li>
                  <li>Institutional partnerships</li>
                </ul>
              </CardContent>
            </Card>
          </div>
        </section>

        {/* Conclusion */}
        <section className="mb-8">
          <h2 className="text-2xl font-bold mb-4">8. Conclusion</h2>
          <p>
            Nexus Protocol represents a comprehensive approach to building DeFi infrastructure that
            prioritizes security, compliance, and user experience. By leveraging proven technologies
            and implementing defense-in-depth strategies, the protocol provides a solid foundation
            for decentralized finance applications.
          </p>
        </section>

        {/* Disclaimer */}
        <Card className="bg-muted/50">
          <CardContent className="pt-6">
            <p className="text-sm text-muted-foreground">
              <strong>Disclaimer:</strong> This whitepaper is for informational purposes only and does
              not constitute financial advice. Participation in DeFi protocols carries inherent risks.
              Please conduct your own research before interacting with any smart contracts.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
