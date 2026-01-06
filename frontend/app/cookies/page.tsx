import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Cookie, Globe, Info } from "lucide-react";
import Link from "next/link";

export default function CookiePolicyPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Cookie className="h-8 w-8 text-primary" />
          <h1 className="text-3xl font-bold">Cookie Policy</h1>
          <Badge variant="outline">Effective: January 1, 2026</Badge>
        </div>
        <p className="text-muted-foreground">
          How we use cookies and similar technologies
        </p>
      </div>

      {/* EU Notice */}
      <Alert className="mb-8 border-primary/50 bg-primary/5">
        <Globe className="h-4 w-4" />
        <AlertTitle>EU Cookie Compliance</AlertTitle>
        <AlertDescription>
          This Cookie Policy complies with the EU ePrivacy Directive and GDPR requirements.
          We obtain your consent before placing non-essential cookies.
        </AlertDescription>
      </Alert>

      <div className="prose dark:prose-invert max-w-none space-y-8">
        {/* Introduction */}
        <Card>
          <CardHeader>
            <CardTitle>1. What Are Cookies?</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              Cookies are small text files that are placed on your device (computer, tablet,
              or mobile phone) when you visit a website. They are widely used to make websites
              work more efficiently and provide information to website owners.
            </p>
            <p>
              <strong>AnITConsultant, LLC</strong> uses cookies and similar technologies
              (such as local storage and web beacons) on the Nexus Protocol platform
              (nexus.dapp.academy) to improve your experience and understand how our
              Service is used.
            </p>
          </CardContent>
        </Card>

        {/* Types of Cookies */}
        <Card>
          <CardHeader>
            <CardTitle>2. Types of Cookies We Use</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Essential Cookies */}
            <div className="border rounded-lg p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-semibold text-lg">Essential Cookies</h4>
                <Badge className="bg-green-600">Always Active</Badge>
              </div>
              <p className="text-muted-foreground text-sm mb-3">
                These cookies are necessary for the website to function and cannot be
                switched off. They are usually set in response to actions you take, such
                as setting privacy preferences, logging in, or filling out forms.
              </p>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-2 px-3">Cookie</th>
                      <th className="text-left py-2 px-3">Purpose</th>
                      <th className="text-left py-2 px-3">Duration</th>
                    </tr>
                  </thead>
                  <tbody className="text-muted-foreground">
                    <tr className="border-b">
                      <td className="py-2 px-3">session_id</td>
                      <td className="py-2 px-3">Maintains your session state</td>
                      <td className="py-2 px-3">Session</td>
                    </tr>
                    <tr className="border-b">
                      <td className="py-2 px-3">cookie_consent</td>
                      <td className="py-2 px-3">Stores your cookie preferences</td>
                      <td className="py-2 px-3">1 year</td>
                    </tr>
                    <tr className="border-b">
                      <td className="py-2 px-3">csrf_token</td>
                      <td className="py-2 px-3">Security - prevents cross-site attacks</td>
                      <td className="py-2 px-3">Session</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* Functional Cookies */}
            <div className="border rounded-lg p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-semibold text-lg">Functional Cookies</h4>
                <Badge variant="outline">Optional</Badge>
              </div>
              <p className="text-muted-foreground text-sm mb-3">
                These cookies enable enhanced functionality and personalization, such as
                remembering your preferences and settings. They may be set by us or by
                third-party providers.
              </p>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-2 px-3">Cookie</th>
                      <th className="text-left py-2 px-3">Purpose</th>
                      <th className="text-left py-2 px-3">Duration</th>
                    </tr>
                  </thead>
                  <tbody className="text-muted-foreground">
                    <tr className="border-b">
                      <td className="py-2 px-3">theme</td>
                      <td className="py-2 px-3">Remembers dark/light mode preference</td>
                      <td className="py-2 px-3">1 year</td>
                    </tr>
                    <tr className="border-b">
                      <td className="py-2 px-3">language</td>
                      <td className="py-2 px-3">Stores your language preference</td>
                      <td className="py-2 px-3">1 year</td>
                    </tr>
                    <tr className="border-b">
                      <td className="py-2 px-3">wallet_connector</td>
                      <td className="py-2 px-3">Remembers your preferred wallet</td>
                      <td className="py-2 px-3">30 days</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* Analytics Cookies */}
            <div className="border rounded-lg p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-semibold text-lg">Analytics Cookies</h4>
                <Badge variant="outline">Optional</Badge>
              </div>
              <p className="text-muted-foreground text-sm mb-3">
                These cookies help us understand how visitors interact with our website
                by collecting and reporting information anonymously. This helps us improve
                the Service.
              </p>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-2 px-3">Cookie</th>
                      <th className="text-left py-2 px-3">Provider</th>
                      <th className="text-left py-2 px-3">Purpose</th>
                      <th className="text-left py-2 px-3">Duration</th>
                    </tr>
                  </thead>
                  <tbody className="text-muted-foreground">
                    <tr className="border-b">
                      <td className="py-2 px-3">_ga</td>
                      <td className="py-2 px-3">Google Analytics</td>
                      <td className="py-2 px-3">Distinguishes unique users</td>
                      <td className="py-2 px-3">2 years</td>
                    </tr>
                    <tr className="border-b">
                      <td className="py-2 px-3">_ga_*</td>
                      <td className="py-2 px-3">Google Analytics</td>
                      <td className="py-2 px-3">Persists session state</td>
                      <td className="py-2 px-3">2 years</td>
                    </tr>
                    <tr className="border-b">
                      <td className="py-2 px-3">_gid</td>
                      <td className="py-2 px-3">Google Analytics</td>
                      <td className="py-2 px-3">Distinguishes users</td>
                      <td className="py-2 px-3">24 hours</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* Marketing Cookies */}
            <div className="border rounded-lg p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-semibold text-lg">Marketing Cookies</h4>
                <Badge variant="outline">Optional</Badge>
              </div>
              <p className="text-muted-foreground text-sm mb-3">
                These cookies may be set through our site by advertising partners to build
                a profile of your interests and show you relevant ads on other sites.
              </p>
              <p className="text-sm text-muted-foreground italic">
                We currently do not use marketing cookies on Nexus Protocol.
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Local Storage */}
        <Card>
          <CardHeader>
            <CardTitle>3. Local Storage and Web3 Data</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              In addition to cookies, we use browser local storage to store certain data
              related to your Web3 experience:
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2 px-3">Item</th>
                    <th className="text-left py-2 px-3">Purpose</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b">
                    <td className="py-2 px-3">wagmi.store</td>
                    <td className="py-2 px-3">Wallet connection state (wagmi library)</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">rk-recent</td>
                    <td className="py-2 px-3">Recently used wallets (RainbowKit)</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">theme-preference</td>
                    <td className="py-2 px-3">UI theme preference</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <Alert>
              <Info className="h-4 w-4" />
              <AlertDescription>
                Your wallet private keys are never stored by our website. Wallet connections
                are managed by your wallet provider (MetaMask, WalletConnect, etc.).
              </AlertDescription>
            </Alert>
          </CardContent>
        </Card>

        {/* Managing Cookies */}
        <Card>
          <CardHeader>
            <CardTitle>4. How to Manage Cookies</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <h4 className="font-semibold">4.1 Cookie Consent Banner</h4>
            <p>
              When you first visit our website, you will see a cookie consent banner that
              allows you to accept or reject non-essential cookies. You can change your
              preferences at any time by clicking the cookie settings link in the footer.
            </p>

            <h4 className="font-semibold mt-6">4.2 Browser Settings</h4>
            <p>
              Most web browsers allow you to control cookies through their settings. You can:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Block all cookies</li>
              <li>Block third-party cookies</li>
              <li>Clear existing cookies</li>
              <li>Set browser to notify you when receiving cookies</li>
            </ul>
            <p className="mt-4">
              Here are links to cookie management instructions for popular browsers:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <Link href="https://support.google.com/chrome/answer/95647" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                  Google Chrome
                </Link>
              </li>
              <li>
                <Link href="https://support.mozilla.org/en-US/kb/cookies-information-websites-store-on-your-computer" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                  Mozilla Firefox
                </Link>
              </li>
              <li>
                <Link href="https://support.apple.com/guide/safari/manage-cookies-sfri11471/mac" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                  Safari
                </Link>
              </li>
              <li>
                <Link href="https://support.microsoft.com/en-us/microsoft-edge/delete-cookies-in-microsoft-edge-63947406-40ac-c3b8-57b9-2a946a29ae09" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                  Microsoft Edge
                </Link>
              </li>
            </ul>

            <h4 className="font-semibold mt-6">4.3 Opt-Out of Analytics</h4>
            <p>
              You can opt out of Google Analytics by installing the{" "}
              <Link href="https://tools.google.com/dlpage/gaoptout" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                Google Analytics Opt-out Browser Add-on
              </Link>
              .
            </p>

            <Alert className="mt-4">
              <Info className="h-4 w-4" />
              <AlertDescription>
                <strong>Note:</strong> Blocking essential cookies may affect the functionality
                of the website. Some features may not work properly without cookies.
              </AlertDescription>
            </Alert>
          </CardContent>
        </Card>

        {/* Third-Party Cookies */}
        <Card>
          <CardHeader>
            <CardTitle>5. Third-Party Cookies</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              Some cookies on our website are placed by third-party services. These
              third parties have their own privacy policies governing the use of
              cookies:
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2 px-3">Provider</th>
                    <th className="text-left py-2 px-3">Purpose</th>
                    <th className="text-left py-2 px-3">Privacy Policy</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b">
                    <td className="py-2 px-3">Google Analytics</td>
                    <td className="py-2 px-3">Website analytics</td>
                    <td className="py-2 px-3">
                      <Link href="https://policies.google.com/privacy" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                        View Policy
                      </Link>
                    </td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">Vercel</td>
                    <td className="py-2 px-3">Website hosting</td>
                    <td className="py-2 px-3">
                      <Link href="https://vercel.com/legal/privacy-policy" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                        View Policy
                      </Link>
                    </td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">WalletConnect</td>
                    <td className="py-2 px-3">Wallet connections</td>
                    <td className="py-2 px-3">
                      <Link href="https://walletconnect.com/privacy" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                        View Policy
                      </Link>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* Do Not Track */}
        <Card>
          <CardHeader>
            <CardTitle>6. Do Not Track Signals</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              Some browsers have a &quot;Do Not Track&quot; (DNT) feature that signals to websites
              that you do not want to be tracked. Currently, there is no universal standard
              for how websites should respond to DNT signals.
            </p>
            <p>
              We respect your privacy preferences and will honor DNT signals by not setting
              non-essential cookies when this signal is detected.
            </p>
          </CardContent>
        </Card>

        {/* Updates */}
        <Card>
          <CardHeader>
            <CardTitle>7. Changes to This Cookie Policy</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              We may update this Cookie Policy from time to time to reflect changes in
              technology, legislation, or our data practices. Any updates will be posted
              on this page with an updated &quot;Effective&quot; date.
            </p>
            <p>
              We encourage you to periodically review this page for the latest information
              on our cookie practices.
            </p>
          </CardContent>
        </Card>

        {/* Contact */}
        <Card className="bg-muted/50">
          <CardHeader>
            <CardTitle>8. Contact Us</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              If you have questions about our use of cookies or this Cookie Policy,
              please contact us:
            </p>
            <div className="space-y-2">
              <p><strong>AnITConsultant, LLC</strong></p>
              <p>
                Email:{" "}
                <Link href="mailto:privacy@anitconsultant.com" className="text-primary hover:underline">
                  privacy@anitconsultant.com
                </Link>
              </p>
              <p>
                Website:{" "}
                <Link href="https://anitconsultant.com" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">
                  anitconsultant.com
                </Link>
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Related Links */}
        <div className="flex flex-wrap gap-4 pt-4">
          <Link href="/terms" className="text-primary hover:underline">
            Terms of Service
          </Link>
          <Link href="/privacy" className="text-primary hover:underline">
            Privacy Policy
          </Link>
          <Link href="/docs" className="text-primary hover:underline">
            Documentation
          </Link>
        </div>
      </div>
    </div>
  );
}
