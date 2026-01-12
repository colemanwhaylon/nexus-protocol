#!/usr/bin/env python3
"""Generate Whaylon Coleman Blockchain Experience PDF for Fidelity Labs"""

from fpdf import FPDF
from fpdf.enums import XPos, YPos
from pathlib import Path

class BlockchainExperiencePDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=False)

def create_pdf():
    pdf = BlockchainExperiencePDF()
    pdf.add_page()
    pdf.set_margins(18, 10, 18)
    pdf.set_y(10)

    # Title
    pdf.set_font("Helvetica", "B", 20)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 9, "My Journey in Blockchain and Digital Assets", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    # Subtitle
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 4, "Whaylon Coleman  |  Principal Software Architect  |  25+ Years in Enterprise Software", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    # LinkedIn link line
    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(41, 98, 166)
    pdf.cell(0, 4, "linkedin.com/in/anitconsultant", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C', link="https://www.linkedin.com/in/anitconsultant/")
    pdf.ln(2)

    # The Path to Blockchain
    pdf.set_font("Helvetica", "BU", 10)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "The Path to Blockchain", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(40, 40, 40)
    text1 = "My journey into blockchain began where most meaningful technical pivots start: at the intersection of a complex problem and an elegant solution waiting to be discovered. After two decades architecting enterprise applications across financial services, healthcare, and supply chain domains, I recognized that blockchain technology wasn't just another tool in the toolkit. It represented a fundamental shift in how we think about trust, transparency, and the movement of value across systems. The transition felt natural. Years of designing distributed systems, implementing cryptographic security patterns, and building infrastructure that financial institutions depend on had prepared me for this moment."
    pdf.multi_cell(0, 3.8, text1, align='J')
    pdf.ln(1.5)

    # Building Enterprise-Grade Blockchain Infrastructure
    pdf.set_font("Helvetica", "BU", 10)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "Building Enterprise-Grade Blockchain Infrastructure", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(40, 40, 40)
    text2 = "Over the past several years, I've dedicated myself to mastering the complete ecosystem: consensus mechanisms, tokenization standards, regulatory frameworks, and the operational realities of deploying blockchain solutions where failure isn't an option. I've evaluated protocols including Ethereum, Polygon, Hyperledger, and Canton based on specific product requirements. This commitment culminated in three production applications and over 12 smart contracts with 100% test coverage. Nexus Protocol serves as my flagship project, implementing DeFi staking, NFT minting, on-chain governance, ERC-1400 security tokens, KYC/AML integration, and meta-transaction relayers. One significant challenge I tackled was implementing gasless transactions for users unfamiliar with crypto wallets, solving it through an ERC-2771 meta-transaction relayer that reduced onboarding friction by 80%. The Decentralized Insurance Platform explores risk management through community-driven pools. PharmaChain addresses supply chain provenance in regulated industries."
    pdf.multi_cell(0, 3.8, text2, align='J')
    pdf.ln(1.5)

    # Technical Philosophy and Compliance
    pdf.set_font("Helvetica", "BU", 10)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "Technical Philosophy and Compliance", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(40, 40, 40)
    text3 = "Enterprise blockchain development requires a different mindset than typical Web3 projects. When institutions stake their reputation on your infrastructure, security cannot be an afterthought. Every contract I write undergoes static analysis with Slither, fuzz testing with Echidna, and formal verification with Certora. Deep familiarity with ERC-20, ERC-721, ERC-721A, and ERC-1400 allows me to select the right standard for each use case, particularly for tokenized securities requiring Delivery versus Payment (DvP) settlement workflows. I've partnered closely with compliance stakeholders to navigate regulatory frameworks, implementing KYC/AML whitelists, transfer restrictions, and comprehensive audit trails that satisfy institutional requirements. I stay current with emerging standards and evolving regulatory guidance to ensure our technology decisions remain forward-looking."
    pdf.multi_cell(0, 3.8, text3, align='J')
    pdf.ln(1.5)

    # Full-Stack Development & Cloud-Native Architecture
    pdf.set_font("Helvetica", "BU", 10)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "Full-Stack Development & Cloud-Native Architecture", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(40, 40, 40)
    text4 = "My technical depth spans the entire modern stack. On the backend, I build high-performance APIs in Go (Gin framework), write Rust CLI tools for blockchain interactions, and develop Python automation scripts for deployment pipelines and data processing. For frontend development, I leverage TypeScript, React, and Next.js to create responsive, user-centric interfaces that abstract blockchain complexity from end users. My AWS experience includes designing containerized microservices deployed via ECS and EKS, implementing API Gateway patterns, managing infrastructure as code with Terraform, and building CI/CD pipelines with GitHub Actions. I've architected data systems using PostgreSQL with sophisticated ORM patterns, integrated Elasticsearch for analytics and search, and designed event-driven architectures that scale horizontally. This full-stack proficiency enables me to architect complete solutions spanning smart contracts, database schemas, and user interfaces while ensuring consistency across every layer."
    pdf.multi_cell(0, 3.8, text4, align='J')
    pdf.ln(1.5)

    # The Fidelity Labs Opportunity
    pdf.set_font("Helvetica", "BU", 10)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "The Fidelity Labs Opportunity", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(40, 40, 40)
    text5 = "Greenfield projects at the intersection of traditional finance and DeFi represent the most exciting frontier in our industry, and Fidelity Labs' commitment to building customer-facing digital asset products aligns perfectly with my experience and passion. I thrive in startup-like environments where rapid prototyping, iterative validation, and technical ownership drive innovation. My background building production-grade DeFi infrastructure, including staking mechanisms, governance systems, token economics, and secure wallet integrations, combined with 25 years of enterprise software discipline means I can move fast without sacrificing the reliability that Fidelity's brand demands. I'm drawn to teams that value curiosity and collaboration, where engineers have a voice in shaping both product direction and technical architecture. I'm eager to bring my experience architecting scalable blockchain solutions, mentoring engineering teams, and translating complex DeFi concepts into intuitive user experiences to help Fidelity Labs define the next generation of digital asset products."
    pdf.multi_cell(0, 3.8, text5, align='J')
    pdf.ln(3)

    # Portfolio Section Header
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 5, "Enterprise Blockchain Portfolio", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    # Sub-header
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 4, "3 DeFi Applications", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
    pdf.ln(1)

    # Screenshots
    screenshot_dir = Path("/home/whaylon/Downloads/Blockchain/nexus-protocol/documentation/screenshots")

    img_width = 52
    img_height = 30
    spacing = 9
    total_width = (img_width * 3) + (spacing * 2)
    start_x = (210 - total_width) / 2

    y_pos = pdf.get_y()

    # Portfolio data
    screenshots = [
        ("nexus-protocol.png", "Nexus Protocol", "DeFi | Governance | Security Tokens", "nexus.dapp.academy"),
        ("dip.png", "Decentralized Insurance", "Risk Pools | Claims | Settlement", "dip.dapp.academy"),
        ("pharmachain.png", "PharmaChain", "Supply Chain | Compliance | Provenance", "pharmachain.dapp.academy"),
    ]

    for i, (img_file, title, subtitle, url) in enumerate(screenshots):
        x_pos = start_x + (i * (img_width + spacing))
        img_path = screenshot_dir / img_file

        if img_path.exists():
            pdf.image(str(img_path), x=x_pos, y=y_pos, w=img_width, h=img_height)

        # Title under image
        pdf.set_xy(x_pos, y_pos + img_height + 1)
        pdf.set_font("Helvetica", "B", 8)
        pdf.set_text_color(0, 0, 0)
        pdf.cell(img_width, 3, title, align='C')

        # Subtitle
        pdf.set_xy(x_pos, y_pos + img_height + 4)
        pdf.set_font("Helvetica", "", 6)
        pdf.set_text_color(80, 80, 80)
        pdf.cell(img_width, 3, subtitle, align='C')

        # URL link
        pdf.set_xy(x_pos, y_pos + img_height + 7)
        pdf.set_font("Helvetica", "", 7)
        pdf.set_text_color(41, 98, 166)
        pdf.cell(img_width, 3, url, align='C', link=f"https://{url}")

    # Move to below screenshots
    pdf.set_y(y_pos + img_height + 12)
    pdf.ln(1)

    # Skills link
    pdf.set_font("Helvetica", "", 7)
    pdf.set_text_color(80, 80, 80)
    skills_text = "For a detailed breakdown of 46 demonstrated skills built specifically for this opportunity: "
    pdf.cell(0, 3, skills_text, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    pdf.set_text_color(41, 98, 166)
    pdf.set_font("Helvetica", "B", 7)
    pdf.cell(0, 3, "nexus.dapp.academy/about", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C', link="https://nexus.dapp.academy/about")

    pdf.ln(1)

    # Footer links - centered with clickable hyperlinks
    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(41, 98, 166)

    # Calculate positioning for centered footer
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
    pdf.cell(github_w, 4, github_text, link="https://github.com/colemanwhaylon")
    pdf.set_text_color(80, 80, 80)
    pdf.cell(sep_w, 4, separator)
    pdf.set_text_color(41, 98, 166)
    pdf.cell(linkedin_w, 4, linkedin_text, link="https://www.linkedin.com/in/anitconsultant/")
    pdf.set_text_color(80, 80, 80)
    pdf.cell(sep_w, 4, separator)
    pdf.set_text_color(41, 98, 166)
    pdf.cell(email_w, 4, email_text, link="mailto:colemanwhaylon@yahoo.com")

    # Output
    output_path = Path("/home/whaylon/Downloads/Blockchain/nexus-protocol/documentation/Whaylon_Coleman_Blockchain_Experience_Fidelity.pdf")
    pdf.output(str(output_path))
    print(f"PDF generated: {output_path}")
    print(f"Final Y position: {pdf.get_y()}")
    return output_path

if __name__ == "__main__":
    create_pdf()
