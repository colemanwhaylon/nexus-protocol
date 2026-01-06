import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Shield, CheckCircle, AlertTriangle, Lock, Eye, Zap } from "lucide-react";
import Link from "next/link";

export default function SecurityPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-5xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Shield className="h-8 w-8 text-primary" />
          <h1 className="text-3xl font-bold">Security</h1>
        </div>
        <p className="text-muted-foreground">
          Audit reports, security measures, and best practices
        </p>
      </div>

      {/* Security Overview */}
      <section className="mb-12">
        <div className="grid gap-4 md:grid-cols-4">
          <Card className="border-green-500/50 bg-green-500/5">
            <CardHeader className="pb-2">
              <CardDescription>Critical Issues</CardDescription>
              <CardTitle className="text-3xl text-green-600">0</CardTitle>
            </CardHeader>
          </Card>
          <Card className="border-green-500/50 bg-green-500/5">
            <CardHeader className="pb-2">
              <CardDescription>High Issues</CardDescription>
              <CardTitle className="text-3xl text-green-600">0</CardTitle>
            </CardHeader>
          </Card>
          <Card className="border-yellow-500/50 bg-yellow-500/5">
            <CardHeader className="pb-2">
              <CardDescription>Medium Issues</CardDescription>
              <CardTitle className="text-3xl text-yellow-600">2 Fixed</CardTitle>
            </CardHeader>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardDescription>Test Coverage</CardDescription>
              <CardTitle className="text-3xl">98.5%</CardTitle>
            </CardHeader>
          </Card>
        </div>
      </section>

      {/* Audit Summary */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Audit Summary</h2>
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>Internal Security Audit</CardTitle>
                <CardDescription>Trail of Bits Format - December 2024</CardDescription>
              </div>
              <Badge variant="outline" className="bg-green-500/10 text-green-600 border-green-500">
                All Issues Resolved
              </Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2 px-3">Severity</th>
                    <th className="text-left py-2 px-3">Count</th>
                    <th className="text-left py-2 px-3">Fixed</th>
                    <th className="text-left py-2 px-3">Acknowledged</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b">
                    <td className="py-2 px-3"><Badge variant="destructive">Critical</Badge></td>
                    <td className="py-2 px-3">0</td>
                    <td className="py-2 px-3">-</td>
                    <td className="py-2 px-3">-</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3"><Badge variant="destructive" className="bg-orange-500">High</Badge></td>
                    <td className="py-2 px-3">0</td>
                    <td className="py-2 px-3">-</td>
                    <td className="py-2 px-3">-</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3"><Badge variant="outline" className="border-yellow-500 text-yellow-600">Medium</Badge></td>
                    <td className="py-2 px-3">2</td>
                    <td className="py-2 px-3">2</td>
                    <td className="py-2 px-3">0</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3"><Badge variant="outline">Low</Badge></td>
                    <td className="py-2 px-3">5</td>
                    <td className="py-2 px-3">4</td>
                    <td className="py-2 px-3">1</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3"><Badge variant="secondary">Informational</Badge></td>
                    <td className="py-2 px-3">8</td>
                    <td className="py-2 px-3">6</td>
                    <td className="py-2 px-3">2</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Contracts in Scope */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Audited Contracts</h2>
        <Card>
          <CardContent className="pt-6">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2 px-3">Contract</th>
                    <th className="text-left py-2 px-3">LOC</th>
                    <th className="text-left py-2 px-3">Complexity</th>
                    <th className="text-left py-2 px-3">Status</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusToken.sol</td>
                    <td className="py-2 px-3">~250</td>
                    <td className="py-2 px-3">Medium</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusNFT.sol</td>
                    <td className="py-2 px-3">~300</td>
                    <td className="py-2 px-3">Medium</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusStaking.sol</td>
                    <td className="py-2 px-3">~350</td>
                    <td className="py-2 px-3">High</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">RewardsDistributor.sol</td>
                    <td className="py-2 px-3">~300</td>
                    <td className="py-2 px-3">High</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusGovernor.sol</td>
                    <td className="py-2 px-3">~300</td>
                    <td className="py-2 px-3">High</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusTimelock.sol</td>
                    <td className="py-2 px-3">~200</td>
                    <td className="py-2 px-3">Medium</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusAccessControl.sol</td>
                    <td className="py-2 px-3">~150</td>
                    <td className="py-2 px-3">Low</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusKYCRegistry.sol</td>
                    <td className="py-2 px-3">~200</td>
                    <td className="py-2 px-3">Medium</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">NexusEmergency.sol</td>
                    <td className="py-2 px-3">~150</td>
                    <td className="py-2 px-3">Medium</td>
                    <td className="py-2 px-3"><CheckCircle className="h-4 w-4 text-green-500" /></td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p className="text-sm text-muted-foreground mt-4">
              Total: ~3,500 lines of Solidity code
            </p>
          </CardContent>
        </Card>
      </section>

      {/* Security Tools */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Security Tools & Methodology</h2>
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Eye className="h-5 w-5" />
                Static Analysis
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Slither v0.10.0
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Aderyn v0.1.0
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Mythril v0.24.0
                </li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Zap className="h-5 w-5" />
                Fuzzing
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Echidna v2.2.0 (10,000+ runs)
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Foundry Fuzz (100,000 runs)
                </li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Lock className="h-5 w-5" />
                Formal Verification
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Certora Prover v5.0
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  All invariants verified
                </li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Shield className="h-5 w-5" />
                Manual Review
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Line-by-line code review
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Business logic validation
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  Access control verification
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Fixed Issues */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Notable Findings (Fixed)</h2>
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="border-yellow-500 text-yellow-600">M-01</Badge>
                <CardTitle className="text-base">Potential Precision Loss in Reward Calculations</CardTitle>
              </div>
              <CardDescription>RewardsDistributor.sol:145</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-3">
                Division before multiplication in reward per token calculation could lead to precision
                loss for small reward amounts.
              </p>
              <div className="bg-muted p-3 rounded text-sm font-mono">
                <p className="text-red-500">- rewardPerToken = (reward / totalStaked) * PRECISION;</p>
                <p className="text-green-500">+ rewardPerToken = (reward * PRECISION) / totalStaked;</p>
              </div>
              <Badge className="mt-3 bg-green-500">Fixed</Badge>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="border-yellow-500 text-yellow-600">M-02</Badge>
                <CardTitle className="text-base">Missing Zero Address Validation</CardTitle>
              </div>
              <CardDescription>NexusStaking.sol:42</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-3">
                Constructor accepts token addresses without validating they are not the zero address.
              </p>
              <div className="bg-muted p-3 rounded text-sm font-mono">
                <p className="text-green-500">+ require(_stakingToken != address(0), &quot;Invalid staking token&quot;);</p>
                <p className="text-green-500">+ require(_rewardsToken != address(0), &quot;Invalid rewards token&quot;);</p>
              </div>
              <Badge className="mt-3 bg-green-500">Fixed</Badge>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Access Control */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Access Control Matrix</h2>
        <Card>
          <CardContent className="pt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Function</th>
                  <th className="text-center py-2 px-3">ADMIN</th>
                  <th className="text-center py-2 px-3">OPERATOR</th>
                  <th className="text-center py-2 px-3">COMPLIANCE</th>
                  <th className="text-center py-2 px-3">PAUSER</th>
                  <th className="text-center py-2 px-3">PUBLIC</th>
                </tr>
              </thead>
              <tbody className="text-muted-foreground">
                <tr className="border-b">
                  <td className="py-2 px-3">setConfig</td>
                  <td className="py-2 px-3 text-center"><CheckCircle className="h-4 w-4 text-green-500 inline" /></td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">addToWhitelist</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center"><CheckCircle className="h-4 w-4 text-green-500 inline" /></td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">pause/unpause</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center"><CheckCircle className="h-4 w-4 text-green-500 inline" /></td>
                  <td className="py-2 px-3 text-center">-</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">mint/burn</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center"><CheckCircle className="h-4 w-4 text-green-500 inline" /></td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">stake/unstake</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center"><CheckCircle className="h-4 w-4 text-green-500 inline" /></td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">vote/propose</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-3 text-center"><CheckCircle className="h-4 w-4 text-green-500 inline" />*</td>
                </tr>
              </tbody>
            </table>
            <p className="text-xs text-muted-foreground mt-2">* Requires minimum token threshold</p>
          </CardContent>
        </Card>
      </section>

      {/* Security Checklist */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Security Checklist</h2>
        <Card>
          <CardContent className="pt-6">
            <div className="grid gap-2 md:grid-cols-2">
              {[
                "Reentrancy vulnerabilities",
                "Integer overflow/underflow",
                "Access control issues",
                "Front-running vulnerabilities",
                "Oracle manipulation risks",
                "Flash loan attack vectors",
                "Signature replay attacks",
                "DOS vulnerabilities",
                "Proxy implementation risks",
                "Gas griefing vectors",
              ].map((item) => (
                <div key={item} className="flex items-center gap-2 text-sm">
                  <CheckCircle className="h-4 w-4 text-green-500" />
                  <span className="text-muted-foreground">{item}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Bug Bounty */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Report a Vulnerability</h2>
        <Card className="bg-primary/5 border-primary/20">
          <CardContent className="pt-6">
            <div className="flex items-start gap-4">
              <AlertTriangle className="h-8 w-8 text-primary flex-shrink-0" />
              <div>
                <p className="font-medium mb-2">Found a security issue?</p>
                <p className="text-sm text-muted-foreground mb-4">
                  We take security seriously. If you&apos;ve discovered a vulnerability, please report it
                  responsibly through our bug bounty program.
                </p>
                <Link href="/bug-bounty">
                  <Badge className="cursor-pointer hover:bg-primary/90">
                    View Bug Bounty Program
                  </Badge>
                </Link>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
