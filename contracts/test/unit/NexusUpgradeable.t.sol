// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { NexusTokenUpgradeable } from "../../src/upgradeable/NexusTokenUpgradeable.sol";
import { NexusStakingUpgradeable } from "../../src/upgradeable/NexusStakingUpgradeable.sol";
import { NexusBridgeUpgradeable } from "../../src/upgradeable/NexusBridgeUpgradeable.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

/**
 * @title NexusUpgradeableTest
 * @notice Tests for UUPS upgradeable contracts
 */
contract NexusUpgradeableTest is Test {
    NexusTokenUpgradeable public tokenImpl;
    NexusTokenUpgradeable public token;
    ERC1967Proxy public tokenProxy;

    NexusStakingUpgradeable public stakingImpl;
    NexusStakingUpgradeable public staking;
    ERC1967Proxy public stakingProxy;

    address public admin = address(1);
    address public treasury = address(2);
    address public user = address(3);

    function setUp() public {
        // Deploy Token
        tokenImpl = new NexusTokenUpgradeable();
        bytes memory tokenInitData = abi.encodeWithSelector(NexusTokenUpgradeable.initialize.selector, admin);
        tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInitData);
        token = NexusTokenUpgradeable(address(tokenProxy));

        // Deploy Staking
        stakingImpl = new NexusStakingUpgradeable();
        bytes memory stakingInitData =
            abi.encodeWithSelector(NexusStakingUpgradeable.initialize.selector, address(token), treasury, admin);
        stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = NexusStakingUpgradeable(address(stakingProxy));
    }

    // ============ Token Tests ============

    function test_Token_Initialize() public view {
        assertEq(token.name(), "Nexus Token");
        assertEq(token.symbol(), "NEXUS");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertEq(token.version(), "1.0.0");
    }

    function test_Token_Mint() public {
        vm.prank(admin);
        token.mint(user, 1000e18);

        assertEq(token.balanceOf(user), 1000e18);
        assertEq(token.totalSupply(), 1000e18);
    }

    function test_Token_Burn() public {
        vm.prank(admin);
        token.mint(user, 1000e18);

        vm.prank(user);
        token.burn(400e18);

        assertEq(token.balanceOf(user), 600e18);
    }

    function test_Token_Snapshot() public {
        vm.prank(admin);
        token.mint(user, 1000e18);

        vm.roll(block.number + 1);

        vm.prank(admin);
        uint256 snapshotId = token.snapshot();

        assertEq(snapshotId, 1);
        assertEq(token.getCurrentSnapshotId(), 1);
    }

    function test_Token_Pause() public {
        // Mint before pausing
        vm.prank(admin);
        token.mint(user, 1000e18);

        vm.prank(admin);
        token.pause();

        assertTrue(token.paused());

        // Transfers should fail when paused
        vm.prank(user);
        vm.expectRevert();
        token.transfer(admin, 500e18);

        // Minting should also fail when paused
        vm.prank(admin);
        vm.expectRevert();
        token.mint(user, 500e18);
    }

    function test_Token_CannotReinitialize() public {
        vm.expectRevert();
        token.initialize(user);
    }

    function test_Token_OnlyUpgraderCanUpgrade() public {
        NexusTokenUpgradeable newImpl = new NexusTokenUpgradeable();

        vm.prank(user);
        vm.expectRevert();
        token.upgradeToAndCall(address(newImpl), "");

        vm.prank(admin);
        token.upgradeToAndCall(address(newImpl), "");
    }

    // ============ Staking Tests ============

    function test_Staking_Initialize() public view {
        assertEq(address(staking.stakingToken()), address(token));
        assertEq(staking.treasury(), treasury);
        assertTrue(staking.hasRole(staking.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(staking.version(), "1.0.0");
    }

    function test_Staking_Stake() public {
        vm.prank(admin);
        token.mint(user, 1000e18);

        vm.startPrank(user);
        token.approve(address(staking), 1000e18);
        staking.stake(1000e18);
        vm.stopPrank();

        assertEq(staking.totalStaked(), 1000e18);
        (uint256 amount,,,,,) = staking.getStakeInfo(user);
        assertEq(amount, 1000e18);
    }

    function test_Staking_Delegate() public {
        address delegatee = address(4);

        vm.prank(admin);
        token.mint(user, 1000e18);

        vm.startPrank(user);
        token.approve(address(staking), 1000e18);
        staking.stake(1000e18);
        staking.delegate(delegatee);
        vm.stopPrank();

        assertEq(staking.votingPower(delegatee), 1000e18);
        assertEq(staking.votingPower(user), 0);
    }

    function test_Staking_CannotReinitialize() public {
        vm.expectRevert();
        staking.initialize(address(token), treasury, user);
    }

    function test_Staking_OnlyUpgraderCanUpgrade() public {
        NexusStakingUpgradeable newImpl = new NexusStakingUpgradeable();

        vm.prank(user);
        vm.expectRevert();
        staking.upgradeToAndCall(address(newImpl), "");

        vm.prank(admin);
        staking.upgradeToAndCall(address(newImpl), "");
    }

    // ============ Upgrade Tests ============

    function test_Upgrade_PreservesState() public {
        // Mint tokens
        vm.prank(admin);
        token.mint(user, 1000e18);

        // Stake tokens
        vm.startPrank(user);
        token.approve(address(staking), 500e18);
        staking.stake(500e18);
        vm.stopPrank();

        // Verify state before upgrade
        assertEq(token.balanceOf(user), 500e18);
        assertEq(staking.totalStaked(), 500e18);

        // Upgrade Token
        NexusTokenUpgradeable newTokenImpl = new NexusTokenUpgradeable();
        vm.prank(admin);
        token.upgradeToAndCall(address(newTokenImpl), "");

        // Upgrade Staking
        NexusStakingUpgradeable newStakingImpl = new NexusStakingUpgradeable();
        vm.prank(admin);
        staking.upgradeToAndCall(address(newStakingImpl), "");

        // Verify state after upgrade
        assertEq(token.balanceOf(user), 500e18);
        assertEq(staking.totalStaked(), 500e18);
        assertEq(token.version(), "1.0.0");
        assertEq(staking.version(), "1.0.0");
    }
}

/**
 * @title NexusBridgeUpgradeableTest
 * @notice Tests for upgradeable bridge
 */
contract NexusBridgeUpgradeableTest is Test {
    NexusBridgeUpgradeable public bridgeImpl;
    NexusBridgeUpgradeable public bridge;
    ERC1967Proxy public bridgeProxy;
    ERC20Mock public token;

    address public admin;
    uint256 public adminKey;

    address[] public relayers;
    uint256[] public relayerKeys;

    uint256 constant SOURCE_CHAIN = 1;
    uint256 constant DEST_CHAIN = 137;

    function setUp() public {
        (admin, adminKey) = makeAddrAndKey("admin");

        // Create relayers
        for (uint256 i = 0; i < 3; i++) {
            (address relayer, uint256 key) = makeAddrAndKey(string(abi.encodePacked("relayer", i)));
            relayers.push(relayer);
            relayerKeys.push(key);
        }

        // Sort relayers
        _sortRelayers();

        token = new ERC20Mock("Test Token", "TEST", 18);

        bridgeImpl = new NexusBridgeUpgradeable();
        bytes memory bridgeInitData = abi.encodeWithSelector(
            NexusBridgeUpgradeable.initialize.selector, address(token), SOURCE_CHAIN, true, 2, relayers
        );
        vm.prank(admin);
        bridgeProxy = new ERC1967Proxy(address(bridgeImpl), bridgeInitData);
        bridge = NexusBridgeUpgradeable(address(bridgeProxy));

        // Add supported chain
        vm.prank(admin);
        bridge.addSupportedChain(DEST_CHAIN);

        // Fund bridge
        token.mint(address(bridge), 10_000_000e18);
    }

    function _sortRelayers() internal {
        for (uint256 i = 0; i < relayers.length - 1; i++) {
            for (uint256 j = 0; j < relayers.length - i - 1; j++) {
                if (relayers[j] > relayers[j + 1]) {
                    (relayers[j], relayers[j + 1]) = (relayers[j + 1], relayers[j]);
                    (relayerKeys[j], relayerKeys[j + 1]) = (relayerKeys[j + 1], relayerKeys[j]);
                }
            }
        }
    }

    function test_Bridge_Initialize() public view {
        (uint256 chainId, bool isSource, uint256 threshold,,) = bridge.getBridgeConfig();
        assertEq(chainId, SOURCE_CHAIN);
        assertTrue(isSource);
        assertEq(threshold, 2);
        assertEq(bridge.version(), "1.0.0");
    }

    function test_Bridge_LockTokens() public {
        address user = address(100);
        token.mint(user, 1000e18);

        vm.startPrank(user);
        token.approve(address(bridge), 1000e18);
        bridge.lockTokens(address(200), 1000e18, DEST_CHAIN);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 0);
        assertEq(bridge.outboundNonce(), 1);
    }

    function test_Bridge_CannotReinitialize() public {
        vm.expectRevert();
        bridge.initialize(address(token), SOURCE_CHAIN, true, 2, relayers);
    }

    function test_Bridge_OnlyUpgraderCanUpgrade() public {
        NexusBridgeUpgradeable newImpl = new NexusBridgeUpgradeable();

        address user = address(100);
        vm.prank(user);
        vm.expectRevert();
        bridge.upgradeToAndCall(address(newImpl), "");

        vm.prank(admin);
        bridge.upgradeToAndCall(address(newImpl), "");
    }
}
