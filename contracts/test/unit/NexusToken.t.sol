// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {NexusToken} from "../../src/core/NexusToken.sol";

/**
 * @title NexusTokenTest
 * @notice Unit tests for NexusToken contract
 * @dev Tests cover:
 *      - Deployment and initialization
 *      - ERC20 basic functionality (transfer, approve, transferFrom)
 *      - ERC20Permit (gasless approvals)
 *      - ERC20Votes (delegation, voting power)
 *      - ERC20FlashMint (flash loans)
 *      - Access control (minting, burning)
 */
contract NexusTokenTest is Test {
    NexusToken public token;

    address public admin = address(1);
    address public minter = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public user3 = address(5);

    uint256 public constant INITIAL_MINT = 100_000_000 * 1e18; // 100M tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1B tokens
    uint256 public constant MINT_AMOUNT = 1_000_000 * 1e18; // 1M tokens
    uint256 public constant FLASH_LOAN_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);

    function setUp() public {
        vm.startPrank(admin);
        token = new NexusToken(admin);
        // Mint initial supply to admin (contract doesn't mint on construction)
        token.mint(admin, INITIAL_MINT);
        vm.stopPrank();
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(token.name(), "Nexus Token");
        assertEq(token.symbol(), "NEXUS");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_MINT);
        assertEq(token.balanceOf(admin), INITIAL_MINT);
    }

    function test_AdminHasRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), admin));
    }

    // ============ Transfer Tests ============

    function test_Transfer() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(admin, user1, amount);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(admin), INITIAL_MINT - amount);
    }

    function test_Transfer_RevertInsufficientBalance() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, amount);
    }

    function test_Transfer_RevertToZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert();
        token.transfer(address(0), 1000);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_MINT);

        vm.prank(admin);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }

    // ============ Approval Tests ============

    function test_Approve() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit Approval(admin, user1, amount);
        token.approve(user1, amount);

        assertEq(token.allowance(admin, user1), amount);
    }

    function test_TransferFrom() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        token.approve(user1, amount);

        vm.prank(user1);
        token.transferFrom(admin, user2, amount);

        assertEq(token.balanceOf(user2), amount);
        assertEq(token.allowance(admin, user1), 0);
    }

    function test_TransferFrom_RevertInsufficientAllowance() public {
        vm.prank(admin);
        token.approve(user1, 500 * 1e18);

        vm.prank(user1);
        vm.expectRevert();
        token.transferFrom(admin, user2, 1000 * 1e18);
    }

    // ============ Delegation Tests ============

    function test_Delegate() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        token.transfer(user1, amount);

        vm.prank(user1);
        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(user1, address(0), user2);
        token.delegate(user2);

        assertEq(token.delegates(user1), user2);
        assertEq(token.getVotes(user2), amount);
    }

    function test_SelfDelegate() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        token.transfer(user1, amount);

        vm.prank(user1);
        token.delegate(user1);

        assertEq(token.delegates(user1), user1);
        assertEq(token.getVotes(user1), amount);
    }

    function test_DelegateVotesChange() public {
        uint256 amount1 = 1000 * 1e18;
        uint256 amount2 = 500 * 1e18;

        vm.startPrank(admin);
        token.transfer(user1, amount1);
        token.transfer(user2, amount2);
        vm.stopPrank();

        vm.prank(user1);
        token.delegate(user3);

        vm.prank(user2);
        token.delegate(user3);

        assertEq(token.getVotes(user3), amount1 + amount2);
    }

    // ============ Minting Tests ============

    function test_Mint() public {
        uint256 supplyBefore = token.totalSupply();

        vm.prank(admin);
        token.mint(user1, MINT_AMOUNT);

        assertEq(token.balanceOf(user1), MINT_AMOUNT);
        assertEq(token.totalSupply(), supplyBefore + MINT_AMOUNT);
    }

    function test_Mint_OnlyMinterRole() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, MINT_AMOUNT);
    }

    function test_Mint_GrantMinterRole() public {
        // Admin grants MINTER_ROLE to minter
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        // Minter can now mint
        vm.prank(minter);
        token.mint(user1, MINT_AMOUNT);

        assertEq(token.balanceOf(user1), MINT_AMOUNT);
    }

    // ============ Burning Tests ============

    function test_Burn() public {
        uint256 burnAmount = 1000 * 1e18;
        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(admin);

        vm.prank(admin);
        token.burn(burnAmount);

        assertEq(token.balanceOf(admin), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
    }

    function test_BurnFrom() public {
        uint256 burnAmount = 1000 * 1e18;

        vm.prank(admin);
        token.transfer(user1, burnAmount * 2);

        vm.prank(user1);
        token.approve(admin, burnAmount);

        vm.prank(admin);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), burnAmount);
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        vm.prank(admin);
        token.pause();

        assertTrue(token.paused());

        vm.prank(admin);
        vm.expectRevert();
        token.transfer(user1, 1000);
    }

    function test_Unpause() public {
        vm.prank(admin);
        token.pause();

        vm.prank(admin);
        token.unpause();

        assertFalse(token.paused());

        vm.prank(admin);
        token.transfer(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
    }

    function test_Pause_OnlyPauserRole() public {
        vm.prank(user1);
        vm.expectRevert();
        token.pause();
    }

    // ============ Flash Loan Tests ============

    function test_MaxFlashLoan() public view {
        uint256 maxLoan = token.maxFlashLoan(address(token));
        // maxFlashLoan = MAX_SUPPLY - totalSupply
        assertEq(maxLoan, MAX_SUPPLY - token.totalSupply());
    }

    function test_FlashFee() public view {
        uint256 amount = 1_000_000 * 1e18;
        uint256 fee = token.flashFee(address(token), amount);
        // Fee = ceil(amount * FLASH_LOAN_FEE_BPS / BPS_DENOMINATOR)
        uint256 expectedFee = (amount * FLASH_LOAN_FEE_BPS + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        assertEq(fee, expectedFee);
    }

    // ============ Permit Tests ============

    function test_Permit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        token.transfer(owner, amount);

        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        user1,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, permitHash);

        token.permit(owner, user1, amount, deadline, v, r, s);

        assertEq(token.allowance(owner, user1), amount);
    }

    // ============ Historical Voting Power Tests ============

    function test_GetPastVotes() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(admin);
        token.transfer(user1, amount);

        vm.prank(user1);
        token.delegate(user1);

        uint256 blockNumber = block.number;

        // Move forward one block
        vm.roll(block.number + 1);

        assertEq(token.getPastVotes(user1, blockNumber), amount);
    }

    function test_GetPastTotalSupply() public {
        uint256 blockNumber = block.number;
        uint256 currentSupply = token.totalSupply();

        // Move forward one block
        vm.roll(block.number + 1);

        assertEq(token.getPastTotalSupply(blockNumber), currentSupply);
    }

    // ============ Edge Cases ============

    function test_TransferZeroAmount() public {
        vm.prank(admin);
        token.transfer(user1, 0);

        assertEq(token.balanceOf(user1), 0);
    }

    function test_ApproveMaxUint() public {
        vm.prank(admin);
        token.approve(user1, type(uint256).max);

        assertEq(token.allowance(admin, user1), type(uint256).max);
    }

    function test_DelegateToZeroAddress() public {
        vm.prank(admin);
        token.delegate(address(0));

        assertEq(token.delegates(admin), address(0));
    }
}
