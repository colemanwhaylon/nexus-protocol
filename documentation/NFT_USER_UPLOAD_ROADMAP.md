# NFT User Upload & Marketplace Roadmap

> **Status**: Planned (Post-Governance)
> **Priority**: High
> **Created**: 2026-01-04

---

## Current State

The NFT system currently operates as a **pre-generated collection** model (similar to BAYC, CryptoPunks):

| Feature | Status | Notes |
|---------|--------|-------|
| Mint from collection | ✅ Complete | Users mint from pre-made set |
| NFT Gallery display | ✅ Complete | Shows owned NFTs with images |
| NFT Detail page | ✅ Complete | Metadata, attributes, transfer |
| Transfer NFTs | ✅ Complete | P2P transfers working |
| Royalties (ERC-2981) | ✅ Built-in | Contract supports on-chain royalties |
| Placeholder images | ✅ Complete | 20 SVG images with AnIT brand colors |
| Metadata serving | ✅ Complete | JSON metadata at `/metadata/*.json` |

### Technical Implementation

- **Contract**: `NexusNFT.sol` using ERC721A (gas-efficient batch minting)
- **Metadata**: Static files in `/frontend/public/metadata/`
- **Images**: SVG files in `/frontend/public/metadata/images/`
- **BaseURI**: `http://localhost:3000/metadata/` (configured via `setBaseURI`)

---

## Gap Analysis

For a **user-generated NFT platform** (like OpenSea, Rarible), the following features are missing:

### 1. User Image Upload (Backend)

```
Current:  Admin pre-generates all images
Needed:   Users upload their own artwork
```

**Requirements:**
- File upload API endpoint (`POST /api/nft/upload`)
- File type validation (PNG, JPG, GIF, SVG, MP4)
- File size limits (e.g., 50MB max)
- Image optimization/thumbnailing
- Temporary storage before IPFS pinning

### 2. IPFS/Decentralized Storage

```
Current:  Images served from Next.js public folder (centralized)
Needed:   Content-addressed storage on IPFS (decentralized)
```

**Options:**
| Provider | Pros | Cons |
|----------|------|------|
| Pinata | Easy API, reliable | Paid after free tier |
| NFT.Storage | Free, Filecoin-backed | Rate limits |
| Infura IPFS | Enterprise-grade | Paid |
| Self-hosted IPFS | Full control | Infrastructure overhead |

**Implementation:**
- Pin uploaded image to IPFS → get CID
- Generate metadata JSON with IPFS image URI
- Pin metadata to IPFS → get metadata CID
- Use `ipfs://` URI as tokenURI

### 3. Dynamic Metadata Generation

```
Current:  Pre-generated JSON files (1.json, 2.json, etc.)
Needed:   On-demand metadata creation per user upload
```

**Metadata Structure:**
```json
{
  "name": "User's Custom NFT",
  "description": "User-provided description",
  "image": "ipfs://QmXxx.../image.png",
  "attributes": [
    { "trait_type": "Creator", "value": "0xUser..." },
    { "trait_type": "Created", "value": "2026-01-04" }
  ]
}
```

### 4. Modified Minting Flow

```
Current Flow:
  User → Click Mint → Get random NFT from collection

Needed Flow:
  User → Upload Image → Add Details → Preview → Mint Custom NFT
```

**New Minting Steps:**
1. User uploads image file
2. Backend pins image to IPFS
3. User fills in name, description, attributes
4. Backend generates metadata JSON
5. Backend pins metadata to IPFS
6. Frontend calls `mint(tokenURI)` with IPFS metadata URI
7. Contract mints with custom tokenURI

### 5. Marketplace Features

```
Current:  Transfer only (P2P gifting)
Needed:   Full marketplace (list, buy, sell, auction)
```

**Marketplace Components:**

| Feature | Description | Contract Changes |
|---------|-------------|------------------|
| Listings | List NFT for fixed price | New `NexusMarketplace.sol` |
| Buying | Purchase listed NFTs | Escrow + transfer logic |
| Offers | Make offers on any NFT | Offer management |
| Auctions | Time-limited bidding | Auction contract |
| Royalties | Creator fees on resale | ERC-2981 integration |
| Collection Offers | Bid on any NFT in collection | Floor price mechanics |

---

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND                              │
│  Upload Page → Preview → Mint                                │
│  Marketplace → Browse → Buy/Sell                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        BACKEND API                           │
│  POST /api/nft/upload     → Accept image, return temp ID     │
│  POST /api/nft/pin        → Pin to IPFS, return CID          │
│  POST /api/nft/metadata   → Generate & pin metadata          │
│  GET  /api/marketplace/*  → Listings, offers, history        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     STORAGE LAYER                            │
│  PostgreSQL: Listings, offers, user data                     │
│  IPFS (Pinata): Images, metadata                             │
│  Redis: Caching, rate limiting                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     SMART CONTRACTS                          │
│  NexusNFT.sol        → Minting with custom tokenURI          │
│  NexusMarketplace.sol → Listings, sales, royalties           │
│  NexusAuction.sol    → Time-based auctions                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: User Upload + IPFS (MVP)
- [ ] Add Pinata/NFT.Storage integration to backend
- [ ] Create upload API endpoint
- [ ] Create metadata generation endpoint
- [ ] Modify mint page for custom uploads
- [ ] Update NexusNFT to accept custom tokenURI per mint

### Phase 2: Basic Marketplace
- [ ] Create NexusMarketplace.sol contract
- [ ] Implement fixed-price listings
- [ ] Implement buy functionality
- [ ] Add marketplace UI pages
- [ ] Integrate royalty payments

### Phase 3: Advanced Features
- [ ] Auction system
- [ ] Collection offers
- [ ] Activity feeds
- [ ] Creator profiles
- [ ] Collection pages

---

## Contract Modifications Needed

### NexusNFT.sol Changes

Current `publicMint` only increments tokenId:
```solidity
function publicMint(uint256 quantity) external payable {
    // Mints sequential tokenIds
    _mint(msg.sender, quantity);
}
```

Need new function for custom URI:
```solidity
function mintWithURI(string calldata _tokenURI) external payable {
    uint256 tokenId = _nextTokenId();
    _mint(msg.sender, 1);
    _tokenURIs[tokenId] = _tokenURI;  // Custom URI storage
}
```

### New NexusMarketplace.sol

```solidity
contract NexusMarketplace {
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;

    function listNFT(uint256 tokenId, uint256 price) external;
    function buyNFT(uint256 tokenId) external payable;
    function cancelListing(uint256 tokenId) external;
}
```

---

## Dependencies

| Dependency | Purpose | Status |
|------------|---------|--------|
| Pinata SDK | IPFS pinning | Not installed |
| sharp | Image optimization | Not installed |
| multer | File upload handling | Not installed |

---

## References

- [ERC-721 Metadata Standard](https://eips.ethereum.org/EIPS/eip-721)
- [IPFS Documentation](https://docs.ipfs.tech/)
- [Pinata API Docs](https://docs.pinata.cloud/)
- [OpenSea Metadata Standards](https://docs.opensea.io/docs/metadata-standards)

---

## Next Steps

1. Complete Governance module first
2. Return to this roadmap
3. Start with Phase 1 (User Upload + IPFS)
4. Test on Anvil before testnet deployment
