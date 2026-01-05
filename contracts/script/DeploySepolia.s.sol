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
 * @title DeploySepolia
 * @notice Deploys ALL contracts to Sepolia testnet
 * @dev Run with: forge script script/DeploySepolia.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer's private key (with 0x prefix)
 * - SEPOLIA_RPC_URL: Sepolia RPC endpoint (e.g., Alchemy/Infura)
 * - ETHERSCAN_API_KEY: For contract verification
 */
contract DeploySepolia is Script {
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying to Sepolia with address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e15, "finney");

        vm.startBroadcast(deployerPrivateKey);

        // ============ Core Contracts ============

        // 1. Deploy NexusToken
        console.log("Deploying NexusToken...");
        NexusToken token = new NexusToken(deployer);
        console.log("NexusToken deployed at:", address(token));

        // 2. Mint tokens to deployer (100k NXS for testnet)
        uint256 mintAmount = 100_000 * 10 ** 18;
        token.mint(deployer, mintAmount);
        console.log("Minted 100,000 NXS to deployer");

        // 3. Deploy NexusStaking
        console.log("Deploying NexusStaking...");
        NexusStaking staking = new NexusStaking(
            address(token), // staking token
            deployer, // treasury
            deployer // admin
        );
        console.log("NexusStaking deployed at:", address(staking));

        // 4. Fund staking contract with rewards (10k NXS)
        uint256 rewardAmount = 10_000 * 10 ** 18;
        token.transfer(address(staking), rewardAmount);
        console.log("Funded staking with 10,000 NXS for rewards");

        // 5. Deploy NexusNFT
        console.log("Deploying NexusNFT...");
        NexusNFT nft = new NexusNFT(
            "Nexus NFT", // name
            "NXNFT", // symbol
            deployer, // treasury
            deployer, // royalty receiver
            500, // royalty bps (5%)
            deployer // admin
        );
        console.log("NexusNFT deployed at:", address(nft));

        // ============ Security Contracts ============

        // 6. Deploy NexusAccessControl
        console.log("Deploying NexusAccessControl...");
        uint256 guardianSunset = block.timestamp + 365 days; // Guardian role expires in 1 year
        NexusAccessControl accessControl = new NexusAccessControl(deployer, guardianSunset);
        console.log("NexusAccessControl deployed at:", address(accessControl));

        // 7. Deploy NexusKYCRegistry
        console.log("Deploying NexusKYCRegistry...");
        NexusKYCRegistry kycRegistry = new NexusKYCRegistry(deployer);
        console.log("NexusKYCRegistry deployed at:", address(kycRegistry));

        // 8. Deploy NexusEmergency
        console.log("Deploying NexusEmergency...");
        NexusEmergency emergency = new NexusEmergency(address(accessControl));
        console.log("NexusEmergency deployed at:", address(emergency));

        // ============ Governance Contracts ============

        // 9. Deploy NexusTimelock (48 hour delay for production)
        console.log("Deploying NexusTimelock...");
        address[] memory proposers = new address[](1);
        proposers[0] = deployer; // Temporary, will be updated to Governor
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute after delay
        uint256 minDelay = 172800; // 48 hours (production setting)
        NexusTimelock timelock = new NexusTimelock(minDelay, proposers, executors, deployer);
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
        NexusForwarder forwarder = new NexusForwarder(deployer, deployer); // Admin and Relayer
        console.log("NexusForwarder deployed at:", address(forwarder));

        vm.stopBroadcast();

        // Print summary
        console.log("\n========================================");
        console.log("    SEPOLIA DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Chain ID: 11155111 (Sepolia)");
        console.log("Deployer:", deployer);
        console.log("----------------------------------------");
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
        console.log("Deployer NXS balance:", token.balanceOf(deployer) / 10 ** 18);
        console.log("========================================\n");
        console.log("Next step: Run post_deploy.py to register contracts in database");
        console.log("  python scripts/post_deploy.py --chain-id 11155111 --api-url <API_URL> --script DeploySepolia");
    }
}
