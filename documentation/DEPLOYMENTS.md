# Nexus Protocol - Deployed Smart Contracts

This document contains all deployed smart contract addresses for the Nexus Protocol platform.

## Network: Sepolia Testnet (Chain ID: 11155111)

Deployed on: January 5, 2025

### Core Contracts

| Contract | Address | Etherscan | Description |
|----------|---------|-----------|-------------|
| **NexusToken** | `0xc495a8ecd63daa5282a4ff3ba58a177b34a36e9e` | [View](https://sepolia.etherscan.io/address/0xc495a8ecd63daa5282a4ff3ba58a177b34a36e9e) | ERC-20 governance token with Snapshot, Permit, Votes, and FlashMint |
| **NexusNFT** | `0x1616ff52b872a343a9ae0766184245f380c99913` | [View](https://sepolia.etherscan.io/address/0x1616ff52b872a343a9ae0766184245f380c99913) | ERC-721A NFT with royalties, reveal mechanism, and soulbound options |
| **NexusStaking** | `0xe0bca60673b3a0e03beb7750b8bb8d085513a4e3` | [View](https://sepolia.etherscan.io/address/0xe0bca60673b3a0e03beb7750b8bb8d085513a4e3) | Stake/unstake with slashing and delegation support |

### Governance Contracts

| Contract | Address | Etherscan | Description |
|----------|---------|-----------|-------------|
| **NexusGovernor** | `0x4fda98c98f9bfcd524e337ede8f2dd90ed409fec` | [View](https://sepolia.etherscan.io/address/0x4fda98c98f9bfcd524e337ede8f2dd90ed409fec) | OpenZeppelin Governor pattern for on-chain governance |
| **NexusTimelock** | `0xbc6ebc67c6facde8977f64211b7f9bd2e5907375` | [View](https://sepolia.etherscan.io/address/0xbc6ebc67c6facde8977f64211b7f9bd2e5907375) | 48-hour execution delay for governance proposals |

### Security & Access Control Contracts

| Contract | Address | Etherscan | Description |
|----------|---------|-----------|-------------|
| **NexusAccessControl** | `0xb2afde15a49b715d6ad5f13e994562d499c2c1cd` | [View](https://sepolia.etherscan.io/address/0xb2afde15a49b715d6ad5f13e994562d499c2c1cd) | Role-based access control (ADMIN, OPERATOR, COMPLIANCE, PAUSER) |
| **NexusKYCRegistry** | `0xc351675376a65cdeba593ff802beeaebb85ff68f` | [View](https://sepolia.etherscan.io/address/0xc351675376a65cdeba593ff802beeaebb85ff68f) | Whitelist/blacklist management for compliance |
| **NexusEmergency** | `0x6009e5e04a07acf8acdb003b671c7cad34355057` | [View](https://sepolia.etherscan.io/address/0x6009e5e04a07acf8acdb003b671c7cad34355057) | Circuit breakers and pause controls |

### Infrastructure Contracts

| Contract | Address | Etherscan | Description |
|----------|---------|-----------|-------------|
| **NexusForwarder** | `0x88b8bb0f0f712b49b274025e9ac4657bc4db036d` | [View](https://sepolia.etherscan.io/address/0x88b8bb0f0f712b49b274025e9ac4657bc4db036d) | Meta-transaction forwarder for gasless transactions |

## Verification Status

All contracts are verified on Sepolia Etherscan. Source code is available for review directly on the block explorer.

## Technology Stack

- **Framework**: Foundry (forge, cast, anvil)
- **Solidity Version**: 0.8.24
- **Dependencies**: OpenZeppelin Contracts v5.x, ERC-721A
- **Security**: Slither static analysis, Echidna fuzzing, custom Aderyn rules

## Repository

- **Source Code**: [github.com/colemanwhaylon/nexus-protocol](https://github.com/colemanwhaylon/nexus-protocol)
- **Contracts Directory**: [`/contracts/src/`](https://github.com/colemanwhaylon/nexus-protocol/tree/main/contracts/src)
