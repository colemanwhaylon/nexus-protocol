import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Bug, ExternalLink, Shield, CheckCircle, XCircle } from "lucide-react";
import Link from "next/link";

export default function BugBountyPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Bug className="h-8 w-8 text-primary" />
          <h1 className="text-3xl font-bold">Bug Bounty Program</h1>
        </div>
        <p className="text-muted-foreground">
          Help us keep Nexus Protocol secure and earn rewards
        </p>
      </div>

      {/* Program Overview */}
      <section className="mb-12">
        <Card>
          <CardHeader>
            <CardTitle>Program Overview</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground">
              Nexus Protocol is committed to working with the security community to find and fix
              vulnerabilities. We appreciate your help in making our protocol more secure for everyone.
            </p>
          </CardContent>
        </Card>
      </section>

      {/* How to Report */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">How to Report</h2>
        <Card className="bg-primary/5 border-primary/20">
          <CardContent className="pt-6">
            <p className="text-muted-foreground mb-4">
              Please report security vulnerabilities through our GitHub repository issues page.
              This ensures proper tracking and timely response.
            </p>
            <Link
              href="https://github.com/colemanwhaylon/nexus-protocol/issues"
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button className="gap-2">
                <ExternalLink className="h-4 w-4" />
                Report on GitHub
              </Button>
            </Link>
          </CardContent>
        </Card>
      </section>

      {/* Rewards */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Rewards</h2>
        <Card>
          <CardContent className="pt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Severity</th>
                  <th className="text-left py-2 px-3">Smart Contracts</th>
                  <th className="text-left py-2 px-3">Backend/API</th>
                  <th className="text-left py-2 px-3">Infrastructure</th>
                </tr>
              </thead>
              <tbody className="text-muted-foreground">
                <tr className="border-b">
                  <td className="py-2 px-3">
                    <Badge variant="destructive">Critical</Badge>
                  </td>
                  <td className="py-2 px-3">$50,000 - $100,000</td>
                  <td className="py-2 px-3">$10,000 - $25,000</td>
                  <td className="py-2 px-3">$5,000 - $15,000</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">
                    <Badge variant="destructive" className="bg-orange-500">High</Badge>
                  </td>
                  <td className="py-2 px-3">$10,000 - $50,000</td>
                  <td className="py-2 px-3">$5,000 - $10,000</td>
                  <td className="py-2 px-3">$2,500 - $5,000</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">
                    <Badge variant="outline" className="border-yellow-500 text-yellow-600">Medium</Badge>
                  </td>
                  <td className="py-2 px-3">$2,500 - $10,000</td>
                  <td className="py-2 px-3">$1,000 - $5,000</td>
                  <td className="py-2 px-3">$500 - $2,500</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">
                    <Badge variant="outline">Low</Badge>
                  </td>
                  <td className="py-2 px-3">$500 - $2,500</td>
                  <td className="py-2 px-3">$250 - $1,000</td>
                  <td className="py-2 px-3">$100 - $500</td>
                </tr>
              </tbody>
            </table>
            <p className="text-xs text-muted-foreground mt-4">
              Note: Rewards are determined based on impact, likelihood, and quality of report.
            </p>
          </CardContent>
        </Card>
      </section>

      {/* Scope */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Scope</h2>
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <CheckCircle className="h-5 w-5 text-green-500" />
                In Scope
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-center gap-2">
                  <Badge variant="destructive" className="text-xs">Critical</Badge>
                  NexusToken, NexusStaking, RewardsDistributor
                </li>
                <li className="flex items-center gap-2">
                  <Badge variant="destructive" className="text-xs bg-orange-500">High</Badge>
                  NexusGovernor, NexusTimelock, NexusEmergency
                </li>
                <li className="flex items-center gap-2">
                  <Badge variant="outline" className="text-xs border-yellow-500 text-yellow-600">Medium</Badge>
                  NexusNFT, NexusVesting, NexusAirdrop
                </li>
                <li className="flex items-center gap-2">
                  <Badge variant="outline" className="text-xs">API</Badge>
                  REST API endpoints
                </li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <XCircle className="h-5 w-5 text-red-500" />
                Out of Scope
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li>Third-party contracts (OpenZeppelin, Chainlink)</li>
                <li>Frontend/UI issues (unless leading to fund loss)</li>
                <li>Social engineering attacks</li>
                <li>Physical security</li>
                <li>Issues already known or reported</li>
                <li>Testnet deployments</li>
                <li>Gas optimization suggestions</li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Severity Classification */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Severity Classification</h2>
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Badge variant="destructive">Critical</Badge>
              </CardTitle>
              <CardDescription>
                Direct loss of funds or permanent freezing of funds with no recovery mechanism
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Examples: Unauthorized token minting, bypassing access control to drain funds,
                reentrancy leading to fund theft, governance takeover with immediate execution.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Badge variant="destructive" className="bg-orange-500">High</Badge>
              </CardTitle>
              <CardDescription>
                Significant impact to protocol functionality or conditional fund loss
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Examples: Griefing attacks that lock user funds temporarily, manipulation of reward
                calculations, denial of service to critical functions.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Badge variant="outline" className="border-yellow-500 text-yellow-600">Medium</Badge>
              </CardTitle>
              <CardDescription>
                Limited impact or requires specific conditions
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Examples: Minor calculation errors with capped impact, temporary denial of service,
                information disclosure, front-running with limited profit potential.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Badge variant="outline">Low</Badge>
              </CardTitle>
              <CardDescription>
                Minimal impact or informational
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Examples: Gas inefficiencies affecting users, missing events, code quality issues
                with no security impact, documentation errors.
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Rules */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Rules of Engagement</h2>
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg text-green-600">Do</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-start gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500 mt-0.5" />
                  Provide detailed reports with reproduction steps
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500 mt-0.5" />
                  Test only on testnets or local forks
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500 mt-0.5" />
                  Give us reasonable time to respond
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500 mt-0.5" />
                  Keep vulnerabilities confidential until fixed
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="h-4 w-4 text-green-500 mt-0.5" />
                  Follow responsible disclosure practices
                </li>
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-lg text-red-600">Do Not</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-2">
                <li className="flex items-start gap-2">
                  <XCircle className="h-4 w-4 text-red-500 mt-0.5" />
                  Test on mainnet contracts
                </li>
                <li className="flex items-start gap-2">
                  <XCircle className="h-4 w-4 text-red-500 mt-0.5" />
                  Exploit vulnerabilities beyond PoC
                </li>
                <li className="flex items-start gap-2">
                  <XCircle className="h-4 w-4 text-red-500 mt-0.5" />
                  Access or modify other users&apos; data
                </li>
                <li className="flex items-start gap-2">
                  <XCircle className="h-4 w-4 text-red-500 mt-0.5" />
                  Perform denial of service attacks
                </li>
                <li className="flex items-start gap-2">
                  <XCircle className="h-4 w-4 text-red-500 mt-0.5" />
                  Publicly disclose before fix is deployed
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Response Timeline */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Response Timeline</h2>
        <Card>
          <CardContent className="pt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3">Severity</th>
                  <th className="text-left py-2 px-3">Initial Response</th>
                  <th className="text-left py-2 px-3">Fix Target</th>
                  <th className="text-left py-2 px-3">Disclosure</th>
                </tr>
              </thead>
              <tbody className="text-muted-foreground">
                <tr className="border-b">
                  <td className="py-2 px-3">Critical</td>
                  <td className="py-2 px-3">24 hours</td>
                  <td className="py-2 px-3">7 days</td>
                  <td className="py-2 px-3">After fix + 14 days</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">High</td>
                  <td className="py-2 px-3">48 hours</td>
                  <td className="py-2 px-3">14 days</td>
                  <td className="py-2 px-3">After fix + 30 days</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Medium</td>
                  <td className="py-2 px-3">72 hours</td>
                  <td className="py-2 px-3">30 days</td>
                  <td className="py-2 px-3">After fix + 30 days</td>
                </tr>
                <tr className="border-b">
                  <td className="py-2 px-3">Low</td>
                  <td className="py-2 px-3">7 days</td>
                  <td className="py-2 px-3">60 days</td>
                  <td className="py-2 px-3">After fix + 30 days</td>
                </tr>
              </tbody>
            </table>
          </CardContent>
        </Card>
      </section>

      {/* Safe Harbor */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Safe Harbor</h2>
        <Alert>
          <Shield className="h-4 w-4" />
          <AlertTitle>Legal Protection</AlertTitle>
          <AlertDescription>
            We will not pursue legal action against researchers who:
            <ul className="list-disc pl-6 mt-2 space-y-1">
              <li>Act in good faith</li>
              <li>Avoid privacy violations</li>
              <li>Avoid destruction of data</li>
              <li>Avoid service disruption</li>
              <li>Report through official channels</li>
              <li>Give reasonable time to fix</li>
            </ul>
          </AlertDescription>
        </Alert>
      </section>

      {/* Contact */}
      <section className="mb-12">
        <h2 className="text-2xl font-bold mb-4">Contact</h2>
        <Card>
          <CardContent className="pt-6">
            <div className="space-y-4">
              <div>
                <p className="font-medium">Primary Contact</p>
                <Link
                  href="https://github.com/colemanwhaylon/nexus-protocol/issues"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary hover:underline"
                >
                  GitHub Issues
                </Link>
              </div>
              <div>
                <p className="font-medium">Email</p>
                <Link
                  href="mailto:it@anitconsultant.com"
                  className="text-primary hover:underline"
                >
                  it@anitconsultant.com
                </Link>
              </div>
              <div>
                <p className="font-medium">Response Hours</p>
                <p className="text-muted-foreground">24/7 for Critical, Business hours for others</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Thank You */}
      <Card className="bg-muted/50">
        <CardContent className="pt-6 text-center">
          <p className="text-muted-foreground">
            Thank you for helping keep Nexus Protocol secure.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
