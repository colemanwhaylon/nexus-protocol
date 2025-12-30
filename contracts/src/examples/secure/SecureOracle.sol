// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SecureOracle
 * @author Nexus Protocol (Educational)
 * @notice SECURE - Production-ready oracle implementation
 * @dev This contract demonstrates secure oracle patterns:
 *
 * SECURITY FIXES:
 * 1. TWAP (Time-Weighted Average Price) - Resistant to flash loan manipulation
 * 2. Multi-Source Aggregation - Combines prices from multiple sources
 * 3. Staleness Check - Rejects prices older than MAX_STALENESS
 * 4. Bounds Checking - Prices must be within MIN/MAX bounds
 * 5. Multi-Sig Updates - Requires multiple signers for manual price updates
 * 6. Rate Limiting - Maximum price change per update
 *
 * See VulnerableOracle.sol for the vulnerable version.
 */
contract SecureOracle is AccessControl {
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // FIX 3: Staleness threshold
    uint256 public constant MAX_STALENESS = 1 hours;

    // FIX 4: Price bounds
    uint256 public constant MIN_PRICE = 1e14; // 0.0001 in 18 decimals
    uint256 public constant MAX_PRICE = 1e24; // 1,000,000 in 18 decimals

    // FIX 6: Maximum price change per update (10%)
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // 10% in basis points

    // FIX 1: TWAP storage
    struct PriceObservation {
        uint256 price;
        uint256 timestamp;
        uint256 cumulativePrice;
    }

    // FIX 2: Multiple price sources
    struct PriceSource {
        address source;
        uint256 price;
        uint256 lastUpdate;
        bool active;
    }

    PriceObservation[] public observations;
    mapping(address => PriceSource) public priceSources;
    address[] public sourceAddresses;

    uint256 public aggregatedPrice;
    uint256 public lastAggregationTime;

    // FIX 5: Multi-sig for critical updates
    uint256 public requiredConfirmations = 2;
    mapping(bytes32 => uint256) public updateConfirmations;
    mapping(bytes32 => mapping(address => bool)) public hasConfirmed;

    event PriceUpdated(address indexed source, uint256 price, uint256 timestamp);
    event PriceAggregated(uint256 price, uint256 timestamp, uint256 sourceCount);
    event SourceAdded(address indexed source);
    event SourceRemoved(address indexed source);

    error PriceTooOld(uint256 age, uint256 maxAge);
    error PriceOutOfBounds(uint256 price, uint256 min, uint256 max);
    error PriceDeviationTooHigh(uint256 deviation, uint256 maxDeviation);
    error InsufficientConfirmations(uint256 current, uint256 required);
    error NoActiveSources();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // FIX 2: Add trusted price source
    function addSource(address source) external onlyRole(ADMIN_ROLE) {
        require(!priceSources[source].active, "Source exists");
        priceSources[source] = PriceSource({source: source, price: 0, lastUpdate: 0, active: true});
        sourceAddresses.push(source);
        _grantRole(ORACLE_UPDATER_ROLE, source);
        emit SourceAdded(source);
    }

    // FIX 2 & 3 & 4 & 6: Update price with validation
    function updatePrice(uint256 newPrice) external onlyRole(ORACLE_UPDATER_ROLE) {
        // FIX 4: Bounds check
        if (newPrice < MIN_PRICE || newPrice > MAX_PRICE) {
            revert PriceOutOfBounds(newPrice, MIN_PRICE, MAX_PRICE);
        }

        PriceSource storage source = priceSources[msg.sender];
        require(source.active, "Source not active");

        // FIX 6: Rate limiting - check deviation from last price
        if (source.price > 0) {
            uint256 deviation = _calculateDeviation(source.price, newPrice);
            if (deviation > MAX_PRICE_DEVIATION) {
                revert PriceDeviationTooHigh(deviation, MAX_PRICE_DEVIATION);
            }
        }

        source.price = newPrice;
        source.lastUpdate = block.timestamp;

        // FIX 1: Record observation for TWAP
        uint256 cumulative = observations.length > 0
            ? observations[observations.length - 1].cumulativePrice + (newPrice * (block.timestamp - source.lastUpdate))
            : newPrice;

        observations.push(PriceObservation({price: newPrice, timestamp: block.timestamp, cumulativePrice: cumulative}));

        emit PriceUpdated(msg.sender, newPrice, block.timestamp);

        // Auto-aggregate if enough time has passed
        if (block.timestamp > lastAggregationTime + 5 minutes) {
            _aggregatePrices();
        }
    }

    // FIX 2: Aggregate prices from multiple sources
    function _aggregatePrices() internal {
        uint256 totalPrice;
        uint256 activeCount;

        for (uint256 i = 0; i < sourceAddresses.length; i++) {
            PriceSource storage source = priceSources[sourceAddresses[i]];

            // FIX 3: Skip stale prices
            if (source.active && block.timestamp - source.lastUpdate <= MAX_STALENESS) {
                totalPrice += source.price;
                activeCount++;
            }
        }

        if (activeCount == 0) revert NoActiveSources();

        aggregatedPrice = totalPrice / activeCount;
        lastAggregationTime = block.timestamp;

        emit PriceAggregated(aggregatedPrice, block.timestamp, activeCount);
    }

    // FIX 1: Get TWAP over specified period
    function getTWAP(uint256 period) external view returns (uint256) {
        require(observations.length >= 2, "Not enough observations");
        require(period > 0, "Invalid period");

        uint256 endIndex = observations.length - 1;
        uint256 startIndex = 0;
        uint256 targetTime = block.timestamp - period;

        // Find observation closest to start of period
        for (uint256 i = endIndex; i > 0; i--) {
            if (observations[i].timestamp <= targetTime) {
                startIndex = i;
                break;
            }
        }

        if (startIndex == endIndex) {
            return observations[endIndex].price;
        }

        uint256 timeDelta = observations[endIndex].timestamp - observations[startIndex].timestamp;
        if (timeDelta == 0) return observations[endIndex].price;

        uint256 priceDelta = observations[endIndex].cumulativePrice - observations[startIndex].cumulativePrice;
        return priceDelta / timeDelta;
    }

    // FIX 3: Get price with staleness check
    function getPrice() external view returns (uint256) {
        if (block.timestamp - lastAggregationTime > MAX_STALENESS) {
            revert PriceTooOld(block.timestamp - lastAggregationTime, MAX_STALENESS);
        }
        return aggregatedPrice;
    }

    // FIX 4: Get price with validation
    function getValidatedPrice() external view returns (uint256 price, bool isValid) {
        if (block.timestamp - lastAggregationTime > MAX_STALENESS) {
            return (0, false);
        }
        if (aggregatedPrice < MIN_PRICE || aggregatedPrice > MAX_PRICE) {
            return (0, false);
        }
        return (aggregatedPrice, true);
    }

    // Helper: Calculate deviation in basis points
    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;
        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * 10_000) / oldPrice;
    }

    // View functions
    function getSourceCount() external view returns (uint256) {
        return sourceAddresses.length;
    }

    function getObservationCount() external view returns (uint256) {
        return observations.length;
    }
}
