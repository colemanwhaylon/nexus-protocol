// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {NexusGovernor} from "../src/governance/NexusGovernor.sol";
import {NexusTimelock} from "../src/governance/NexusTimelock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title RedeployGovernor
 * @notice Deploys a new NexusGovernor with admin override functionality
 * @dev Used to upgrade the Governor contract with database-driven configuration
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - TOKEN_ADDRESS: Address of NexusToken (ERC20Votes)
 * - TIMELOCK_ADDRESS: Address of NexusTimelock
 *
 * Usage:
 *   TOKEN_ADDRESS=0x... TIMELOCK_ADDRESS=0x... PRIVATE_KEY=0x... \
 *   forge script script/RedeployGovernor.s.sol --rpc-url <RPC_URL> --broadcast --via-ir
 */
contract RedeployGovernor is Script {
    function run() external {
        // Load addresses from environment
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=========================================");
        console.log("Redeploying NexusGovernor with Admin Override");
        console.log("=========================================");
        console.log("Deployer:", deployer);
        console.log("NexusToken:", tokenAddress);
        console.log("NexusTimelock:", timelockAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new Governor with testnet admin override enabled
        // Parameters:
        // - votingDelay: 1 block (fast for testing)
        // - votingPeriod: 100 blocks (~20 minutes at 12s/block)
        // - proposalThreshold: 100 tokens (demo-friendly)
        NexusGovernor governor = new NexusGovernor(
            IVotes(tokenAddress),
            NexusTimelock(payable(timelockAddress)),
            deployer,     // admin (can override params on testnet)
            true,         // isTestnet = true (enables admin override)
            1,            // votingDelay (1 block)
            100,          // votingPeriod (100 blocks)
            100 * 10**18  // proposalThreshold (100 tokens)
        );

        console.log("NexusGovernor deployed at:", address(governor));

        // Grant PROPOSER_ROLE to new governor on timelock
        NexusTimelock timelock = NexusTimelock(payable(timelockAddress));
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();

        // Check if deployer has admin role on timelock
        bytes32 DEFAULT_ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();
        bool hasAdmin = timelock.hasRole(DEFAULT_ADMIN_ROLE, deployer);

        if (hasAdmin) {
            timelock.grantRole(PROPOSER_ROLE, address(governor));
            console.log("Granted PROPOSER_ROLE to new Governor");
        } else {
            console.log("WARNING: Deployer doesn't have admin role on timelock");
            console.log("You need to manually grant PROPOSER_ROLE to:", address(governor));
        }

        vm.stopBroadcast();

        console.log("\n=========================================");
        console.log("Deployment Summary");
        console.log("=========================================");
        console.log("New NexusGovernor:", address(governor));
        console.log("Admin (testnet):", deployer);
        console.log("isTestnet:", governor.isTestnet());
        console.log("Voting Delay:", governor.votingDelay(), "blocks");
        console.log("Voting Period:", governor.votingPeriod(), "blocks");
        console.log("Proposal Threshold:", governor.proposalThreshold() / 1e18, "tokens");
        console.log("\nNext steps:");
        console.log("1. Register new contract address in database");
        console.log("2. Test admin override functions:");
        console.log("   - setProposalThresholdAdmin(uint256)");
        console.log("   - setVotingDelayAdmin(uint48)");
        console.log("   - setVotingPeriodAdmin(uint32)");
    }
}
