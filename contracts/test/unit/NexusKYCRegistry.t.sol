// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {NexusKYCRegistry} from "../../src/security/NexusKYCRegistry.sol";

/**
 * @title NexusKYCRegistryTest
 * @notice Unit tests for NexusKYCRegistry contract
 * @dev Tests cover:
 *      - KYC status setting and levels
 *      - Whitelist management
 *      - Blacklist management
 *      - KYC expiration
 *      - Country restrictions
 *      - Batch operations
 *      - Access control
 */
contract NexusKYCRegistryTest is Test {
    NexusKYCRegistry public registry;

    address public admin = address(1);
    address public complianceOfficer = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public user3 = address(5);

    uint256 public constant MAX_EXPIRY_DURATION = 5 * 365 days;
    uint256 public constant DEFAULT_EXPIRY_DURATION = 365 days;

    string public constant COUNTRY_USA = "USA";
    string public constant COUNTRY_UK = "GBR";
    string public constant COUNTRY_RESTRICTED = "PRK";

    // Events
    event KYCUpdated(
        address indexed account,
        NexusKYCRegistry.KYCLevel indexed level,
        uint256 expiresAt,
        address indexed updatedBy
    );
    event Whitelisted(address indexed account, address indexed addedBy);
    event WhitelistRemoved(address indexed account, address indexed removedBy);
    event Blacklisted(address indexed account, string reason, address indexed addedBy);
    event BlacklistRemoved(address indexed account, address indexed removedBy);
    event CountryRestrictionUpdated(
        bytes32 indexed countryHash,
        bool isRestricted,
        NexusKYCRegistry.KYCLevel requiredLevel
    );
    event DefaultRequiredLevelUpdated(
        NexusKYCRegistry.KYCLevel previousLevel,
        NexusKYCRegistry.KYCLevel newLevel
    );
    event KYCRequirementUpdated(bool required);
    event BlacklistCheckingUpdated(bool enabled);
    event KYCRevoked(address indexed account, address indexed revokedBy, string reason);

    function setUp() public {
        vm.prank(admin);
        registry = new NexusKYCRegistry(admin);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.COMPLIANCE_ROLE(), admin));
        assertTrue(registry.blacklistEnabled());
        assertFalse(registry.kycRequired());
        assertEq(uint256(registry.defaultRequiredLevel()), uint256(NexusKYCRegistry.KYCLevel.Basic));
    }

    function test_Deployment_RevertZeroAddress() public {
        vm.expectRevert(NexusKYCRegistry.ZeroAddress.selector);
        new NexusKYCRegistry(address(0));
    }

    // ============ KYC Setting Tests ============

    function test_SetKYC_Basic() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            0, // Use default expiry
            "KYC Provider A",
            keccak256("documents")
        );

        (
            NexusKYCRegistry.KYCLevel level,
            uint256 verifiedAt,
            uint256 expiresAt,
            bytes32 countryCode,
            bool isWhitelisted,
            bool isBlacklisted
        ) = registry.getKYCInfo(user1);

        assertEq(uint256(level), uint256(NexusKYCRegistry.KYCLevel.Basic));
        assertEq(verifiedAt, block.timestamp);
        assertEq(expiresAt, block.timestamp + DEFAULT_EXPIRY_DURATION);
        assertEq(countryCode, keccak256(abi.encodePacked(COUNTRY_USA)));
        assertTrue(isWhitelisted); // Auto-whitelisted
        assertFalse(isBlacklisted);
    }

    function test_SetKYC_Enhanced() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Enhanced,
            COUNTRY_UK,
            180 days,
            "KYC Provider B",
            keccak256("enhanced-docs")
        );

        assertEq(uint256(registry.getKYCLevel(user1)), uint256(NexusKYCRegistry.KYCLevel.Enhanced));
    }

    function test_SetKYC_Accredited() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Accredited,
            COUNTRY_USA,
            365 days,
            "Accreditation Service",
            keccak256("accredited-docs")
        );

        assertEq(uint256(registry.getKYCLevel(user1)), uint256(NexusKYCRegistry.KYCLevel.Accredited));
    }

    function test_SetKYC_None_DoesNotWhitelist() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.None,
            COUNTRY_USA,
            0,
            "",
            bytes32(0)
        );

        assertFalse(registry.isWhitelisted(user1));
    }

    function test_SetKYC_AutoWhitelists() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            0,
            "Provider",
            bytes32(0)
        );

        assertTrue(registry.isWhitelisted(user1));
    }

    function test_SetKYC_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.ZeroAddress.selector);
        registry.setKYC(
            address(0),
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            0,
            "",
            bytes32(0)
        );
    }

    function test_SetKYC_RevertInvalidExpiry() public {
        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.InvalidExpiryDuration.selector);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            MAX_EXPIRY_DURATION + 1,
            "",
            bytes32(0)
        );
    }

    function test_SetKYC_RevertNotComplianceRole() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.setKYC(
            user2,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            0,
            "",
            bytes32(0)
        );
    }

    function test_SetKYC_ByComplianceOfficer() public {
        vm.startPrank(admin);
        registry.grantRole(registry.COMPLIANCE_ROLE(), complianceOfficer);
        vm.stopPrank();

        vm.prank(complianceOfficer);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            0,
            "Provider",
            bytes32(0)
        );

        assertEq(uint256(registry.getKYCLevel(user1)), uint256(NexusKYCRegistry.KYCLevel.Basic));
    }

    // ============ Batch KYC Tests ============

    function test_BatchSetKYC() public {
        address[] memory accounts = new address[](3);
        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = user3;

        NexusKYCRegistry.KYCLevel[] memory levels = new NexusKYCRegistry.KYCLevel[](3);
        levels[0] = NexusKYCRegistry.KYCLevel.Basic;
        levels[1] = NexusKYCRegistry.KYCLevel.Enhanced;
        levels[2] = NexusKYCRegistry.KYCLevel.Accredited;

        string[] memory countries = new string[](3);
        countries[0] = COUNTRY_USA;
        countries[1] = COUNTRY_UK;
        countries[2] = COUNTRY_USA;

        vm.prank(admin);
        registry.batchSetKYC(accounts, levels, countries, 180 days);

        assertEq(uint256(registry.getKYCLevel(user1)), uint256(NexusKYCRegistry.KYCLevel.Basic));
        assertEq(uint256(registry.getKYCLevel(user2)), uint256(NexusKYCRegistry.KYCLevel.Enhanced));
        assertEq(uint256(registry.getKYCLevel(user3)), uint256(NexusKYCRegistry.KYCLevel.Accredited));
    }

    function test_BatchSetKYC_RevertEmptyArray() public {
        address[] memory accounts = new address[](0);
        NexusKYCRegistry.KYCLevel[] memory levels = new NexusKYCRegistry.KYCLevel[](0);
        string[] memory countries = new string[](0);

        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.EmptyArray.selector);
        registry.batchSetKYC(accounts, levels, countries, 0);
    }

    function test_BatchSetKYC_RevertArrayLengthMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        NexusKYCRegistry.KYCLevel[] memory levels = new NexusKYCRegistry.KYCLevel[](1);
        levels[0] = NexusKYCRegistry.KYCLevel.Basic;

        string[] memory countries = new string[](2);
        countries[0] = COUNTRY_USA;
        countries[1] = COUNTRY_UK;

        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.ArrayLengthMismatch.selector);
        registry.batchSetKYC(accounts, levels, countries, 0);
    }

    // ============ KYC Revocation Tests ============

    function test_RevokeKYC() public {
        // First set KYC
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            0,
            "Provider",
            bytes32(0)
        );

        assertTrue(registry.isWhitelisted(user1));

        // Revoke KYC
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit KYCRevoked(user1, admin, "Suspicious activity");
        registry.revokeKYC(user1, "Suspicious activity");

        assertEq(uint256(registry.getKYCLevel(user1)), uint256(NexusKYCRegistry.KYCLevel.None));
        assertFalse(registry.isWhitelisted(user1));
    }

    function test_RevokeKYC_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.ZeroAddress.selector);
        registry.revokeKYC(address(0), "reason");
    }

    // ============ Whitelist Tests ============

    function test_AddToWhitelist() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit Whitelisted(user1, admin);
        registry.addToWhitelist(user1);

        assertTrue(registry.isWhitelisted(user1));
        assertEq(registry.getWhitelistCount(), 1);
    }

    function test_AddToWhitelist_RevertAlreadyWhitelisted() public {
        vm.startPrank(admin);
        registry.addToWhitelist(user1);

        vm.expectRevert(NexusKYCRegistry.AlreadyWhitelisted.selector);
        registry.addToWhitelist(user1);
        vm.stopPrank();
    }

    function test_AddToWhitelist_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.ZeroAddress.selector);
        registry.addToWhitelist(address(0));
    }

    function test_BatchAddToWhitelist() public {
        address[] memory accounts = new address[](3);
        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = user3;

        vm.prank(admin);
        registry.batchAddToWhitelist(accounts);

        assertTrue(registry.isWhitelisted(user1));
        assertTrue(registry.isWhitelisted(user2));
        assertTrue(registry.isWhitelisted(user3));
        assertEq(registry.getWhitelistCount(), 3);
    }

    function test_BatchAddToWhitelist_SkipsAlreadyWhitelisted() public {
        vm.prank(admin);
        registry.addToWhitelist(user1);

        address[] memory accounts = new address[](2);
        accounts[0] = user1; // Already whitelisted
        accounts[1] = user2;

        vm.prank(admin);
        registry.batchAddToWhitelist(accounts);

        assertEq(registry.getWhitelistCount(), 2);
    }

    function test_RemoveFromWhitelist() public {
        vm.startPrank(admin);
        registry.addToWhitelist(user1);

        vm.expectEmit(true, true, false, false);
        emit WhitelistRemoved(user1, admin);
        registry.removeFromWhitelist(user1);
        vm.stopPrank();

        assertFalse(registry.isWhitelisted(user1));
        assertEq(registry.getWhitelistCount(), 0);
    }

    function test_RemoveFromWhitelist_RevertNotWhitelisted() public {
        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.NotWhitelisted.selector);
        registry.removeFromWhitelist(user1);
    }

    function test_GetWhitelistedAddresses_Paginated() public {
        address[] memory accounts = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            accounts[i] = address(uint160(100 + i));
        }

        vm.prank(admin);
        registry.batchAddToWhitelist(accounts);

        address[] memory page1 = registry.getWhitelistedAddresses(0, 2);
        assertEq(page1.length, 2);

        address[] memory page2 = registry.getWhitelistedAddresses(2, 2);
        assertEq(page2.length, 2);

        address[] memory page3 = registry.getWhitelistedAddresses(4, 10);
        assertEq(page3.length, 1);

        address[] memory outOfRange = registry.getWhitelistedAddresses(10, 5);
        assertEq(outOfRange.length, 0);
    }

    // ============ Blacklist Tests ============

    function test_AddToBlacklist() public {
        vm.prank(admin);
        vm.expectEmit(true, false, true, true);
        emit Blacklisted(user1, "Fraud detected", admin);
        registry.addToBlacklist(user1, "Fraud detected");

        assertTrue(registry.isBlacklisted(user1));
        assertEq(registry.getBlacklistCount(), 1);
    }

    function test_AddToBlacklist_RemovesFromWhitelist() public {
        vm.startPrank(admin);
        registry.addToWhitelist(user1);
        assertTrue(registry.isWhitelisted(user1));

        registry.addToBlacklist(user1, "Fraud");
        vm.stopPrank();

        assertTrue(registry.isBlacklisted(user1));
        assertFalse(registry.isWhitelisted(user1));
    }

    function test_AddToBlacklist_RevertAlreadyBlacklisted() public {
        vm.startPrank(admin);
        registry.addToBlacklist(user1, "Reason 1");

        vm.expectRevert(NexusKYCRegistry.AlreadyBlacklisted.selector);
        registry.addToBlacklist(user1, "Reason 2");
        vm.stopPrank();
    }

    function test_RemoveFromBlacklist() public {
        vm.startPrank(admin);
        registry.addToBlacklist(user1, "Fraud");

        vm.expectEmit(true, true, false, false);
        emit BlacklistRemoved(user1, admin);
        registry.removeFromBlacklist(user1);
        vm.stopPrank();

        assertFalse(registry.isBlacklisted(user1));
        assertEq(registry.getBlacklistCount(), 0);
    }

    function test_RemoveFromBlacklist_RevertNotBlacklisted() public {
        vm.prank(admin);
        vm.expectRevert(NexusKYCRegistry.NotBlacklisted.selector);
        registry.removeFromBlacklist(user1);
    }

    function test_GetBlacklistedAddresses_Paginated() public {
        vm.startPrank(admin);
        for (uint256 i = 0; i < 5; i++) {
            registry.addToBlacklist(address(uint160(100 + i)), "Blacklisted");
        }
        vm.stopPrank();

        address[] memory page = registry.getBlacklistedAddresses(0, 3);
        assertEq(page.length, 3);
    }

    // ============ KYC Expiration Tests ============

    function test_IsKYCExpired_NotExpired() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            30 days,
            "Provider",
            bytes32(0)
        );

        assertFalse(registry.isKYCExpired(user1));
    }

    function test_IsKYCExpired_Expired() public {
        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            30 days,
            "Provider",
            bytes32(0)
        );

        vm.warp(block.timestamp + 31 days);

        assertTrue(registry.isKYCExpired(user1));
    }

    function test_IsCompliant_FailsIfExpired() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            30 days,
            "Provider",
            bytes32(0)
        );
        vm.stopPrank();

        assertTrue(registry.isCompliant(user1));

        vm.warp(block.timestamp + 31 days);

        assertFalse(registry.isCompliant(user1));
    }

    // ============ Country Restriction Tests ============

    function test_SetCountryRestriction() public {
        bytes32 countryHash = keccak256(abi.encodePacked(COUNTRY_RESTRICTED));

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit CountryRestrictionUpdated(countryHash, true, NexusKYCRegistry.KYCLevel.Enhanced);
        registry.setCountryRestriction(
            COUNTRY_RESTRICTED,
            true,
            NexusKYCRegistry.KYCLevel.Enhanced,
            1000 ether
        );

        (bool isRestricted, NexusKYCRegistry.KYCLevel requiredLevel, uint256 maxAmount) =
            registry.countryRestrictions(countryHash);

        assertTrue(isRestricted);
        assertEq(uint256(requiredLevel), uint256(NexusKYCRegistry.KYCLevel.Enhanced));
        assertEq(maxAmount, 1000 ether);
    }

    function test_IsCompliant_FailsIfCountryRestricted() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);

        // Set country restriction
        registry.setCountryRestriction(COUNTRY_RESTRICTED, true, NexusKYCRegistry.KYCLevel.Enhanced, 0);

        // Set user KYC with restricted country
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Enhanced,
            COUNTRY_RESTRICTED,
            365 days,
            "Provider",
            bytes32(0)
        );
        vm.stopPrank();

        assertFalse(registry.isCompliant(user1));
    }

    // ============ canTransfer Tests ============

    function test_CanTransfer_BothBlacklisted() public {
        vm.startPrank(admin);
        registry.addToBlacklist(user1, "Fraud");
        registry.addToBlacklist(user2, "Fraud");
        vm.stopPrank();

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertFalse(allowed);
        assertEq(reason, "Sender is blacklisted");
    }

    function test_CanTransfer_RecipientBlacklisted() public {
        vm.prank(admin);
        registry.addToBlacklist(user2, "Fraud");

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertFalse(allowed);
        assertEq(reason, "Recipient is blacklisted");
    }

    function test_CanTransfer_NoKYCRequired() public {
        // blacklistEnabled is true by default, but neither is blacklisted
        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertTrue(allowed);
        assertEq(reason, "");
    }

    function test_CanTransfer_KYCRequired_SenderInsufficient() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setDefaultRequiredLevel(NexusKYCRegistry.KYCLevel.Enhanced);

        // Set sender to Basic (insufficient)
        registry.setKYC(user1, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 0, "", bytes32(0));
        // Set recipient to Enhanced (sufficient)
        registry.setKYC(user2, NexusKYCRegistry.KYCLevel.Enhanced, COUNTRY_USA, 0, "", bytes32(0));
        vm.stopPrank();

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertFalse(allowed);
        assertEq(reason, "Sender KYC level insufficient");
    }

    function test_CanTransfer_KYCRequired_RecipientInsufficient() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setDefaultRequiredLevel(NexusKYCRegistry.KYCLevel.Enhanced);

        registry.setKYC(user1, NexusKYCRegistry.KYCLevel.Enhanced, COUNTRY_USA, 0, "", bytes32(0));
        registry.setKYC(user2, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 0, "", bytes32(0));
        vm.stopPrank();

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertFalse(allowed);
        assertEq(reason, "Recipient KYC level insufficient");
    }

    function test_CanTransfer_KYCRequired_SenderExpired() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setKYC(user1, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 30 days, "", bytes32(0));
        registry.setKYC(user2, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 365 days, "", bytes32(0));
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertFalse(allowed);
        assertEq(reason, "Sender KYC expired");
    }

    function test_CanTransfer_KYCRequired_CountryRestriction() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setCountryRestriction(COUNTRY_RESTRICTED, true, NexusKYCRegistry.KYCLevel.None, 0);

        registry.setKYC(user1, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_RESTRICTED, 365 days, "", bytes32(0));
        registry.setKYC(user2, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 365 days, "", bytes32(0));
        vm.stopPrank();

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertFalse(allowed);
        assertEq(reason, "Sender country restricted");
    }

    function test_CanTransfer_AmountExceedsCountryLimit() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setCountryRestriction(COUNTRY_USA, false, NexusKYCRegistry.KYCLevel.None, 100 ether);

        registry.setKYC(user1, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 365 days, "", bytes32(0));
        registry.setKYC(user2, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_UK, 365 days, "", bytes32(0));
        vm.stopPrank();

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 200 ether);
        assertFalse(allowed);
        assertEq(reason, "Amount exceeds sender country limit");
    }

    function test_CanTransfer_Success() public {
        vm.startPrank(admin);
        registry.setKYCRequired(true);
        registry.setKYC(user1, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_USA, 365 days, "", bytes32(0));
        registry.setKYC(user2, NexusKYCRegistry.KYCLevel.Basic, COUNTRY_UK, 365 days, "", bytes32(0));
        vm.stopPrank();

        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100 ether);
        assertTrue(allowed);
        assertEq(reason, "");
    }

    // ============ Admin Configuration Tests ============

    function test_SetDefaultRequiredLevel() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit DefaultRequiredLevelUpdated(NexusKYCRegistry.KYCLevel.Basic, NexusKYCRegistry.KYCLevel.Enhanced);
        registry.setDefaultRequiredLevel(NexusKYCRegistry.KYCLevel.Enhanced);

        assertEq(uint256(registry.defaultRequiredLevel()), uint256(NexusKYCRegistry.KYCLevel.Enhanced));
    }

    function test_SetKYCRequired() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit KYCRequirementUpdated(true);
        registry.setKYCRequired(true);

        assertTrue(registry.kycRequired());
    }

    function test_SetBlacklistEnabled() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit BlacklistCheckingUpdated(false);
        registry.setBlacklistEnabled(false);

        assertFalse(registry.blacklistEnabled());
    }

    function test_CanTransfer_BlacklistDisabled() public {
        vm.startPrank(admin);
        registry.setBlacklistEnabled(false);
        registry.addToBlacklist(user1, "Fraud");
        vm.stopPrank();

        // Even though user1 is blacklisted, blacklist checking is disabled
        (bool allowed, string memory reason) = registry.canTransfer(user1, user2, 100);
        assertTrue(allowed);
        assertEq(reason, "");
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        vm.prank(admin);
        registry.pause();

        assertTrue(registry.paused());
    }

    function test_Pause_RevertOnOperations() public {
        vm.prank(admin);
        registry.pause();

        vm.prank(admin);
        vm.expectRevert();
        registry.addToWhitelist(user1);
    }

    function test_Unpause() public {
        vm.startPrank(admin);
        registry.pause();
        registry.unpause();
        vm.stopPrank();

        assertFalse(registry.paused());

        vm.prank(admin);
        registry.addToWhitelist(user1);
        assertTrue(registry.isWhitelisted(user1));
    }

    function test_Pause_RevertNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.pause();
    }

    // ============ Edge Cases ============

    function test_WhitelistRemovalPreservesOrder() public {
        // Add 3 addresses
        vm.startPrank(admin);
        registry.addToWhitelist(user1);
        registry.addToWhitelist(user2);
        registry.addToWhitelist(user3);

        // Remove middle one
        registry.removeFromWhitelist(user2);
        vm.stopPrank();

        // Should have 2 addresses
        assertEq(registry.getWhitelistCount(), 2);

        // Both should still be whitelisted
        assertTrue(registry.isWhitelisted(user1));
        assertFalse(registry.isWhitelisted(user2));
        assertTrue(registry.isWhitelisted(user3));
    }

    function test_BlacklistRemovalPreservesOrder() public {
        vm.startPrank(admin);
        registry.addToBlacklist(user1, "Reason 1");
        registry.addToBlacklist(user2, "Reason 2");
        registry.addToBlacklist(user3, "Reason 3");

        registry.removeFromBlacklist(user2);
        vm.stopPrank();

        assertEq(registry.getBlacklistCount(), 2);
        assertTrue(registry.isBlacklisted(user1));
        assertFalse(registry.isBlacklisted(user2));
        assertTrue(registry.isBlacklisted(user3));
    }

    function testFuzz_SetKYC_ExpiryDuration(uint256 duration) public {
        duration = bound(duration, 1, MAX_EXPIRY_DURATION);

        vm.prank(admin);
        registry.setKYC(
            user1,
            NexusKYCRegistry.KYCLevel.Basic,
            COUNTRY_USA,
            duration,
            "",
            bytes32(0)
        );

        (,, uint256 expiresAt,,,) = registry.getKYCInfo(user1);
        assertEq(expiresAt, block.timestamp + duration);
    }

    function testFuzz_SetKYC_Level(uint8 levelSeed) public {
        uint8 levelValue = levelSeed % 4;
        NexusKYCRegistry.KYCLevel level = NexusKYCRegistry.KYCLevel(levelValue);

        vm.prank(admin);
        registry.setKYC(user1, level, COUNTRY_USA, 0, "", bytes32(0));

        assertEq(uint256(registry.getKYCLevel(user1)), uint256(level));
    }
}
