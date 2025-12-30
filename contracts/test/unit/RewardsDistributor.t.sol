// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {RewardsDistributor} from "../../src/defi/RewardsDistributor.sol";
import {NexusToken} from "../../src/core/NexusToken.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title RewardsDistributorTest
 * @notice Unit tests for RewardsDistributor contract
 * @dev Tests cover:
 *      - Campaign creation (streaming and Merkle)
 *      - Streaming rewards claiming
 *      - Merkle claims with proof verification
 *      - Admin functions (pause, treasury, campaign management)
 *      - Rate limiting (SEC-011)
 *      - Merkle replay prevention (SEC-012)
 */
contract RewardsDistributorTest is Test {
    RewardsDistributor public distributor;
    NexusToken public rewardToken;

    address public admin = address(1);
    address public campaignManager = address(2);
    address public treasury = address(3);
    address public user1 = address(4);
    address public user2 = address(5);
    address public user3 = address(6);

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant CAMPAIGN_REWARDS = 1_000_000 * 1e18;
    uint256 public constant STREAMING_DURATION = 30 days;
    uint256 public constant MERKLE_DURATION = 90 days;
    uint256 public constant RATE_LIMIT_WINDOW = 1 hours;
    uint256 public constant MAX_CLAIMS_PER_WINDOW = 10;

    // Merkle tree data for testing
    bytes32 public merkleRoot;
    bytes32[] public user1Proof;
    bytes32[] public user2Proof;
    uint256 public user1Amount = 10000 * 1e18;
    uint256 public user2Amount = 20000 * 1e18;

    // Events
    event StreamingCampaignCreated(
        uint256 indexed campaignId,
        address indexed rewardToken,
        uint256 totalRewards,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardRate,
        string name
    );

    event MerkleCampaignCreated(
        uint256 indexed campaignId,
        address indexed rewardToken,
        uint256 totalRewards,
        bytes32 merkleRoot,
        uint256 startTime,
        uint256 expirationTime,
        string name
    );

    event StreamingRewardsClaimed(
        uint256 indexed campaignId,
        address indexed user,
        uint256 amount,
        uint256 totalClaimed
    );

    event MerkleRewardsClaimed(
        uint256 indexed campaignId,
        address indexed user,
        uint256 amount,
        uint256 leafIndex
    );

    event CampaignStatusChanged(
        uint256 indexed campaignId,
        RewardsDistributor.CampaignStatus oldStatus,
        RewardsDistributor.CampaignStatus newStatus
    );

    event AllocationSet(
        uint256 indexed campaignId,
        address indexed user,
        uint256 allocation
    );

    event TreasuryUpdated(
        address indexed oldTreasury,
        address indexed newTreasury
    );

    function setUp() public {
        vm.startPrank(admin);

        // Deploy reward token
        rewardToken = new NexusToken(admin);
        rewardToken.mint(admin, INITIAL_SUPPLY);

        // Deploy distributor
        distributor = new RewardsDistributor(treasury, admin);

        // Grant campaign manager role
        distributor.grantRole(distributor.CAMPAIGN_MANAGER_ROLE(), campaignManager);

        // Transfer tokens to campaign manager for creating campaigns
        rewardToken.transfer(campaignManager, CAMPAIGN_REWARDS * 10);

        vm.stopPrank();

        // Campaign manager approves distributor
        vm.prank(campaignManager);
        rewardToken.approve(address(distributor), type(uint256).max);

        // Setup Merkle tree for testing
        _setupMerkleTree();
    }

    /**
     * @dev Setup Merkle tree with known proofs for testing
     * Tree structure:
     *   - Leaf 0: keccak256(campaignId=1, user1, 10000e18, index=0)
     *   - Leaf 1: keccak256(campaignId=1, user2, 20000e18, index=1)
     */
    function _setupMerkleTree() internal {
        // For campaignId = 1
        uint256 campaignId = 1;

        // Calculate leaf hashes
        bytes32 leaf0 = keccak256(abi.encodePacked(campaignId, user1, user1Amount, uint256(0)));
        bytes32 leaf1 = keccak256(abi.encodePacked(campaignId, user2, user2Amount, uint256(1)));

        // For a 2-leaf tree, root = hash(sorted(leaf0, leaf1))
        if (uint256(leaf0) < uint256(leaf1)) {
            merkleRoot = keccak256(abi.encodePacked(leaf0, leaf1));
        } else {
            merkleRoot = keccak256(abi.encodePacked(leaf1, leaf0));
        }

        // Proofs for 2-leaf tree
        user1Proof = new bytes32[](1);
        user1Proof[0] = leaf1;

        user2Proof = new bytes32[](1);
        user2Proof[0] = leaf0;
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(distributor.treasury(), treasury);
        assertEq(distributor.nextCampaignId(), 1);
        assertTrue(distributor.hasRole(distributor.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(distributor.hasRole(distributor.ADMIN_ROLE(), admin));
        assertTrue(distributor.hasRole(distributor.CAMPAIGN_MANAGER_ROLE(), admin));
    }

    function test_Deployment_RevertZeroTreasury() public {
        vm.expectRevert(RewardsDistributor.ZeroAddress.selector);
        new RewardsDistributor(address(0), admin);
    }

    function test_Deployment_RevertZeroAdmin() public {
        vm.expectRevert(RewardsDistributor.ZeroAddress.selector);
        new RewardsDistributor(treasury, address(0));
    }

    // ============ Streaming Campaign Creation Tests ============

    function test_CreateStreamingCampaign() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test Campaign",
            "Test Description"
        );

        assertEq(campaignId, 1);

        (
            address tokenAddr,
            uint256 totalRewards,
            uint256 claimedRewards,
            uint256 storedStartTime,
            uint256 endTime,
            RewardsDistributor.CampaignStatus status
        ) = distributor.getStreamingCampaign(campaignId);

        assertEq(tokenAddr, address(rewardToken));
        assertEq(totalRewards, CAMPAIGN_REWARDS);
        assertEq(claimedRewards, 0);
        assertEq(storedStartTime, startTime);
        assertEq(endTime, startTime + STREAMING_DURATION);
        assertEq(uint8(status), uint8(RewardsDistributor.CampaignStatus.Active));
    }

    function test_CreateStreamingCampaign_EmitsEvent() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        vm.expectEmit(true, true, false, true);
        emit StreamingCampaignCreated(
            1,
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            startTime + STREAMING_DURATION,
            (CAMPAIGN_REWARDS * 1e18) / STREAMING_DURATION,
            "Test Campaign"
        );
        distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test Campaign",
            "Test Description"
        );
    }

    function test_CreateStreamingCampaign_RevertZeroToken() public {
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.ZeroAddress.selector);
        distributor.createStreamingCampaign(
            address(0),
            CAMPAIGN_REWARDS,
            block.timestamp + 1 hours,
            STREAMING_DURATION,
            "Test",
            "Test"
        );
    }

    function test_CreateStreamingCampaign_RevertZeroAmount() public {
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.ZeroAmount.selector);
        distributor.createStreamingCampaign(
            address(rewardToken),
            0,
            block.timestamp + 1 hours,
            STREAMING_DURATION,
            "Test",
            "Test"
        );
    }

    function test_CreateStreamingCampaign_RevertPastStartTime() public {
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.InvalidStartTime.selector);
        distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            block.timestamp - 1,
            STREAMING_DURATION,
            "Test",
            "Test"
        );
    }

    function test_CreateStreamingCampaign_RevertDurationTooShort() public {
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.InvalidDuration.selector);
        distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            block.timestamp + 1 hours,
            30 minutes, // Less than MIN_STREAMING_DURATION (1 hour)
            "Test",
            "Test"
        );
    }

    function test_CreateStreamingCampaign_RevertDurationTooLong() public {
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.InvalidDuration.selector);
        distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            block.timestamp + 1 hours,
            400 days, // More than MAX_STREAMING_DURATION (365 days)
            "Test",
            "Test"
        );
    }

    function test_CreateStreamingCampaign_RevertUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            block.timestamp + 1 hours,
            STREAMING_DURATION,
            "Test",
            "Test"
        );
    }

    // ============ Streaming Allocation Tests ============

    function test_SetAllocation() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        vm.expectEmit(true, true, false, true);
        emit AllocationSet(campaignId, user1, 100_000 * 1e18);
        distributor.setAllocation(campaignId, user1, 100_000 * 1e18);

        (uint256 lastClaimTime, uint256 totalClaimed, uint256 allocation) =
            distributor.getUserStreamingPosition(campaignId, user1);

        assertEq(lastClaimTime, startTime);
        assertEq(totalClaimed, 0);
        assertEq(allocation, 100_000 * 1e18);
    }

    function test_SetAllocationsBatch() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 100_000 * 1e18;
        allocations[1] = 200_000 * 1e18;
        allocations[2] = 300_000 * 1e18;

        vm.prank(campaignManager);
        distributor.setAllocationsBatch(campaignId, users, allocations);

        (, , uint256 alloc1) = distributor.getUserStreamingPosition(campaignId, user1);
        (, , uint256 alloc2) = distributor.getUserStreamingPosition(campaignId, user2);
        (, , uint256 alloc3) = distributor.getUserStreamingPosition(campaignId, user3);

        assertEq(alloc1, 100_000 * 1e18);
        assertEq(alloc2, 200_000 * 1e18);
        assertEq(alloc3, 300_000 * 1e18);
    }

    function test_SetAllocation_RevertCampaignNotFound() public {
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.CampaignNotFound.selector);
        distributor.setAllocation(999, user1, 100_000 * 1e18);
    }

    // ============ Streaming Rewards Claiming Tests ============

    function test_ClaimStreamingRewards() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        uint256 userAllocation = 100_000 * 1e18;
        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, userAllocation);

        // Warp to halfway through the campaign
        vm.warp(startTime + STREAMING_DURATION / 2);

        uint256 balanceBefore = rewardToken.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = distributor.claimStreamingRewards(campaignId);

        uint256 balanceAfter = rewardToken.balanceOf(user1);

        // Should claim approximately half the allocation
        assertApproxEqRel(claimed, userAllocation / 2, 0.01e18); // 1% tolerance
        assertEq(balanceAfter - balanceBefore, claimed);
    }

    function test_ClaimStreamingRewards_FullVesting() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        uint256 userAllocation = 100_000 * 1e18;
        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, userAllocation);

        // Warp past the end of the campaign
        vm.warp(startTime + STREAMING_DURATION + 1 days);

        vm.prank(user1);
        uint256 claimed = distributor.claimStreamingRewards(campaignId);

        // Should claim full allocation
        assertEq(claimed, userAllocation);
    }

    function test_ClaimStreamingRewards_MultipleClaims() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        uint256 userAllocation = 100_000 * 1e18;
        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, userAllocation);

        uint256 totalClaimed = 0;

        // Claim at 25%
        vm.warp(startTime + STREAMING_DURATION / 4);
        vm.prank(user1);
        totalClaimed += distributor.claimStreamingRewards(campaignId);

        // Claim at 50%
        vm.warp(startTime + STREAMING_DURATION / 2);
        vm.prank(user1);
        totalClaimed += distributor.claimStreamingRewards(campaignId);

        // Claim at 100%
        vm.warp(startTime + STREAMING_DURATION);
        vm.prank(user1);
        totalClaimed += distributor.claimStreamingRewards(campaignId);

        assertApproxEqRel(totalClaimed, userAllocation, 0.001e18); // 0.1% tolerance
    }

    function test_ClaimStreamingRewards_RevertNotStarted() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, 100_000 * 1e18);

        // Try to claim before start
        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.CampaignNotStarted.selector);
        distributor.claimStreamingRewards(campaignId);
    }

    function test_ClaimStreamingRewards_RevertNoAllocation() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.warp(startTime + 1 days);

        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.NoAllocation.selector);
        distributor.claimStreamingRewards(campaignId);
    }

    function test_ClaimStreamingRewards_RevertWhenPaused() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, 100_000 * 1e18);

        vm.warp(startTime + 1 days);

        vm.prank(admin);
        distributor.pause();

        vm.prank(user1);
        vm.expectRevert();
        distributor.claimStreamingRewards(campaignId);
    }

    // ============ Merkle Campaign Creation Tests ============

    function test_CreateMerkleCampaign() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Merkle Airdrop",
            "Test Airdrop"
        );

        assertEq(campaignId, 1);

        (
            address tokenAddr,
            uint256 totalRewards,
            uint256 claimedRewards,
            bytes32 storedRoot,
            uint256 storedStartTime,
            uint256 storedExpirationTime,
            RewardsDistributor.CampaignStatus status
        ) = distributor.getMerkleCampaign(campaignId);

        assertEq(tokenAddr, address(rewardToken));
        assertEq(totalRewards, CAMPAIGN_REWARDS);
        assertEq(claimedRewards, 0);
        assertEq(storedRoot, merkleRoot);
        assertEq(storedStartTime, startTime);
        assertEq(storedExpirationTime, expirationTime);
        assertEq(uint8(status), uint8(RewardsDistributor.CampaignStatus.Active));
    }

    function test_CreateMerkleCampaign_RevertInvalidMerkleRoot() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.InvalidMerkleRoot.selector);
        distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            bytes32(0),
            startTime,
            startTime + MERKLE_DURATION,
            "Test",
            "Test"
        );
    }

    function test_CreateMerkleCampaign_RevertInvalidDuration() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.InvalidDuration.selector);
        distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            startTime - 1, // Expiration before start
            "Test",
            "Test"
        );
    }

    // ============ Merkle Claims Tests - SEC-012 ============

    function test_ClaimMerkleRewards() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Merkle Airdrop",
            "Test"
        );

        // Warp to after start
        vm.warp(startTime + 1);

        uint256 balanceBefore = rewardToken.balanceOf(user1);

        vm.prank(user1);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);

        uint256 balanceAfter = rewardToken.balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, user1Amount);
        assertTrue(distributor.hasClaimed(campaignId, user1));
        assertEq(distributor.claimedAmount(campaignId, user1), user1Amount);
    }

    function test_ClaimMerkleRewards_MultipleUsers() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Merkle Airdrop",
            "Test"
        );

        vm.warp(startTime + 1);

        // User1 claims
        vm.prank(user1);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);

        // User2 claims
        vm.prank(user2);
        distributor.claimMerkleRewards(campaignId, user2Amount, 1, user2Proof);

        assertEq(rewardToken.balanceOf(user1), user1Amount);
        assertEq(rewardToken.balanceOf(user2), user2Amount);

        (,, uint256 claimedRewards,,,,) = distributor.getMerkleCampaign(campaignId);
        assertEq(claimedRewards, user1Amount + user2Amount);
    }

    function test_ClaimMerkleRewards_RevertAlreadyClaimed() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        vm.warp(startTime + 1);

        vm.prank(user1);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);

        // Try to claim again
        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.AlreadyClaimed.selector);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);
    }

    function test_ClaimMerkleRewards_RevertInvalidProof() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        vm.warp(startTime + 1);

        // Try with wrong proof
        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.InvalidMerkleProof.selector);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user2Proof); // Wrong proof
    }

    function test_ClaimMerkleRewards_RevertWrongAmount() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        vm.warp(startTime + 1);

        // Try with wrong amount
        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.InvalidMerkleProof.selector);
        distributor.claimMerkleRewards(campaignId, user2Amount, 0, user1Proof); // Wrong amount
    }

    function test_ClaimMerkleRewards_RevertExpired() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        // Warp past expiration
        vm.warp(expirationTime + 1);

        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.CampaignExpired.selector);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);
    }

    function test_ClaimMerkleRewards_RevertNotStarted() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        // Don't warp - still before start
        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.CampaignNotStarted.selector);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);
    }

    function test_VerifyMerkleProof() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        assertTrue(distributor.verifyMerkleProof(campaignId, user1, user1Amount, 0, user1Proof));
        assertTrue(distributor.verifyMerkleProof(campaignId, user2, user2Amount, 1, user2Proof));
        assertFalse(distributor.verifyMerkleProof(campaignId, user1, user2Amount, 0, user1Proof)); // Wrong amount
        assertFalse(distributor.verifyMerkleProof(campaignId, user3, user1Amount, 0, user1Proof)); // Wrong user
    }

    // ============ Rate Limiting Tests - SEC-011 ============

    function test_RateLimit_MaxClaimsPerWindow() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        // Create multiple campaigns
        for (uint256 i = 0; i < MAX_CLAIMS_PER_WINDOW + 1; i++) {
            // Create unique Merkle root for each campaign
            bytes32 uniqueRoot = keccak256(abi.encodePacked("root", i));

            vm.prank(campaignManager);
            distributor.createMerkleCampaign(
                address(rewardToken),
                CAMPAIGN_REWARDS / 20,
                uniqueRoot,
                startTime,
                expirationTime,
                "Test",
                "Test"
            );
        }

        vm.warp(startTime + 1);

        // Create streaming campaign for rate limit testing
        vm.prank(campaignManager);
        uint256 streamingId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            block.timestamp,
            STREAMING_DURATION,
            "Stream",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.setAllocation(streamingId, user1, 100_000 * 1e18);

        // Claim MAX_CLAIMS_PER_WINDOW times
        for (uint256 i = 0; i < MAX_CLAIMS_PER_WINDOW; i++) {
            vm.warp(block.timestamp + 1 hours / MAX_CLAIMS_PER_WINDOW);
            vm.prank(user1);
            distributor.claimStreamingRewards(streamingId);
        }

        // 11th claim should fail
        vm.prank(user1);
        vm.expectRevert(RewardsDistributor.RateLimitExceeded_Error.selector);
        distributor.claimStreamingRewards(streamingId);
    }

    function test_RateLimit_WindowReset() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, 100_000 * 1e18);

        vm.warp(startTime + 1);

        // Use up rate limit
        for (uint256 i = 0; i < MAX_CLAIMS_PER_WINDOW; i++) {
            vm.warp(block.timestamp + 1 minutes);
            vm.prank(user1);
            distributor.claimStreamingRewards(campaignId);
        }

        // Wait for window to reset
        vm.warp(block.timestamp + RATE_LIMIT_WINDOW + 1);

        // Should be able to claim again
        vm.prank(user1);
        distributor.claimStreamingRewards(campaignId);
    }

    function test_CanUserClaim() public view {
        (bool canClaim, uint256 remainingClaims) = distributor.canUserClaim(user1);
        assertTrue(canClaim);
        assertEq(remainingClaims, MAX_CLAIMS_PER_WINDOW);
    }

    // ============ Campaign Management Tests ============

    function test_PauseCampaign_Streaming() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.pauseCampaign(campaignId, false);

        (,,,,,RewardsDistributor.CampaignStatus status) = distributor.getStreamingCampaign(campaignId);
        assertEq(uint8(status), uint8(RewardsDistributor.CampaignStatus.Paused));
    }

    function test_ResumeCampaign_Streaming() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.pauseCampaign(campaignId, false);

        vm.prank(campaignManager);
        distributor.resumeCampaign(campaignId, false);

        (,,,,,RewardsDistributor.CampaignStatus status) = distributor.getStreamingCampaign(campaignId);
        assertEq(uint8(status), uint8(RewardsDistributor.CampaignStatus.Active));
    }

    function test_CancelCampaign_Streaming() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        uint256 treasuryBalanceBefore = rewardToken.balanceOf(treasury);

        vm.prank(admin);
        distributor.cancelCampaign(campaignId, false);

        uint256 treasuryBalanceAfter = rewardToken.balanceOf(treasury);

        (,,,,,RewardsDistributor.CampaignStatus status) = distributor.getStreamingCampaign(campaignId);
        assertEq(uint8(status), uint8(RewardsDistributor.CampaignStatus.Cancelled));
        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, CAMPAIGN_REWARDS);
    }

    function test_ReclaimExpiredFunds() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        // Warp past expiration
        vm.warp(expirationTime + 1);

        uint256 treasuryBalanceBefore = rewardToken.balanceOf(treasury);

        vm.prank(admin);
        distributor.reclaimExpiredFunds(campaignId);

        uint256 treasuryBalanceAfter = rewardToken.balanceOf(treasury);

        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, CAMPAIGN_REWARDS);
    }

    function test_UpdateMerkleRoot() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        bytes32 newRoot = keccak256("new root");

        vm.prank(campaignManager);
        distributor.updateMerkleRoot(campaignId, newRoot);

        (,,, bytes32 storedRoot,,,) = distributor.getMerkleCampaign(campaignId);
        assertEq(storedRoot, newRoot);
    }

    function test_UpdateMerkleRoot_RevertAfterClaims() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 expirationTime = startTime + MERKLE_DURATION;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createMerkleCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            merkleRoot,
            startTime,
            expirationTime,
            "Test",
            "Test"
        );

        vm.warp(startTime + 1);

        // Make a claim
        vm.prank(user1);
        distributor.claimMerkleRewards(campaignId, user1Amount, 0, user1Proof);

        // Try to update root
        vm.prank(campaignManager);
        vm.expectRevert(RewardsDistributor.AlreadyClaimed.selector);
        distributor.updateMerkleRoot(campaignId, keccak256("new root"));
    }

    // ============ Admin Functions Tests ============

    function test_SetTreasury() public {
        address newTreasury = address(100);

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit TreasuryUpdated(treasury, newTreasury);
        distributor.setTreasury(newTreasury);

        assertEq(distributor.treasury(), newTreasury);
    }

    function test_SetTreasury_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(RewardsDistributor.ZeroAddress.selector);
        distributor.setTreasury(address(0));
    }

    function test_SetTreasury_RevertUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        distributor.setTreasury(address(100));
    }

    function test_Pause() public {
        vm.prank(admin);
        distributor.pause();

        assertTrue(distributor.paused());
    }

    function test_Unpause() public {
        vm.prank(admin);
        distributor.pause();

        vm.prank(admin);
        distributor.unpause();

        assertFalse(distributor.paused());
    }

    // ============ View Functions Tests ============

    function test_GetClaimableStreaming() public {
        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        uint256 userAllocation = 100_000 * 1e18;
        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, userAllocation);

        // Before start - should be 0
        uint256 claimable = distributor.getClaimableStreaming(campaignId, user1);
        assertEq(claimable, 0);

        // At 50%
        vm.warp(startTime + STREAMING_DURATION / 2);
        claimable = distributor.getClaimableStreaming(campaignId, user1);
        assertApproxEqRel(claimable, userAllocation / 2, 0.01e18);

        // At 100%
        vm.warp(startTime + STREAMING_DURATION);
        claimable = distributor.getClaimableStreaming(campaignId, user1);
        assertEq(claimable, userAllocation);
    }

    function test_GetActiveStreamingCampaignCount() public {
        uint256 startTime = block.timestamp + 1 hours;

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(campaignManager);
            distributor.createStreamingCampaign(
                address(rewardToken),
                CAMPAIGN_REWARDS / 10,
                startTime,
                STREAMING_DURATION,
                "Test",
                "Test"
            );
        }

        assertEq(distributor.getActiveStreamingCampaignCount(), 3);
    }

    function test_GetActiveMerkleCampaignCount() public {
        uint256 startTime = block.timestamp + 1 hours;

        for (uint256 i = 0; i < 2; i++) {
            vm.prank(campaignManager);
            distributor.createMerkleCampaign(
                address(rewardToken),
                CAMPAIGN_REWARDS / 10,
                keccak256(abi.encodePacked("root", i)),
                startTime,
                startTime + MERKLE_DURATION,
                "Test",
                "Test"
            );
        }

        assertEq(distributor.getActiveMerkleCampaignCount(), 2);
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateStreamingCampaign(uint256 rewards, uint256 duration) public {
        rewards = bound(rewards, 1, CAMPAIGN_REWARDS);
        duration = bound(duration, 1 hours, 365 days);

        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            rewards,
            startTime,
            duration,
            "Fuzz Test",
            "Test"
        );

        (
            address tokenAddr,
            uint256 totalRewards,
            ,
            uint256 storedStartTime,
            uint256 endTime,
        ) = distributor.getStreamingCampaign(campaignId);

        assertEq(tokenAddr, address(rewardToken));
        assertEq(totalRewards, rewards);
        assertEq(storedStartTime, startTime);
        assertEq(endTime, startTime + duration);
    }

    function testFuzz_StreamingClaim(uint256 allocation, uint256 timeElapsed) public {
        allocation = bound(allocation, 1e18, CAMPAIGN_REWARDS);
        timeElapsed = bound(timeElapsed, 0, STREAMING_DURATION);

        uint256 startTime = block.timestamp + 1 hours;

        vm.prank(campaignManager);
        uint256 campaignId = distributor.createStreamingCampaign(
            address(rewardToken),
            CAMPAIGN_REWARDS,
            startTime,
            STREAMING_DURATION,
            "Test",
            "Test"
        );

        vm.prank(campaignManager);
        distributor.setAllocation(campaignId, user1, allocation);

        vm.warp(startTime + timeElapsed);

        if (timeElapsed == 0) {
            vm.prank(user1);
            vm.expectRevert(RewardsDistributor.NothingToClaim.selector);
            distributor.claimStreamingRewards(campaignId);
        } else {
            uint256 expectedClaimable = (allocation * timeElapsed) / STREAMING_DURATION;
            uint256 actualClaimable = distributor.getClaimableStreaming(campaignId, user1);

            // Allow for rounding
            assertApproxEqAbs(actualClaimable, expectedClaimable, 1);
        }
    }
}
