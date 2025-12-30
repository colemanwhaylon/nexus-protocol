// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title VulnerableVault
 * @author Nexus Protocol (Educational)
 * @notice VULNERABLE - DO NOT USE IN PRODUCTION
 * @dev This contract demonstrates common smart contract vulnerabilities:
 *
 * VULNERABILITIES:
 * 1. Reentrancy - withdraw() makes external call before state update
 * 2. Access Control - no ownership or role checks on sensitive functions
 * 3. Denial of Service - unbounded loop in emergencyDrain()
 * 4. Front-running - predictable withdrawal amounts
 * 5. Missing Input Validation - no checks on deposit amounts
 *
 * See SecureVault.sol for the corrected implementation.
 */
contract VulnerableVault {
    mapping(address => uint256) public balances;
    address[] public depositors;
    bool public paused;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    // VULNERABILITY 1: No access control - anyone can pause
    function setPaused(bool _paused) external {
        paused = _paused;
    }

    // VULNERABILITY 5: No minimum deposit validation
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        depositors.push(msg.sender);
        emit Deposit(msg.sender, msg.value);
    }

    // VULNERABILITY 1: Reentrancy - external call before state update
    // An attacker can recursively call withdraw() before balance is set to 0
    function withdraw() external {
        require(!paused, "Paused");
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        // VULNERABLE: External call BEFORE state update
        (bool success,) = msg.sender.call{ value: amount }("");
        require(success, "Transfer failed");

        // State update happens AFTER external call - attacker can re-enter
        balances[msg.sender] = 0;

        emit Withdrawal(msg.sender, amount);
    }

    // VULNERABILITY 3: Denial of Service - unbounded loop
    // If depositors array grows too large, this function will run out of gas
    function emergencyDrain(address payable recipient) external {
        // VULNERABLE: Unbounded loop over all depositors
        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 amount = balances[depositors[i]];
            if (amount > 0) {
                balances[depositors[i]] = 0;
                (bool success,) = recipient.call{ value: amount }("");
                require(success, "Transfer failed");
            }
        }
    }

    // VULNERABILITY 2: No access control on admin function
    function updateBalance(address user, uint256 amount) external {
        // Anyone can arbitrarily set balances!
        balances[user] = amount;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        depositors.push(msg.sender);
    }
}
