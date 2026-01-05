// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { NexusToken } from "../src/core/NexusToken.sol";
import { NexusStaking } from "../src/defi/NexusStaking.sol";
import { NexusNFT } from "../src/core/NexusNFT.sol";
import { NexusKYCRegistry } from "../src/security/NexusKYCRegistry.sol";

/**
 * @title InitializeLocal
 * @notice Initializes ALL contracts after deployment for immediate use
 * @dev Run AFTER DeployLocal.s.sol and post_deploy.py
 *      This script reads contract addresses from environment variables set by the caller
 *
 * Required env vars (set by dev-setup.sh from database API):
 *   - NEXUS_TOKEN_ADDRESS
 *   - NEXUS_NFT_ADDRESS
 *   - NEXUS_KYC_ADDRESS
 *
 * Usage: forge script script/InitializeLocal.s.sol --rpc-url http://localhost:8545 --broadcast
 */
contract InitializeLocal is Script {
    // Anvil's first test account
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        // Use Anvil's first private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        // Read addresses from environment (set by dev-setup.sh)
        address tokenAddress = vm.envAddress("NEXUS_TOKEN_ADDRESS");
        address nftAddress = vm.envAddress("NEXUS_NFT_ADDRESS");
        address kycAddress = vm.envAddress("NEXUS_KYC_ADDRESS");

        console.log("\n========================================");
        console.log("       INITIALIZING CONTRACTS");
        console.log("========================================");
        console.log("Token:", tokenAddress);
        console.log("NFT:", nftAddress);
        console.log("KYC:", kycAddress);
        console.log("========================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // ============ Token Initialization ============
        NexusToken token = NexusToken(tokenAddress);

        // 1. Self-delegate to enable voting power for governance
        console.log("Delegating voting power to self...");
        token.delegate(DEPLOYER);
        console.log("Voting power delegated!");

        // Verify voting power
        uint256 votes = token.getVotes(DEPLOYER);
        console.log("Deployer voting power:", votes / 1e18, "NXS");

        // ============ NFT Initialization ============
        NexusNFT nft = NexusNFT(nftAddress);

        // 2. Set NFT sale phase to Public
        console.log("\nSetting NFT sale phase to Public...");
        nft.setSalePhase(NexusNFT.SalePhase.Public);
        console.log("NFT sale phase set to Public!");

        // 3. Set mint price to 0.01 ETH for testing
        uint256 mintPrice = 0.01 ether;
        console.log("Setting mint price to 0.01 ETH...");
        nft.setMintPrice(mintPrice);
        console.log("Mint price set!");

        // Verify NFT settings
        console.log("Current sale phase:", uint(nft.salePhase()));
        console.log("Current mint price:", nft.mintPrice() / 1e18, "ETH");

        // ============ KYC Initialization ============
        NexusKYCRegistry kyc = NexusKYCRegistry(kycAddress);

        // 4. Add deployer to whitelist for testing
        console.log("\nAdding deployer to KYC whitelist...");
        kyc.addToWhitelist(DEPLOYER);
        console.log("Deployer whitelisted!");

        // Verify KYC status
        bool isWhitelisted = kyc.isWhitelisted(DEPLOYER);
        console.log("Deployer whitelisted:", isWhitelisted);

        vm.stopBroadcast();

        // Print summary
        console.log("\n========================================");
        console.log("       INITIALIZATION COMPLETE");
        console.log("========================================");
        console.log("Token:");
        console.log("  - Voting power delegated to deployer");
        console.log("  - Ready for governance participation");
        console.log("");
        console.log("NFT:");
        console.log("  - Sale phase: Public");
        console.log("  - Mint price: 0.01 ETH");
        console.log("  - Ready for minting!");
        console.log("");
        console.log("KYC:");
        console.log("  - Deployer whitelisted");
        console.log("  - Ready for KYC-gated features");
        console.log("========================================\n");
    }
}
