import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import Link from "next/link";

export default function TermsOfServicePage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <h1 className="text-3xl font-bold">Terms of Service</h1>
          <Badge variant="outline">Effective: January 1, 2026</Badge>
        </div>
        <p className="text-muted-foreground">
          Please read these terms carefully before using Nexus Protocol
        </p>
      </div>

      <div className="prose dark:prose-invert max-w-none space-y-8">
        {/* Introduction */}
        <Card>
          <CardHeader>
            <CardTitle>1. Introduction and Acceptance</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              These Terms of Service (&quot;Terms&quot;) constitute a legally binding agreement between you
              (&quot;User,&quot; &quot;you,&quot; or &quot;your&quot;) and <strong>AnITConsultant, LLC</strong> (&quot;Company,&quot;
              &quot;we,&quot; &quot;us,&quot; or &quot;our&quot;), governing your access to and use of the Nexus Protocol
              platform, including the website at nexus.dapp.academy, smart contracts, APIs, and
              all related services (collectively, the &quot;Service&quot;).
            </p>
            <p>
              By accessing or using the Service, you acknowledge that you have read, understood,
              and agree to be bound by these Terms. If you do not agree to these Terms, you must
              not access or use the Service.
            </p>
            <p>
              AnITConsultant, LLC reserves the right to modify these Terms at any time. We will
              provide notice of material changes by updating the &quot;Effective&quot; date above. Your
              continued use of the Service after such modifications constitutes acceptance of
              the updated Terms.
            </p>
          </CardContent>
        </Card>

        {/* Intellectual Property */}
        <Card>
          <CardHeader>
            <CardTitle>2. Intellectual Property Rights</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              All intellectual property rights in and to the Service, including but not limited
              to the website, user interface, graphics, design, text, software, smart contracts,
              documentation, and all other content (collectively, &quot;Content&quot;), are owned by or
              licensed to <strong>AnITConsultant, LLC</strong>.
            </p>
            <p>
              The Nexus Protocol name, logo, and all related names, logos, product and service
              names, designs, and slogans are trademarks of AnITConsultant, LLC. You may not use
              such marks without our prior written permission.
            </p>
            <p>
              Subject to your compliance with these Terms, we grant you a limited, non-exclusive,
              non-transferable, revocable license to access and use the Service for its intended
              purposes. This license does not include the right to:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Modify, copy, or create derivative works of the Service</li>
              <li>Reverse engineer, decompile, or disassemble any part of the Service</li>
              <li>Remove or alter any proprietary notices or labels</li>
              <li>Use the Service for any commercial purpose without our consent</li>
              <li>Sublicense, sell, or transfer your rights under this license</li>
            </ul>
          </CardContent>
        </Card>

        {/* User Responsibilities */}
        <Card>
          <CardHeader>
            <CardTitle>3. User Responsibilities and Conduct</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>You agree to:</p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Provide accurate and complete information when required</li>
              <li>Maintain the security of your wallet and private keys</li>
              <li>Comply with all applicable laws and regulations</li>
              <li>Not engage in any fraudulent, abusive, or illegal activities</li>
              <li>Not attempt to interfere with or disrupt the Service</li>
              <li>Not use automated systems or bots to interact with the Service without authorization</li>
            </ul>
            <p>
              You are solely responsible for all activities that occur under your wallet address
              and for securing your private keys. We are not responsible for any unauthorized
              access to your wallet or any losses resulting from your failure to maintain security.
            </p>
          </CardContent>
        </Card>

        {/* Blockchain Risks */}
        <Card>
          <CardHeader>
            <CardTitle>4. Blockchain and Smart Contract Risks</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              You acknowledge and accept the inherent risks associated with blockchain technology
              and smart contracts, including but not limited to:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>
                <strong>Immutability</strong>: Blockchain transactions are irreversible once confirmed
              </li>
              <li>
                <strong>Smart Contract Risk</strong>: Smart contracts may contain bugs or vulnerabilities
              </li>
              <li>
                <strong>Network Risk</strong>: Blockchain networks may experience congestion, delays, or failures
              </li>
              <li>
                <strong>Regulatory Risk</strong>: Laws and regulations may change and affect the Service
              </li>
              <li>
                <strong>Market Risk</strong>: Digital asset values are volatile and may fluctuate significantly
              </li>
              <li>
                <strong>Gas Fees</strong>: Transaction fees are required and may vary significantly
              </li>
            </ul>
            <p>
              We do not guarantee the performance, security, or availability of any smart contract
              or blockchain network. You interact with smart contracts at your own risk.
            </p>
          </CardContent>
        </Card>

        {/* Tokens and NFTs */}
        <Card>
          <CardHeader>
            <CardTitle>5. Tokens and Digital Assets</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              The NEXUS token (NXS) and Nexus NFTs are utility tokens used within the Nexus Protocol
              ecosystem. They are <strong>not</strong> securities, investments, or financial instruments.
            </p>
            <p>
              Tokens and NFTs:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Do not represent equity, ownership, or voting rights in AnITConsultant, LLC</li>
              <li>Do not entitle holders to dividends, profits, or financial returns</li>
              <li>Are not backed by any physical asset or collateral</li>
              <li>May have no value outside the Nexus Protocol ecosystem</li>
            </ul>
            <p>
              We make no guarantees regarding the future value, utility, or functionality of any
              tokens or NFTs. You should not acquire tokens or NFTs as an investment.
            </p>
          </CardContent>
        </Card>

        {/* Staking and Governance */}
        <Card>
          <CardHeader>
            <CardTitle>6. Staking and Governance</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              Staking NEXUS tokens involves locking tokens in smart contracts to participate in
              the protocol. You acknowledge:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Staked tokens are subject to a 7-day unbonding period</li>
              <li>Staking rewards are not guaranteed and may vary</li>
              <li>Slashing may occur under certain conditions as defined by the protocol</li>
              <li>Smart contract risks apply to all staking activities</li>
            </ul>
            <p>
              Governance participation allows token holders to vote on protocol proposals. Governance
              decisions are made collectively by token holders, and we do not guarantee any
              particular outcome of governance votes.
            </p>
          </CardContent>
        </Card>

        {/* Disclaimers */}
        <Card>
          <CardHeader>
            <CardTitle>7. Disclaimers</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="uppercase font-semibold">
              THE SERVICE IS PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE&quot; WITHOUT WARRANTIES OF ANY KIND,
              EITHER EXPRESS OR IMPLIED.
            </p>
            <p>
              To the fullest extent permitted by law, AnITConsultant, LLC disclaims all warranties,
              including but not limited to:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Implied warranties of merchantability and fitness for a particular purpose</li>
              <li>Warranties of non-infringement or accuracy of information</li>
              <li>Warranties that the Service will be uninterrupted, secure, or error-free</li>
              <li>Warranties regarding the reliability of any smart contract</li>
            </ul>
            <p>
              We do not provide financial, investment, tax, or legal advice. You should consult
              qualified professionals before making any financial decisions.
            </p>
          </CardContent>
        </Card>

        {/* Limitation of Liability */}
        <Card>
          <CardHeader>
            <CardTitle>8. Limitation of Liability</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="uppercase font-semibold">
              TO THE MAXIMUM EXTENT PERMITTED BY LAW, ANITCONSULTANT, LLC SHALL NOT BE LIABLE FOR
              ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES.
            </p>
            <p>
              This includes, without limitation, damages for:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Loss of profits, data, or other intangible losses</li>
              <li>Loss of or damage to digital assets</li>
              <li>Unauthorized access to or alteration of your transmissions or data</li>
              <li>Smart contract failures or exploits</li>
              <li>Actions of third parties on the blockchain</li>
              <li>Regulatory actions or changes in law</li>
            </ul>
            <p>
              Our total liability for any claim arising from or related to these Terms or the
              Service shall not exceed the greater of (a) $100 USD or (b) the amount you paid
              us in the 12 months preceding the claim.
            </p>
          </CardContent>
        </Card>

        {/* Indemnification */}
        <Card>
          <CardHeader>
            <CardTitle>9. Indemnification</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              You agree to indemnify, defend, and hold harmless AnITConsultant, LLC and its
              officers, directors, employees, agents, and affiliates from and against any and
              all claims, damages, losses, liabilities, costs, and expenses (including reasonable
              attorneys&apos; fees) arising from or related to:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Your use of the Service</li>
              <li>Your violation of these Terms</li>
              <li>Your violation of any applicable law or regulation</li>
              <li>Your infringement of any third-party rights</li>
              <li>Any content you submit or transmit through the Service</li>
            </ul>
          </CardContent>
        </Card>

        {/* Prohibited Activities */}
        <Card>
          <CardHeader>
            <CardTitle>10. Prohibited Activities</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>You agree not to:</p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Use the Service for money laundering, terrorist financing, or other illegal purposes</li>
              <li>Manipulate markets or engage in wash trading</li>
              <li>Exploit smart contracts or the Service in unintended ways</li>
              <li>Use the Service if you are subject to sanctions or located in a prohibited jurisdiction</li>
              <li>Interfere with the proper functioning of the Service</li>
              <li>Attempt to access unauthorized areas of the Service</li>
              <li>Harvest or collect user information without consent</li>
              <li>Transmit malware, viruses, or harmful code</li>
            </ul>
          </CardContent>
        </Card>

        {/* Termination */}
        <Card>
          <CardHeader>
            <CardTitle>11. Termination</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              We may suspend or terminate your access to the Service at any time, with or without
              cause, and with or without notice. You may discontinue use of the Service at any time.
            </p>
            <p>
              Upon termination:
            </p>
            <ul className="list-disc pl-6 space-y-2">
              <li>Your license to use the Service immediately terminates</li>
              <li>Provisions that by their nature should survive will continue in effect</li>
              <li>Any tokens or NFTs in your wallet remain under your control on the blockchain</li>
              <li>Any staked tokens remain subject to the smart contract&apos;s unbonding period</li>
            </ul>
          </CardContent>
        </Card>

        {/* Governing Law */}
        <Card>
          <CardHeader>
            <CardTitle>12. Governing Law and Dispute Resolution</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              These Terms shall be governed by and construed in accordance with the laws of the
              State of Delaware, United States, without regard to its conflict of law principles.
            </p>
            <p>
              Any dispute arising from these Terms or the Service shall be resolved through
              binding arbitration administered by the American Arbitration Association in
              accordance with its Commercial Arbitration Rules. The arbitration shall be
              conducted in the English language and shall take place in Delaware, United States.
            </p>
            <p>
              You agree to waive any right to participate in a class action lawsuit or class-wide
              arbitration against AnITConsultant, LLC.
            </p>
          </CardContent>
        </Card>

        {/* Miscellaneous */}
        <Card>
          <CardHeader>
            <CardTitle>13. Miscellaneous</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              <strong>Entire Agreement</strong>: These Terms, together with our Privacy Policy and
              Cookie Policy, constitute the entire agreement between you and AnITConsultant, LLC.
            </p>
            <p>
              <strong>Severability</strong>: If any provision of these Terms is found unenforceable,
              the remaining provisions will continue in effect.
            </p>
            <p>
              <strong>Waiver</strong>: Our failure to enforce any right or provision shall not
              constitute a waiver of that right or provision.
            </p>
            <p>
              <strong>Assignment</strong>: You may not assign or transfer these Terms without our
              consent. We may assign these Terms without restriction.
            </p>
          </CardContent>
        </Card>

        {/* Contact */}
        <Card className="bg-muted/50">
          <CardHeader>
            <CardTitle>14. Contact Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p>
              For questions about these Terms of Service, please contact us:
            </p>
            <div className="space-y-2">
              <p><strong>AnITConsultant, LLC</strong></p>
              <p>
                Email:{" "}
                <Link href="mailto:legal@anitconsultant.com" className="text-primary hover:underline">
                  legal@anitconsultant.com
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
          <Link href="/privacy" className="text-primary hover:underline">
            Privacy Policy
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
