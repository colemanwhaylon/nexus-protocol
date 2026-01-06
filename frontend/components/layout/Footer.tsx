import Link from 'next/link';
import { Github, Twitter, Linkedin, Globe, Mail } from 'lucide-react';

const footerLinks = {
  protocol: [
    { name: 'Staking', href: '/staking' },
    { name: 'NFT Collection', href: '/nft' },
    { name: 'Governance', href: '/governance' },
    { name: 'Documentation', href: '/docs' },
  ],
  resources: [
    { name: 'Whitepaper', href: '/whitepaper' },
    { name: 'Tokenomics', href: '/tokenomics' },
    { name: 'Security Audits', href: '/security' },
    { name: 'Bug Bounty', href: '/bug-bounty' },
  ],
  legal: [
    { name: 'Terms of Service', href: '/terms' },
    { name: 'Privacy Policy', href: '/privacy' },
    { name: 'Cookie Policy', href: '/cookies' },
  ],
};

const socialLinks = [
  { name: 'GitHub', href: 'https://github.com/colemanwhaylon/nexus-protocol', icon: Github },
  { name: 'X', href: 'https://x.com/anitconsultant', icon: Twitter },
  { name: 'LinkedIn', href: 'https://www.linkedin.com/in/anitconsultant/', icon: Linkedin },
  { name: 'Website', href: 'https://anitconsultant.com/', icon: Globe },
  { name: 'Email', href: 'mailto:it@anitconsultant.com', icon: Mail },
];

export function Footer() {
  return (
    <footer className="border-t bg-background">
      <div className="container py-12">
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-5">
          {/* Brand */}
          <div className="lg:col-span-2">
            <Link href="/" className="flex items-center space-x-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
                <span className="text-lg font-bold text-primary-foreground">N</span>
              </div>
              <span className="font-bold">Nexus Protocol</span>
            </Link>
            <p className="mt-4 max-w-xs text-sm text-muted-foreground">
              A comprehensive DeFi platform combining staking, NFTs, and decentralized governance.
            </p>
            <div className="mt-6 flex space-x-4">
              {socialLinks.map((item) => (
                <a
                  key={item.name}
                  href={item.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-muted-foreground transition-colors hover:text-foreground"
                >
                  <span className="sr-only">{item.name}</span>
                  <item.icon className="h-5 w-5" />
                </a>
              ))}
            </div>
          </div>

          {/* Protocol Links */}
          <div>
            <h3 className="text-sm font-semibold">Protocol</h3>
            <ul className="mt-4 space-y-3">
              {footerLinks.protocol.map((item) => (
                <li key={item.name}>
                  <Link
                    href={item.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {item.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Resources Links */}
          <div>
            <h3 className="text-sm font-semibold">Resources</h3>
            <ul className="mt-4 space-y-3">
              {footerLinks.resources.map((item) => (
                <li key={item.name}>
                  <Link
                    href={item.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {item.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal Links */}
          <div>
            <h3 className="text-sm font-semibold">Legal</h3>
            <ul className="mt-4 space-y-3">
              {footerLinks.legal.map((item) => (
                <li key={item.name}>
                  <Link
                    href={item.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {item.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Copyright */}
        <div className="mt-12 border-t pt-8">
          <p className="text-center text-sm text-muted-foreground">
            &copy; 2026 Nexus Protocol. All rights reserved, AnITConsultant, LLC
          </p>
        </div>
      </div>
    </footer>
  );
}
