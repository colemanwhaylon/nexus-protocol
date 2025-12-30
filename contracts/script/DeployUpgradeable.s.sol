// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { NexusTokenUpgradeable } from "../src/upgradeable/NexusTokenUpgradeable.sol";
import { NexusStakingUpgradeable } from "../src/upgradeable/NexusStakingUpgradeable.sol";
import { NexusBridgeUpgradeable } from "../src/upgradeable/NexusBridgeUpgradeable.sol";

/**
 * @title DeployUpgradeable
 * @notice Deployment script for upgradeable contracts
 */
contract DeployUpgradeable is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy NexusToken implementation and proxy
        NexusTokenUpgradeable tokenImpl = new NexusTokenUpgradeable();
        bytes memory tokenInitData = abi.encodeWithSelector(NexusTokenUpgradeable.initialize.selector, admin);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInitData);
        NexusTokenUpgradeable token = NexusTokenUpgradeable(address(tokenProxy));

        console2.log("NexusToken Implementation:", address(tokenImpl));
        console2.log("NexusToken Proxy:", address(tokenProxy));

        // Deploy NexusStaking implementation and proxy
        NexusStakingUpgradeable stakingImpl = new NexusStakingUpgradeable();
        bytes memory stakingInitData =
            abi.encodeWithSelector(NexusStakingUpgradeable.initialize.selector, address(token), treasury, admin);
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        NexusStakingUpgradeable staking = NexusStakingUpgradeable(address(stakingProxy));

        console2.log("NexusStaking Implementation:", address(stakingImpl));
        console2.log("NexusStaking Proxy:", address(stakingProxy));

        vm.stopBroadcast();

        console2.log("\n--- Deployment Summary ---");
        console2.log("Token Version:", token.version());
        console2.log("Staking Version:", staking.version());
    }
}

/**
 * @title DeployBridge
 * @notice Deployment script for bridge contract
 */
contract DeployBridge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        uint256 chainId = vm.envUint("CHAIN_ID");
        bool isSource = vm.envBool("IS_SOURCE_CHAIN");

        // Get relayers from environment
        address relayer1 = vm.envAddress("RELAYER_1");
        address relayer2 = vm.envAddress("RELAYER_2");
        address relayer3 = vm.envAddress("RELAYER_3");

        address[] memory relayers = new address[](3);
        relayers[0] = relayer1;
        relayers[1] = relayer2;
        relayers[2] = relayer3;

        vm.startBroadcast(deployerPrivateKey);

        NexusBridgeUpgradeable bridgeImpl = new NexusBridgeUpgradeable();
        bytes memory bridgeInitData = abi.encodeWithSelector(
            NexusBridgeUpgradeable.initialize.selector,
            tokenAddress,
            chainId,
            isSource,
            2, // relayerThreshold
            relayers
        );
        ERC1967Proxy bridgeProxy = new ERC1967Proxy(address(bridgeImpl), bridgeInitData);
        NexusBridgeUpgradeable bridge = NexusBridgeUpgradeable(address(bridgeProxy));

        console2.log("NexusBridge Implementation:", address(bridgeImpl));
        console2.log("NexusBridge Proxy:", address(bridgeProxy));
        console2.log("Bridge Version:", bridge.version());

        vm.stopBroadcast();
    }
}

/**
 * @title UpgradeToken
 * @notice Upgrade script for NexusToken
 */
contract UpgradeToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("TOKEN_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        NexusTokenUpgradeable newImpl = new NexusTokenUpgradeable();

        // Upgrade proxy
        NexusTokenUpgradeable proxy = NexusTokenUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(address(newImpl), "");

        console2.log("New Implementation:", address(newImpl));
        console2.log("New Version:", proxy.version());

        vm.stopBroadcast();
    }
}

/**
 * @title UpgradeStaking
 * @notice Upgrade script for NexusStaking
 */
contract UpgradeStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("STAKING_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        NexusStakingUpgradeable newImpl = new NexusStakingUpgradeable();
        NexusStakingUpgradeable proxy = NexusStakingUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(address(newImpl), "");

        console2.log("New Implementation:", address(newImpl));
        console2.log("New Version:", proxy.version());

        vm.stopBroadcast();
    }
}

/**
 * @title UpgradeBridge
 * @notice Upgrade script for NexusBridge
 */
contract UpgradeBridge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("BRIDGE_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        NexusBridgeUpgradeable newImpl = new NexusBridgeUpgradeable();
        NexusBridgeUpgradeable proxy = NexusBridgeUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(address(newImpl), "");

        console2.log("New Implementation:", address(newImpl));
        console2.log("New Version:", proxy.version());

        vm.stopBroadcast();
    }
}
