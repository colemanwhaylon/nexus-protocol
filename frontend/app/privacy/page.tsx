import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Shield, Globe } from "lucide-react";
import Link from "next/link";

export default function PrivacyPolicyPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Shield className="h-8 w-8 text-primary" />
          <h1 className="text-3xl font-bold">Privacy Policy</h1>
          <Badge variant="outline">Effective: January 1, 2026</Badge>
        </div>
        <p className="text-muted-foreground">
          How we collect, use, and protect your personal information
        </p>
      </div>

      {/* GDPR Notice */}
      <Alert className="mb-8 border-primary/50 bg-primary/5">
        <Globe className="h-4 w-4" />
        <AlertTitle>EU/EEA Users</AlertTitle>
        <AlertDescription>
          This Privacy Policy complies with the General Data Protection Regulation (GDPR).
          See <a href="#gdpr-rights" className="underline">Section 10</a> for your specific rights under GDPR.
        </AlertDescription>
      </Alert>

      <div className="prose dark:prose-invert max-w-none space-y-8">
        {/* Introduction */}
        <Card>
          <CardHeader>
            <CardTitle>1. Introduction</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              <strong>AnITConsultant, LLC</strong> (&quot;Company,&quot; &quot;we,&quot; &quot;us,&quot; or &quot;our&quot;) is committed
              to protecting your privacy. This Privacy Policy explains how we collect, use,
              disclose, and safeguard your information when you use the Nexus Protocol platform,
              including the website at nexus.dapp.academy and related services (the &quot;Service&quot;).
            </p>
            <p>
              By using the Service, you consent to the data practices described in this policy.
              If you do not agree with these practices, please do not use the Service.
            </p>
          </CardContent>
        </Card>

        {/* Data Controller */}
        <Card>
          <CardHeader>
            <CardTitle>2. Data Controller</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              For the purposes of applicable data protection laws, including the GDPR, the data
              controller is:
            </p>
            <div className="bg-muted/50 p-4 rounded-lg">
              <p><strong>AnITConsultant, LLC</strong></p>
              <p>Email: <Link href="mailto:it@anitconsultant.com" className="text-primary hover:underline">it@anitconsultant.com</Link></p>
              <p>Website: <Link href="https://anitconsultant.com" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">anitconsultant.com</Link></p>
            </div>
          </CardContent>
        </Card>

        {/* Information We Collect */}
        <Card>
          <CardHeader>
            <CardTitle>3. Information We Collect</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <h4 className="font-semibold">3.1 Information You Provide</h4>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Wallet Address</strong>: Your public blockchain address when you connect
                your wallet to the Service
              </li>
              <li>
                <strong>Transaction Data</strong>: Information about your on-chain transactions
                when interacting with our smart contracts
              </li>
              <li>
                <strong>Communication Data</strong>: Information you provide when contacting us
                for support or inquiries
              </li>
              <li>
                <strong>KYC Information</strong>: If applicable, identity verification information
                required for regulatory compliance (processed by third-party providers)
              </li>
            </ul>

            <h4 className="font-semibold mt-6">3.2 Automatically Collected Information</h4>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Device Information</strong>: Browser type, operating system, device type
              </li>
              <li>
                <strong>Usage Data</strong>: Pages visited, features used, time spent on the Service
              </li>
              <li>
                <strong>Log Data</strong>: IP address, access times, referring URLs
              </li>
              <li>
                <strong>Cookies</strong>: As described in our <Link href="/cookies" className="text-primary hover:underline">Cookie Policy</Link>
              </li>
            </ul>

            <h4 className="font-semibold mt-6">3.3 Blockchain Data</h4>
            <p>
              Please note that blockchain transactions are public by nature. Any transactions
              you make through the Service, including token transfers, staking, and governance
              votes, are recorded on the public blockchain and are not private.
            </p>
          </CardContent>
        </Card>

        {/* Legal Basis (GDPR) */}
        <Card>
          <CardHeader>
            <CardTitle>4. Legal Basis for Processing (GDPR)</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              For users in the European Economic Area (EEA), we process personal data under
              the following legal bases:
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-2 px-3">Purpose</th>
                    <th className="text-left py-2 px-3">Legal Basis</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b">
                    <td className="py-2 px-3">Providing the Service</td>
                    <td className="py-2 px-3">Contract performance (Art. 6(1)(b) GDPR)</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">Regulatory compliance (KYC/AML)</td>
                    <td className="py-2 px-3">Legal obligation (Art. 6(1)(c) GDPR)</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">Security and fraud prevention</td>
                    <td className="py-2 px-3">Legitimate interest (Art. 6(1)(f) GDPR)</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">Analytics and improvement</td>
                    <td className="py-2 px-3">Legitimate interest (Art. 6(1)(f) GDPR)</td>
                  </tr>
                  <tr className="border-b">
                    <td className="py-2 px-3">Marketing communications</td>
                    <td className="py-2 px-3">Consent (Art. 6(1)(a) GDPR)</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* How We Use Information */}
        <Card>
          <CardHeader>
            <CardTitle>5. How We Use Your Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>We use the collected information to:</p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Provide, maintain, and improve the Service</li>
              <li>Process transactions and interact with smart contracts</li>
              <li>Respond to your requests and provide customer support</li>
              <li>Send important notices about the Service</li>
              <li>Detect, prevent, and address technical issues and security threats</li>
              <li>Comply with legal obligations, including KYC/AML requirements</li>
              <li>Analyze usage patterns to improve user experience</li>
              <li>Enforce our Terms of Service</li>
            </ul>
          </CardContent>
        </Card>

        {/* Information Sharing */}
        <Card>
          <CardHeader>
            <CardTitle>6. Information Sharing and Disclosure</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>We may share your information in the following circumstances:</p>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Service Providers</strong>: With third-party vendors who perform services
                on our behalf (hosting, analytics, KYC verification)
              </li>
              <li>
                <strong>Legal Requirements</strong>: When required by law, regulation, or legal
                process
              </li>
              <li>
                <strong>Protection of Rights</strong>: To protect the rights, property, or safety
                of AnITConsultant, LLC, our users, or others
              </li>
              <li>
                <strong>Business Transfers</strong>: In connection with a merger, acquisition, or
                sale of assets
              </li>
              <li>
                <strong>With Your Consent</strong>: When you have given us explicit permission
              </li>
            </ul>
            <p>
              We do <strong>not</strong> sell your personal information to third parties.
            </p>
          </CardContent>
        </Card>

        {/* International Transfers */}
        <Card>
          <CardHeader>
            <CardTitle>7. International Data Transfers</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              Your information may be transferred to and processed in countries other than
              your country of residence, including the United States. These countries may
              have different data protection laws than your country.
            </p>
            <p>
              For transfers from the EEA to countries not deemed to provide adequate data
              protection, we implement appropriate safeguards, such as:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Standard Contractual Clauses approved by the European Commission</li>
              <li>Binding Corporate Rules where applicable</li>
              <li>Your explicit consent for specific transfers</li>
            </ul>
          </CardContent>
        </Card>

        {/* Data Retention */}
        <Card>
          <CardHeader>
            <CardTitle>8. Data Retention</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              We retain personal data only for as long as necessary to fulfill the purposes
              for which it was collected, including:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Account Data</strong>: For the duration of your use of the Service, plus
                a reasonable period for legal or business purposes
              </li>
              <li>
                <strong>Transaction Records</strong>: As required by law (typically 5-7 years for
                financial records)
              </li>
              <li>
                <strong>KYC Data</strong>: As required by AML regulations (typically 5 years after
                relationship ends)
              </li>
              <li>
                <strong>Analytics Data</strong>: Aggregated and anonymized data may be retained
                indefinitely
              </li>
            </ul>
            <p>
              Note: Blockchain transactions are permanent and cannot be deleted from the
              public ledger.
            </p>
          </CardContent>
        </Card>

        {/* Data Security */}
        <Card>
          <CardHeader>
            <CardTitle>9. Data Security</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              We implement appropriate technical and organizational measures to protect your
              personal data, including:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Encryption of data in transit (TLS/SSL) and at rest</li>
              <li>Regular security assessments and audits</li>
              <li>Access controls and authentication measures</li>
              <li>Secure coding practices and code reviews</li>
              <li>Incident response procedures</li>
            </ul>
            <p>
              However, no method of transmission over the Internet is 100% secure. While we
              strive to protect your data, we cannot guarantee absolute security.
            </p>
          </CardContent>
        </Card>

        {/* GDPR Rights */}
        <Card id="gdpr-rights" className="border-primary/50">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Globe className="h-5 w-5 text-primary" />
              10. Your Rights Under GDPR (EEA Users)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              If you are located in the European Economic Area (EEA), you have the following
              rights under the General Data Protection Regulation (GDPR):
            </p>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right of Access</h4>
                <p className="text-sm text-muted-foreground">
                  Request a copy of the personal data we hold about you
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Rectification</h4>
                <p className="text-sm text-muted-foreground">
                  Request correction of inaccurate or incomplete data
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Erasure</h4>
                <p className="text-sm text-muted-foreground">
                  Request deletion of your personal data (&quot;right to be forgotten&quot;)
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Restrict Processing</h4>
                <p className="text-sm text-muted-foreground">
                  Request limitation of how we process your data
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Data Portability</h4>
                <p className="text-sm text-muted-foreground">
                  Receive your data in a structured, machine-readable format
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Object</h4>
                <p className="text-sm text-muted-foreground">
                  Object to processing based on legitimate interests
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Withdraw Consent</h4>
                <p className="text-sm text-muted-foreground">
                  Withdraw consent at any time where processing is based on consent
                </p>
              </div>
              <div className="bg-muted/50 p-4 rounded-lg">
                <h4 className="font-semibold mb-2">Right to Lodge a Complaint</h4>
                <p className="text-sm text-muted-foreground">
                  File a complaint with your local supervisory authority
                </p>
              </div>
            </div>
            <p className="mt-4">
              To exercise any of these rights, please contact us at{" "}
              <Link href="mailto:it@anitconsultant.com" className="text-primary hover:underline">
                it@anitconsultant.com
              </Link>
              . We will respond within 30 days.
            </p>
            <p className="text-sm text-muted-foreground">
              Note: Some rights may be limited where we have overriding legitimate interests
              or legal obligations. Blockchain data cannot be modified or deleted due to the
              immutable nature of the technology.
            </p>
          </CardContent>
        </Card>

        {/* California Privacy Rights */}
        <Card>
          <CardHeader>
            <CardTitle>11. California Privacy Rights (CCPA)</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              California residents have additional rights under the California Consumer
              Privacy Act (CCPA):
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Right to know what personal information is collected</li>
              <li>Right to know whether personal information is sold or disclosed</li>
              <li>Right to opt-out of the sale of personal information</li>
              <li>Right to request deletion of personal information</li>
              <li>Right to non-discrimination for exercising privacy rights</li>
            </ul>
            <p>
              We do not sell personal information. To exercise your CCPA rights, contact us
              at{" "}
              <Link href="mailto:it@anitconsultant.com" className="text-primary hover:underline">
                it@anitconsultant.com
              </Link>
              .
            </p>
          </CardContent>
        </Card>

        {/* Children's Privacy */}
        <Card>
          <CardHeader>
            <CardTitle>12. Children&apos;s Privacy</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              The Service is not intended for individuals under the age of 18. We do not
              knowingly collect personal information from children. If you believe we have
              collected information from a child, please contact us immediately.
            </p>
          </CardContent>
        </Card>

        {/* Changes to Policy */}
        <Card>
          <CardHeader>
            <CardTitle>13. Changes to This Privacy Policy</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              We may update this Privacy Policy from time to time. We will notify you of
              material changes by:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Updating the &quot;Effective&quot; date at the top of this page</li>
              <li>Posting a notice on our website</li>
              <li>Sending an email notification where appropriate</li>
            </ul>
            <p>
              We encourage you to review this Privacy Policy periodically to stay informed
              about how we protect your information.
            </p>
          </CardContent>
        </Card>

        {/* Contact */}
        <Card className="bg-muted/50">
          <CardHeader>
            <CardTitle>14. Contact Us</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              If you have questions about this Privacy Policy or wish to exercise your
              privacy rights, please contact us:
            </p>
            <div className="space-y-2">
              <p><strong>AnITConsultant, LLC</strong></p>
              <p><strong>Data Protection Contact</strong></p>
              <p>
                Email:{" "}
                <Link href="mailto:it@anitconsultant.com" className="text-primary hover:underline">
                  it@anitconsultant.com
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
          <Link href="/cookies" className="text-primary hover:underline">
            Cookie Policy
          </Link>
          <Link href="/docs" className="text-primary hover:underline">
            Documentation
          </Link>
        </div>
      </div>
    </div>
  );
}
