import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function TokenomicsPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-5xl">
      <div className="mb-8">
        <h1 className="text-3xl font-bold">Tokenomics</h1>
        <p className="text-muted-foreground">
          NEXUS token economics, distribution, and utility
        </p>
      </div>

      {/* Token Overview */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Token Overview</h2>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Token Name</CardDescription>
              <CardTitle>Nexus Token</CardTitle>
            </CardHeader>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Symbol</CardDescription>
              <CardTitle>NXS</CardTitle>
            </CardHeader>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Standard</CardDescription>
              <CardTitle>ERC-20</CardTitle>
            </CardHeader>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Decimals</CardDescription>
              <CardTitle>18</CardTitle>
            </CardHeader>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Max Supply</CardDescription>
              <CardTitle>1,000,000,000</CardTitle>
            </CardHeader>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Initial Supply</CardDescription>
              <CardTitle>0 (Fair Launch)</CardTitle>
            </CardHeader>
          </Card>
        </div>
      </section>

      {/* Token Distribution */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Token Distribution</h2>
        <Card>
          <CardContent className="pt-6">
            <div className="space-y-4">
              <div>
                <div className="flex justify-between mb-1">
                  <span className="font-medium">Community & Ecosystem</span>
                  <span className="text-muted-foreground">40%</span>
                </div>
                <div className="w-full bg-muted rounded-full h-3">
                  <div className="bg-blue-500 h-3 rounded-full" style={{ width: '40%' }}></div>
                </div>
                <p className="text-sm text-muted-foreground mt-1">
                  Staking Rewards (20%), Liquidity Mining (10%), Ecosystem Grants (5%), Airdrops (5%)
                </p>
              </div>

              <div>
                <div className="flex justify-between mb-1">
                  <span className="font-medium">Treasury</span>
                  <span className="text-muted-foreground">20%</span>
                </div>
                <div className="w-full bg-muted rounded-full h-3">
                  <div className="bg-green-500 h-3 rounded-full" style={{ width: '20%' }}></div>
                </div>
                <p className="text-sm text-muted-foreground mt-1">
                  Protocol Development (10%), Security Fund (5%), Insurance Fund (5%)
                </p>
              </div>

              <div>
                <div className="flex justify-between mb-1">
                  <span className="font-medium">Team & Advisors</span>
                  <span className="text-muted-foreground">15%</span>
                </div>
                <div className="w-full bg-purple-500 h-3 rounded-full" style={{ width: '15%' }}></div>
                <p className="text-sm text-muted-foreground mt-1">
                  Core Team (12%), Advisors (3%) - 4-year vesting, 1-year cliff
                </p>
              </div>

              <div>
                <div className="flex justify-between mb-1">
                  <span className="font-medium">Private Sale</span>
                  <span className="text-muted-foreground">15%</span>
                </div>
                <div className="w-full bg-muted rounded-full h-3">
                  <div className="bg-orange-500 h-3 rounded-full" style={{ width: '15%' }}></div>
                </div>
                <p className="text-sm text-muted-foreground mt-1">
                  18-month vesting, 6-month cliff
                </p>
              </div>

              <div>
                <div className="flex justify-between mb-1">
                  <span className="font-medium">Public Sale</span>
                  <span className="text-muted-foreground">10%</span>
                </div>
                <div className="w-full bg-muted rounded-full h-3">
                  <div className="bg-pink-500 h-3 rounded-full" style={{ width: '10%' }}></div>
                </div>
                <p className="text-sm text-muted-foreground mt-1">
                  20% at TGE, 80% over 6 months
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Vesting Schedules */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Vesting Schedules</h2>
        <Card>
          <CardContent className="pt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Allocation</th>
                  <th className="text-left py-2 px-3">Cliff</th>
                  <th className="text-left py-2 px-3">Vesting</th>
                  <th className="text-left py-2 px-3">TGE Unlock</th>
                </tr>
              </thead>
              <tbody className="text-muted-foreground">
                <tr className="border-b">
                  <td className="py-2 px-3">Team</td>
                  <td className="py-2 px-3">12 months</td>
                  <td className="py-2 px-3">48 months</td>
                  <td className="py-2 px-3">0%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Advisors</td>
                  <td className="py-2 px-3">6 months</td>
                  <td className="py-2 px-3">24 months</td>
                  <td className="py-2 px-3">0%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Private Sale</td>
                  <td className="py-2 px-3">6 months</td>
                  <td className="py-2 px-3">18 months</td>
                  <td className="py-2 px-3">0%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Public Sale</td>
                  <td className="py-2 px-3">None</td>
                  <td className="py-2 px-3">6 months</td>
                  <td className="py-2 px-3">20%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Ecosystem</td>
                  <td className="py-2 px-3">None</td>
                  <td className="py-2 px-3">60 months</td>
                  <td className="py-2 px-3">10%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Treasury</td>
                  <td className="py-2 px-3">Governance</td>
                  <td className="py-2 px-3">As needed</td>
                  <td className="py-2 px-3">0%</td>
                </tr>
              </tbody>
            </table>
          </CardContent>
        </Card>
      </section>

      {/* Token Utility */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Token Utility</h2>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Governance</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Vote on proposals</li>
                <li>Create proposals</li>
                <li>Treasury decisions</li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Staking</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Earn rewards</li>
                <li>Delegate votes</li>
                <li>Lock period bonuses</li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Access</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Premium features</li>
                <li>NFT minting</li>
                <li>API access</li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Fee Payment</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Protocol fees</li>
                <li>Gas rebates</li>
                <li>Discounted services</li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Collateral</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Bridge collateral</li>
                <li>Validator bonds</li>
                <li>Insurance coverage</li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Incentives</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Liquidity provision</li>
                <li>Bug bounties</li>
                <li>Referral rewards</li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Fee Structure */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Fee Structure</h2>
        <Card>
          <CardContent className="pt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Action</th>
                  <th className="text-left py-2 px-3">Fee</th>
                  <th className="text-left py-2 px-3">Recipient</th>
                </tr>
              </thead>
              <tbody className="text-muted-foreground">
                <tr className="border-b">
                  <td className="py-2 px-3">NFT Mint</td>
                  <td className="py-2 px-3">0.01 ETH</td>
                  <td className="py-2 px-3">Treasury (50%), Stakers (50%)</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Secondary Sale</td>
                  <td className="py-2 px-3">2.5% royalty</td>
                  <td className="py-2 px-3">Creator (70%), Treasury (30%)</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Airdrop Claim</td>
                  <td className="py-2 px-3">0 NXS</td>
                  <td className="py-2 px-3">N/A</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Governance Proposal</td>
                  <td className="py-2 px-3">1000 NXS</td>
                  <td className="py-2 px-3">Refunded if passed</td>
                </tr>
              </tbody>
            </table>
          </CardContent>
        </Card>

        <Card className="mt-6">
          <CardHeader>
            <CardTitle className="text-lg">Fee Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-4 flex-wrap">
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 bg-blue-500 rounded"></div>
                <span className="text-sm">50% Staking Rewards</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 bg-green-500 rounded"></div>
                <span className="text-sm">40% Treasury</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 bg-red-500 rounded"></div>
                <span className="text-sm">10% Burn</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* NFT Collection */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">NFT Collection</h2>
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Collection Specs</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Max Supply</span>
                  <span>10,000</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Mint Price</span>
                  <span>0.01 ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Royalty</span>
                  <span>5% (EIP-2981)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Max Per Wallet</span>
                  <span>3 (public sale)</span>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Rarity Tiers</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span>
                    <Badge variant="secondary" className="bg-yellow-500/20 text-yellow-600">Legendary</Badge>
                  </span>
                  <span className="text-muted-foreground">100 (1%)</span>
                </div>
                <div className="flex justify-between">
                  <span>
                    <Badge variant="secondary" className="bg-purple-500/20 text-purple-600">Epic</Badge>
                  </span>
                  <span className="text-muted-foreground">400 (4%)</span>
                </div>
                <div className="flex justify-between">
                  <span>
                    <Badge variant="secondary" className="bg-blue-500/20 text-blue-600">Rare</Badge>
                  </span>
                  <span className="text-muted-foreground">1,500 (15%)</span>
                </div>
                <div className="flex justify-between">
                  <span>
                    <Badge variant="secondary">Common</Badge>
                  </span>
                  <span className="text-muted-foreground">8,000 (80%)</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Governance Thresholds */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Governance Thresholds</h2>
        <Card>
          <CardContent className="pt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Action</th>
                  <th className="text-left py-2 px-3">Threshold</th>
                  <th className="text-left py-2 px-3">Quorum</th>
                </tr>
              </thead>
              <tbody className="text-muted-foreground">
                <tr className="border-b">
                  <td className="py-2 px-3">Standard Proposal</td>
                  <td className="py-2 px-3">10,000 NXS</td>
                  <td className="py-2 px-3">4%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Treasury Spend (&lt;$100k)</td>
                  <td className="py-2 px-3">10,000 NXS</td>
                  <td className="py-2 px-3">4%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Treasury Spend (&gt;$100k)</td>
                  <td className="py-2 px-3">100,000 NXS</td>
                  <td className="py-2 px-3">10%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Parameter Change</td>
                  <td className="py-2 px-3">50,000 NXS</td>
                  <td className="py-2 px-3">8%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Emergency Action</td>
                  <td className="py-2 px-3">1,000,000 NXS</td>
                  <td className="py-2 px-3">15%</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Contract Upgrade</td>
                  <td className="py-2 px-3">1,000,000 NXS</td>
                  <td className="py-2 px-3">20%</td>
                </tr>
              </tbody>
            </table>
          </CardContent>
        </Card>
      </section>

      {/* Risk Factors */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Risk Factors</h2>
        <Card className="bg-muted/50">
          <CardContent className="pt-6">
            <ul className="space-y-2 text-sm text-muted-foreground">
              <li><strong>Regulatory Risk:</strong> Token classification uncertainty</li>
              <li><strong>Market Risk:</strong> Crypto market volatility</li>
              <li><strong>Technical Risk:</strong> Smart contract vulnerabilities</li>
              <li><strong>Adoption Risk:</strong> Competition, user acquisition</li>
              <li><strong>Liquidity Risk:</strong> DEX pool depth</li>
            </ul>
            <p className="mt-4 text-sm">
              <strong>Mitigations:</strong> Conservative token release schedule, multi-jurisdictional
              legal review, comprehensive security audits, diversified use cases, and strategic
              liquidity partnerships.
            </p>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
