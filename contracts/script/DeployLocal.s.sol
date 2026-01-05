// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { NexusToken } from "../src/core/NexusToken.sol";
import { NexusStaking } from "../src/defi/NexusStaking.sol";
import { NexusNFT } from "../src/core/NexusNFT.sol";
import { NexusAccessControl } from "../src/security/NexusAccessControl.sol";
import { NexusKYCRegistry } from "../src/security/NexusKYCRegistry.sol";
import { NexusEmergency } from "../src/security/NexusEmergency.sol";
import { NexusTimelock } from "../src/governance/NexusTimelock.sol";
import { NexusGovernor } from "../src/governance/NexusGovernor.sol";
import { NexusForwarder } from "../src/metatx/NexusForwarder.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title DeployLocal
 * @notice Deploys ALL contracts to local Anvil for development/demo
 * @dev Run with: forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
 */
contract DeployLocal is Script {
    // Anvil's first test account
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        // Use Anvil's first private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        // ============ Core Contracts ============

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

        // ============ Security Contracts ============

        // 6. Deploy NexusAccessControl
        console.log("Deploying NexusAccessControl...");
        uint256 guardianSunset = block.timestamp + 365 days; // Guardian role expires in 1 year
        NexusAccessControl accessControl = new NexusAccessControl(DEPLOYER, guardianSunset);
        console.log("NexusAccessControl deployed at:", address(accessControl));

        // 7. Deploy NexusKYCRegistry
        console.log("Deploying NexusKYCRegistry...");
        NexusKYCRegistry kycRegistry = new NexusKYCRegistry(DEPLOYER);
        console.log("NexusKYCRegistry deployed at:", address(kycRegistry));

        // 8. Deploy NexusEmergency
        console.log("Deploying NexusEmergency...");
        NexusEmergency emergency = new NexusEmergency(address(accessControl));
        console.log("NexusEmergency deployed at:", address(emergency));

        // ============ Governance Contracts ============

        // 9. Deploy NexusTimelock (48 hour delay for local testing reduced to 1 minute)
        console.log("Deploying NexusTimelock...");
        address[] memory proposers = new address[](1);
        proposers[0] = DEPLOYER; // Temporary, will be updated to Governor
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute after delay
        uint256 minDelay = 86400; // 24 hours minimum (ABSOLUTE_MIN_DELAY in NexusTimelock)
        NexusTimelock timelock = new NexusTimelock(minDelay, proposers, executors, DEPLOYER);
        console.log("NexusTimelock deployed at:", address(timelock));

        // 10. Deploy NexusGovernor
        console.log("Deploying NexusGovernor...");
        NexusGovernor governor = new NexusGovernor(IVotes(address(token)), timelock);
        console.log("NexusGovernor deployed at:", address(governor));

        // 11. Grant Governor the PROPOSER_ROLE on Timelock
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        timelock.grantRole(PROPOSER_ROLE, address(governor));
        console.log("Granted PROPOSER_ROLE to Governor");

        // ============ Meta-Transaction Support ============

        // 12. Deploy NexusForwarder
        console.log("Deploying NexusForwarder...");
        NexusForwarder forwarder = new NexusForwarder(DEPLOYER, DEPLOYER); // Admin and Relayer both DEPLOYER for testing
        console.log("NexusForwarder deployed at:", address(forwarder));

        vm.stopBroadcast();

        // Print summary
        console.log("\n========================================");
        console.log("       DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("CORE CONTRACTS:");
        console.log("  NexusToken:        ", address(token));
        console.log("  NexusStaking:      ", address(staking));
        console.log("  NexusNFT:          ", address(nft));
        console.log("----------------------------------------");
        console.log("SECURITY CONTRACTS:");
        console.log("  NexusAccessControl:", address(accessControl));
        console.log("  NexusKYCRegistry:  ", address(kycRegistry));
        console.log("  NexusEmergency:    ", address(emergency));
        console.log("----------------------------------------");
        console.log("GOVERNANCE CONTRACTS:");
        console.log("  NexusTimelock:     ", address(timelock));
        console.log("  NexusGovernor:     ", address(governor));
        console.log("----------------------------------------");
        console.log("META-TX CONTRACTS:");
        console.log("  NexusForwarder:    ", address(forwarder));
        console.log("----------------------------------------");
        console.log("Deployer NXS balance:", token.balanceOf(DEPLOYER) / 10 ** 18);
        console.log("========================================\n");
    }
}
