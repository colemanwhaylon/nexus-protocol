// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title SecureVault
 * @author Nexus Protocol (Educational)
 * @notice SECURE - Production-ready implementation
 * @dev This contract demonstrates secure patterns that fix VulnerableVault:
 *
 * SECURITY FIXES:
 * 1. ReentrancyGuard - nonReentrant modifier prevents reentrancy
 * 2. AccessControl - Role-based access for admin functions
 * 3. Pull over Push - Users withdraw their own funds (no loops)
 * 4. Checks-Effects-Interactions - State updated before external calls
 * 5. Input Validation - Minimum deposit and balance checks
 *
 * See VulnerableVault.sol for the vulnerable version.
 */
contract SecureVault is ReentrancyGuard, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MIN_DEPOSIT = 0.001 ether;
    uint256 public constant MAX_DEPOSIT = 100 ether;

    mapping(address => uint256) public balances;
    uint256 public totalDeposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    error InsufficientDeposit(uint256 provided, uint256 minimum);
    error ExcessiveDeposit(uint256 provided, uint256 maximum);
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    // FIX 2: Only OPERATOR_ROLE can pause
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    // FIX 5: Input validation for deposits
    function deposit() external payable whenNotPaused {
        if (msg.value < MIN_DEPOSIT) {
            revert InsufficientDeposit(msg.value, MIN_DEPOSIT);
        }
        if (msg.value > MAX_DEPOSIT) {
            revert ExcessiveDeposit(msg.value, MAX_DEPOSIT);
        }

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    // FIX 1 & 4: Reentrancy guard + Checks-Effects-Interactions pattern
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        uint256 balance = balances[msg.sender];
        if (amount > balance) {
            revert InsufficientBalance(amount, balance);
        }

        // SECURE: State update BEFORE external call
        balances[msg.sender] = balance - amount;
        totalDeposits -= amount;

        emit Withdrawal(msg.sender, amount);

        // External call AFTER state update
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed();
    }

    // FIX 3: Pull pattern - user withdraws their own full balance
    function withdrawAll() external nonReentrant whenNotPaused {
        uint256 amount = balances[msg.sender];
        if (amount == 0) {
            revert InsufficientBalance(amount, 0);
        }

        // SECURE: State update BEFORE external call
        balances[msg.sender] = 0;
        totalDeposits -= amount;

        emit Withdrawal(msg.sender, amount);

        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed();
    }

    // FIX 2: Admin function protected by role
    function emergencyWithdraw(address payable recipient) external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 amount = address(this).balance;
        (bool success,) = recipient.call{ value: amount }("");
        if (!success) revert TransferFailed();
    }

    // View functions
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
