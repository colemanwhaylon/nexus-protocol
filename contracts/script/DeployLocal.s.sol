// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { NexusToken } from "../src/core/NexusToken.sol";
import { NexusStaking } from "../src/defi/NexusStaking.sol";
import { NexusNFT } from "../src/core/NexusNFT.sol";

/**
 * @title DeployLocal
 * @notice Deploys contracts to local Anvil for development/demo
 * @dev Run with: forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
 */
contract DeployLocal is Script {
    // Anvil's first test account
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        // Use Anvil's first private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy NexusToken
        console.log("Deploying NexusToken...");
        NexusToken token = new NexusToken(DEPLOYER);
        console.log("NexusToken deployed at:", address(token));

        // 2. Mint tokens to deployer (1 million NXS for testing)
        uint256 mintAmount = 1_000_000 * 10 ** 18;
        token.mint(DEPLOYER, mintAmount);
        console.log("Minted 1,000,000 NXS to deployer");

        // 3. Deploy NexusStaking
        console.log("Deploying NexusStaking...");
        NexusStaking staking = new NexusStaking(
            address(token), // staking token
            DEPLOYER, // treasury
            DEPLOYER // admin
        );
        console.log("NexusStaking deployed at:", address(staking));

        // 4. Fund staking contract with rewards (100k NXS)
        uint256 rewardAmount = 100_000 * 10 ** 18;
        token.transfer(address(staking), rewardAmount);
        console.log("Funded staking with 100,000 NXS for rewards");

        // 5. Deploy NexusNFT
        console.log("Deploying NexusNFT...");
        NexusNFT nft = new NexusNFT(
            "Nexus NFT", // name
            "NXNFT", // symbol
            DEPLOYER, // treasury
            DEPLOYER, // royalty receiver
            500, // royalty bps (5%)
            DEPLOYER // admin
        );
        console.log("NexusNFT deployed at:", address(nft));

        vm.stopBroadcast();

        // Print summary
        console.log("\n========================================");
        console.log("       DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("NexusToken (NEXUS):", address(token));
        console.log("NexusStaking:      ", address(staking));
        console.log("NexusNFT:          ", address(nft));
        console.log("----------------------------------------");
        console.log("Deployer NXS balance:", token.balanceOf(DEPLOYER) / 10 ** 18);
        console.log("========================================\n");
    }
}
