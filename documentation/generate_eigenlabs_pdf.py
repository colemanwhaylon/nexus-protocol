#!/usr/bin/env python3
"""Generate Whaylon Coleman Blockchain Experience PDF for Eigen Labs (2-page version with FULL detailed mappings)"""

from fpdf import FPDF
from fpdf.enums import XPos, YPos
from pathlib import Path

class BlockchainExperiencePDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=False)

def create_pdf():
    pdf = BlockchainExperiencePDF()

    # ============ PAGE 1: NARRATIVE ============
    pdf.add_page()
    pdf.set_margins(20, 12, 20)
    pdf.set_y(12)

    # Title
    pdf.set_font("Helvetica", "B", 22)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 10, "My Journey in Blockchain and Digital Assets", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    # Subtitle
    pdf.set_font("Helvetica", "I", 10)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 5, "Whaylon Coleman  |  Principal Software Architect  |  25+ Years in Enterprise Software", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    # Footer links moved to top (replacing LinkedIn-only line)
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(41, 98, 166)

    github_text = "GitHub"
    linkedin_text = "LinkedIn"
    email_text = "colemanwhaylon@yahoo.com"
    separator = "  |  "

    github_w = pdf.get_string_width(github_text)
    linkedin_w = pdf.get_string_width(linkedin_text)
    email_w = pdf.get_string_width(email_text)
    sep_w = pdf.get_string_width(separator)

    total_w = github_w + sep_w + linkedin_w + sep_w + email_w
    start_x = (210 - total_w) / 2

    pdf.set_x(start_x)
    pdf.cell(github_w, 5, github_text, link="https://github.com/colemanwhaylon")
    pdf.set_text_color(80, 80, 80)
    pdf.cell(sep_w, 5, separator)
    pdf.set_text_color(41, 98, 166)
    pdf.cell(linkedin_w, 5, linkedin_text, link="https://www.linkedin.com/in/anitconsultant/")
    pdf.set_text_color(80, 80, 80)
    pdf.cell(sep_w, 5, separator)
    pdf.set_text_color(41, 98, 166)
    pdf.cell(email_w, 5, email_text, link="mailto:colemanwhaylon@yahoo.com")
    pdf.ln(6)

    # The Path to Blockchain
    pdf.set_font("Helvetica", "BU", 12)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "The Path to Blockchain", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(40, 40, 40)
    text1 = "My journey into blockchain began where most meaningful technical pivots start: at the intersection of a complex problem and an elegant solution waiting to be discovered. After two decades architecting enterprise applications across financial services, healthcare, and supply chain domains, I recognized that blockchain technology wasn't just another tool in the toolkit. It represented a fundamental shift in how we think about trust, transparency, and the movement of value across systems. The transition felt natural. Years of designing distributed systems, implementing cryptographic security patterns, and building infrastructure that financial institutions depend on had prepared me for this moment."
    pdf.multi_cell(0, 5, text1, align='J')
    pdf.ln(3)

    # Building Enterprise-Grade Blockchain Infrastructure
    pdf.set_font("Helvetica", "BU", 12)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "Building Enterprise-Grade Blockchain Infrastructure", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(40, 40, 40)
    text2 = "Over the past several years, I've dedicated myself to mastering the complete ecosystem: consensus mechanisms, tokenization standards, regulatory frameworks, and the operational realities of deploying blockchain solutions where failure isn't an option. I've evaluated protocols including Ethereum, Polygon, Hyperledger, and Canton based on specific product requirements. This commitment culminated in four production applications and over 12 smart contracts with 100% test coverage. Nexus Protocol serves as my flagship project, implementing DeFi staking with slashing mechanisms, NFT minting, on-chain governance, ERC-1400 security tokens, KYC/AML integration, and meta-transaction relayers. One significant challenge I tackled was implementing gasless transactions for users unfamiliar with crypto wallets, solving it through an ERC-2771 meta-transaction relayer that reduced onboarding friction by 80%."
    pdf.multi_cell(0, 5, text2, align='J')
    pdf.ln(3)

    # Smart Contract Security Engineering
    pdf.set_font("Helvetica", "BU", 12)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "Smart Contract Security Engineering", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(40, 40, 40)
    text3 = "My security engineering practice centers on defense-in-depth: every contract undergoes static analysis with Slither, property-based fuzzing with Echidna across 50,000 test sequences, and formal verification with Certora. I've implemented production-grade staking contracts with 7-day unbonding queues, proportional slashing mechanisms with 30-day cooldowns, and streaming reward distribution with Merkle-based replay prevention. The NexusStaking contract (875 lines) demonstrates unbonding queue management, daily withdrawal limits (10% cap), epoch-based processing, and treasury-integrated slashing. The Time-Lock-Wallet implements CEI pattern, ReentrancyGuard, and guardian recovery mechanisms with N-of-M multi-signature governance. These patterns directly mirror the security requirements for restaking protocol infrastructure protecting significant TVL."
    pdf.multi_cell(0, 5, text3, align='J')
    pdf.ln(3)

    # Security Tooling & Verification
    pdf.set_font("Helvetica", "BU", 12)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "Security Tooling & Verification", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(40, 40, 40)
    text4 = "I build and maintain security tooling pipelines that catch vulnerabilities before deployment. My Echidna configurations test 6 invariant properties with coverage-guided mutation, achieving 98.5% line coverage and 95.2% branch coverage across 3,500+ lines of Solidity. Certora formal verification specs validate critical properties including slashing bounds and unbonding timing constraints. I've developed custom Slither detectors for domain-specific vulnerabilities and maintain comprehensive test suites spanning unit, fuzz, invariant, and fork testing. My full-stack proficiency includes Go backends (Gin framework), Rust CLI tools, and React/Next.js frontends, enabling me to architect complete solutions spanning smart contracts, database schemas, and user interfaces while ensuring security consistency across every layer."
    pdf.multi_cell(0, 5, text4, align='J')
    pdf.ln(3)

    # The Eigen Labs Opportunity
    pdf.set_font("Helvetica", "BU", 12)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "The Eigen Labs Opportunity", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(40, 40, 40)
    text5 = "EigenLayer's restaking infrastructure represents the frontier of Ethereum security, and protecting billions in restaked ETH demands exactly the security engineering discipline I've built across four production-grade blockchain applications. My experience implementing staking contracts with slashing mechanisms, reward distribution with replay-proof Merkle claims, and time-locked withdrawal queues directly maps to EigenPods and AVS security requirements. I'm drawn to Eigen Labs' builder-driven culture and the challenge of securing infrastructure where vulnerabilities could impact not just one protocol but the entire restaking ecosystem. I'm eager to bring my formal verification pipelines, fuzzing infrastructure, and security-first engineering approach to strengthen EigenLayer's protocol security."
    pdf.multi_cell(0, 5, text5, align='J')

    # ============ PAGE 2: FULL MAPPING TABLES + PORTFOLIO ============
    pdf.add_page()
    pdf.set_y(10)

    # Core Responsibilities Header
    pdf.set_font("Helvetica", "B", 13)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "Core Responsibilities Mapping", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    pdf.set_font("Helvetica", "I", 7)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 3, "Eigen Labs Job Requirements Mapped to Demonstrated Implementations", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
    pdf.ln(1)

    # Core Responsibilities Table (10 rows, 4 columns)
    col_widths = [42, 68, 28, 42]  # Requirement, Implementation, Project, Evidence
    row_height = 5.5
    table_width = sum(col_widths)
    start_x = (210 - table_width) / 2

    pdf.set_x(start_x)

    # Header row
    pdf.set_font("Helvetica", "B", 6)
    pdf.set_fill_color(41, 98, 166)
    pdf.set_text_color(255, 255, 255)
    headers = ["Eigen Labs Requirement", "Your Demonstrated Implementation", "Project", "Evidence File"]
    for i, header in enumerate(headers):
        pdf.cell(col_widths[i], row_height, header, border=1, align='C', fill=True)
    pdf.ln(row_height)

    # Data rows
    pdf.set_font("Helvetica", "", 5)
    pdf.set_text_color(40, 40, 40)

    # GitHub base URLs
    NEXUS_BLOB = "https://github.com/colemanwhaylon/nexus-protocol/blob/main/"
    NEXUS_TREE = "https://github.com/colemanwhaylon/nexus-protocol/tree/main/"

    def get_github_url(evidence, is_directory=False):
        """Convert evidence path to GitHub URL for nexus-protocol repo"""
        first_path = evidence.split(",")[0].strip()

        # Handle line number references (e.g., :520-552)
        if ":" in first_path:
            parts = first_path.rsplit(":", 1)
            if len(parts) == 2 and parts[1].replace("-", "").isdigit():
                path = parts[0]
                lines = parts[1]
                if "-" in lines:
                    start, end = lines.split("-")
                    line_anchor = f"#L{start}-L{end}"
                else:
                    line_anchor = f"#L{lines}"
                return NEXUS_BLOB + path + line_anchor

        # Use tree for directories, blob for files
        base = NEXUS_TREE if is_directory else NEXUS_BLOB
        return base + first_path

    # Core data with link flag: (requirement, implementation, project, evidence, has_link, is_directory)
    core_data = [
        ("Lead security reviews of staking contracts", "NexusStaking.sol: 875 LOC with 7-day unbonding, 10% daily withdrawal limits, epoch-based processing", "Nexus Protocol", "contracts/src/defi/NexusStaking.sol", True, False),
        ("Lead security reviews of slashing contracts", "Proportional slashing (max 50%), 30-day cooldown, 1,000-token minimum threshold, treasury integration", "Nexus Protocol", "contracts/src/defi/NexusStaking.sol:520-552", True, False),
        ("Lead security reviews of reward distribution", "RewardsDistributor.sol: 1,076 LOC with streaming + Merkle campaigns, rate limiting, dust tracking", "Nexus Protocol", "contracts/src/defi/RewardsDistributor.sol", True, False),
        ("Develop security tooling & fuzzers", "Echidna config (50,000 sequences), 6 invariant properties, Foundry fuzz tests (100,000 runs)", "Nexus Protocol", "contracts/echidna/echidna.yaml", True, False),
        ("Formal verification pipelines", "Certora specs framework, Slither v0.10.0, Aderyn custom rules, Mythril bytecode analysis", "Nexus Protocol", "documentation/SECURITY_AUDIT.md", True, False),
        ("Deep EVM comprehension", "Gas optimization patterns, assembly snippets, storage layout awareness", "Nexus Protocol", "documentation/GAS_OPTIMIZATION.md", True, False),
        ("Common vulnerabilities expertise", "Reentrancy (CEI pattern), overflow protection, access control, time-lock mechanisms", "Time-Lock-Wallet", "contracts/TimeLockWallet.sol", False, False),  # No link - repo not on GitHub
        ("Hardhat & Foundry experience", "Foundry for Nexus (forge test), Hardhat for Time-Lock-Wallet + DIP", "Nexus Protocol", "contracts/foundry.toml", True, False),
        ("Testing frameworks expertise", "Unit (98.5% coverage), Fuzz, Invariant, Fork, Integration, E2E (Playwright)", "Nexus Protocol", "contracts/test/unit", True, True),  # Directory
        ("Production deployment with audits", "Self-audit (Trail of Bits format), 0 Critical/High findings, testnet deployments", "Nexus Protocol", "documentation/SECURITY_AUDIT.md", True, False),
    ]

    for row_idx, (requirement, implementation, project, evidence, has_link, is_dir) in enumerate(core_data):
        pdf.set_x(start_x)
        if row_idx % 2 == 0:
            pdf.set_fill_color(245, 245, 245)
        else:
            pdf.set_fill_color(255, 255, 255)

        pdf.cell(col_widths[0], row_height, requirement, border=1, align='L', fill=True)
        pdf.cell(col_widths[1], row_height, implementation, border=1, align='L', fill=True)
        pdf.cell(col_widths[2], row_height, project, border=1, align='C', fill=True)

        # Evidence cell - clickable link if has_link is True, otherwise plain text
        pdf.set_font("Helvetica", "I", 4.5)
        if has_link:
            pdf.set_text_color(41, 98, 166)  # Blue for links
            github_url = get_github_url(evidence, is_dir)
            pdf.cell(col_widths[3], row_height, evidence, border=1, align='L', fill=True, link=github_url)
        else:
            pdf.set_text_color(40, 40, 40)  # Dark gray for plain text
            pdf.cell(col_widths[3], row_height, evidence, border=1, align='L', fill=True)
        pdf.set_text_color(40, 40, 40)  # Reset
        pdf.set_font("Helvetica", "", 5)
        pdf.ln(row_height)

    pdf.ln(4)

    # Secondary Skills Header
    pdf.set_font("Helvetica", "B", 13)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 6, "Secondary Skills Mapping", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    pdf.set_font("Helvetica", "I", 7)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 3, "Nice-to-Have Skills with Demonstrated Implementations", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
    pdf.ln(1)

    # Secondary Skills Table (9 rows, 3 columns)
    col_widths_sec = [50, 85, 35]
    row_height_sec = 5.5
    table_width_sec = sum(col_widths_sec)
    start_x_sec = (210 - table_width_sec) / 2

    pdf.set_x(start_x_sec)

    # Header row
    pdf.set_font("Helvetica", "B", 6)
    pdf.set_fill_color(41, 98, 166)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(col_widths_sec[0], row_height_sec, "Eigen Labs Nice-to-Have", border=1, align='C', fill=True)
    pdf.cell(col_widths_sec[1], row_height_sec, "Your Implementation", border=1, align='C', fill=True)
    pdf.cell(col_widths_sec[2], row_height_sec, "Project", border=1, align='C', fill=True)
    pdf.ln(row_height_sec)

    # Data rows
    pdf.set_font("Helvetica", "", 5)
    pdf.set_text_color(40, 40, 40)

    secondary_data = [
        ("Significant TVL protocol experience", "Nexus demonstrates institutional-grade patterns for high-value protocols", "Nexus Protocol"),
        ("Smart contract audits", "Self-audit report + SECURITY_REVIEW_BEFORE/AFTER methodology", "Nexus Protocol"),
        ("Formal verification", "Certora Prover v5.0 integration", "Nexus Protocol"),
        ("Validator/node management", "Documented in ARCHITECTURE.md", "Nexus Protocol"),
        ("Wallet security", "Non-custodial Time-Lock-Wallet with guardian recovery", "Time-Lock-Wallet"),
        ("Key management", "HSM/MPC patterns documentation, recovery address separation", "Time-Lock-Wallet + Nexus"),
        ("Cryptography familiarity", "Merkle proofs, EIP-712 signatures, ERC-2771 meta-transactions", "Nexus + DIP"),
        ("Full-stack development", "Go backend, React/Next.js frontend, .NET 10 Blazor", "All Projects"),
        ("Open-source contributions", "All 4 projects are open-source portfolio pieces", "All Projects"),
    ]

    for row_idx, (nice_to_have, implementation, project) in enumerate(secondary_data):
        pdf.set_x(start_x_sec)
        if row_idx % 2 == 0:
            pdf.set_fill_color(245, 245, 245)
        else:
            pdf.set_fill_color(255, 255, 255)

        pdf.cell(col_widths_sec[0], row_height_sec, nice_to_have, border=1, align='L', fill=True)
        pdf.cell(col_widths_sec[1], row_height_sec, implementation, border=1, align='L', fill=True)
        pdf.cell(col_widths_sec[2], row_height_sec, project, border=1, align='C', fill=True)
        pdf.ln(row_height_sec)

    pdf.ln(8)

    # Portfolio Section Header
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "Enterprise Security Portfolio", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 4, "4 Production Applications", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
    pdf.ln(2)

    # Screenshots - 2x2 grid with larger images
    screenshot_dir = Path("/home/whaylon/Downloads/Blockchain/nexus-protocol/documentation/screenshots")

    img_width = 70
    img_height = 40
    h_spacing = 12
    v_spacing = 14  # vertical spacing between rows (includes text)
    total_width = (img_width * 2) + h_spacing
    start_x = (210 - total_width) / 2

    y_pos = pdf.get_y()

    # Portfolio data - 4 apps in 2x2 grid
    screenshots = [
        ("nexus-protocol.png", "Nexus Protocol", "DeFi | Governance | Security Tokens", "nexus.dapp.academy"),
        ("dip.png", "Decentralized Insurance", "Risk Pools | Claims | Settlement", "dip.dapp.academy"),
        ("pharmachain.png", "PharmaChain", "Supply Chain | Compliance | Provenance", "pharmachain.dapp.academy"),
        ("timelock-wallet.png", "Time-Lock Wallet", "Multi-Sig | Guardian | Recovery", "Coming Soon"),
    ]

    for i, (img_file, title, subtitle, url) in enumerate(screenshots):
        row = i // 2  # 0 for first row, 1 for second row
        col = i % 2   # 0 for left, 1 for right

        x_pos = start_x + (col * (img_width + h_spacing))
        y_img = y_pos + (row * (img_height + v_spacing))

        img_path = screenshot_dir / img_file

        if img_path.exists():
            pdf.image(str(img_path), x=x_pos, y=y_img, w=img_width, h=img_height)

        # Title under image
        pdf.set_xy(x_pos, y_img + img_height + 1)
        pdf.set_font("Helvetica", "B", 8)
        pdf.set_text_color(0, 0, 0)
        pdf.cell(img_width, 3, title, align='C')

        # Subtitle
        pdf.set_xy(x_pos, y_img + img_height + 4.5)
        pdf.set_font("Helvetica", "", 6)
        pdf.set_text_color(80, 80, 80)
        pdf.cell(img_width, 3, subtitle, align='C')

        # URL link
        pdf.set_xy(x_pos, y_img + img_height + 8)
        pdf.set_font("Helvetica", "", 7)
        pdf.set_text_color(41, 98, 166)
        if url != "Coming Soon":
            pdf.cell(img_width, 3, url, align='C', link=f"https://{url}")
        else:
            pdf.set_text_color(100, 100, 100)
            pdf.cell(img_width, 3, url, align='C')

    # Move to below 2x2 grid (2 rows of images + text)
    pdf.set_y(y_pos + (img_height + v_spacing) * 2 + 2)

    # Skills link
    pdf.set_font("Helvetica", "", 7)
    pdf.set_text_color(80, 80, 80)
    skills_text = "For a detailed breakdown of 46 demonstrated skills built specifically for this opportunity: "
    pdf.cell(0, 3, skills_text, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    pdf.set_text_color(41, 98, 166)
    pdf.set_font("Helvetica", "B", 7)
    pdf.cell(0, 3, "nexus.dapp.academy/about", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C', link="https://nexus.dapp.academy/about")

    # Output
    output_path = Path("/home/whaylon/Downloads/Blockchain/nexus-protocol/documentation/Whaylon_Coleman_Blockchain_Experience_EigenLabs.pdf")
    pdf.output(str(output_path))
    print(f"PDF generated: {output_path}")
    print(f"Final Y position: {pdf.get_y()}")
    print(f"Total pages: {pdf.page_no()}")
    return output_path

if __name__ == "__main__":
    create_pdf()
