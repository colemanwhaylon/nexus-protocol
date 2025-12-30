// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VulnerableOracle
 * @author Nexus Protocol (Educational)
 * @notice VULNERABLE - DO NOT USE IN PRODUCTION
 * @dev This contract demonstrates oracle and price manipulation vulnerabilities:
 *
 * VULNERABILITIES:
 * 1. Spot Price Manipulation - Uses current pool reserves (flash loan attackable)
 * 2. Single Source - No aggregation from multiple oracles
 * 3. No Staleness Check - Doesn't verify if price is recent
 * 4. No Bounds Checking - Accepts any price without sanity limits
 * 5. Centralized Update - Single address can set any price
 *
 * Attack scenario: Attacker takes flash loan, manipulates pool reserves,
 * reads manipulated price from this oracle, exploits dependent contracts,
 * repays flash loan with profit.
 *
 * See SecureOracle.sol for the corrected implementation.
 */
contract VulnerableOracle {
    address public token0;
    address public token1;
    address public liquidityPool;
    address public priceUpdater;

    uint256 public manualPrice;
    uint256 public lastUpdateTime;

    event PriceUpdated(uint256 price, uint256 timestamp);

    constructor(address _token0, address _token1, address _pool, address _updater) {
        token0 = _token0;
        token1 = _token1;
        liquidityPool = _pool;
        priceUpdater = _updater;
    }

    // VULNERABILITY 1: Spot price from pool reserves - easily manipulated
    function getSpotPrice() public view returns (uint256) {
        uint256 reserve0 = IERC20(token0).balanceOf(liquidityPool);
        uint256 reserve1 = IERC20(token1).balanceOf(liquidityPool);

        // VULNERABLE: Current reserves can be manipulated within a transaction
        // via flash loans or large swaps
        return (reserve1 * 1e18) / reserve0;
    }

    // VULNERABILITY 5: Anyone who is priceUpdater can set any price
    // No validation, no multi-sig, no delay
    function setManualPrice(uint256 _price) external {
        require(msg.sender == priceUpdater, "Not updater");
        // VULNERABLE: No bounds checking - can set to 0 or extreme values
        manualPrice = _price;
        lastUpdateTime = block.timestamp;
        emit PriceUpdated(_price, block.timestamp);
    }

    // VULNERABILITY 2 & 3: Uses spot price, no staleness check
    function getPrice() external view returns (uint256) {
        if (manualPrice > 0) {
            // VULNERABLE: No staleness check on manual price
            return manualPrice;
        }
        // VULNERABLE: Falls back to manipulatable spot price
        return getSpotPrice();
    }

    // VULNERABILITY 4: No sanity bounds on price
    function validatePrice(uint256 price) external pure returns (bool) {
        // VULNERABLE: Accepts any non-zero price
        return price > 0;
    }

    // Used by lending protocols - highly exploitable
    function getCollateralValue(address user, address token, uint256 amount) external view returns (uint256) {
        uint256 price = this.getPrice();
        // VULNERABLE: Uses potentially manipulated price for collateral valuation
        return (amount * price) / 1e18;
    }
}
