// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ERC20FlashMintUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

/**
 * @title NexusTokenUpgradeable
 * @notice UUPS upgradeable version of NexusToken
 * @dev ERC20 with Votes, Permit, FlashMint, Pausable, and Burnable
 */
contract NexusTokenUpgradeable is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC20FlashMintUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18; // 1 billion tokens
    uint256 public constant FLASH_LOAN_FEE_BPS = 10; // 0.1%

    uint256 private _currentSnapshotId;

    // Snapshot storage
    mapping(uint256 snapshotId => mapping(address account => uint256 balance)) private _snapshotBalances;
    mapping(uint256 snapshotId => uint256 supply) private _snapshotTotalSupply;
    mapping(uint256 snapshotId => mapping(address account => bool)) private _snapshotted;

    event Snapshot(uint256 indexed id);

    error MaxSupplyExceeded();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     * @param admin Address to receive admin roles
     */
    function initialize(address admin) public initializer {
        __ERC20_init("Nexus Token", "NEXUS");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __ERC20Permit_init("Nexus Token");
        __ERC20Votes_init();
        __ERC20FlashMint_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(SNAPSHOT_ROLE, admin);
    }

    /**
     * @notice Mint new tokens
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }
        _mint(to, amount);
    }

    /**
     * @notice Pause all token transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause token transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Create a new snapshot
     * @return snapshotId The ID of the new snapshot
     */
    function snapshot() external onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        _currentSnapshotId++;
        emit Snapshot(_currentSnapshotId);
        return _currentSnapshotId;
    }

    /**
     * @notice Get current snapshot ID
     */
    function getCurrentSnapshotId() external view returns (uint256) {
        return _currentSnapshotId;
    }

    /**
     * @notice Get balance at snapshot
     * @param account Address to query
     * @param snapshotId Snapshot ID
     */
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _currentSnapshotId, "Invalid snapshot");
        if (_snapshotted[snapshotId][account]) {
            return _snapshotBalances[snapshotId][account];
        }
        return balanceOf(account);
    }

    /**
     * @notice Get total supply at snapshot
     * @param snapshotId Snapshot ID
     */
    function totalSupplyAt(uint256 snapshotId) external view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _currentSnapshotId, "Invalid snapshot");
        if (_snapshotTotalSupply[snapshotId] > 0) {
            return _snapshotTotalSupply[snapshotId];
        }
        return totalSupply();
    }

    /**
     * @notice Flash loan fee calculation
     */
    function flashFee(address token, uint256 amount) public view override returns (uint256) {
        require(token == address(this), "Invalid token");
        return (amount * FLASH_LOAN_FEE_BPS + 9999) / 10000; // Ceiling division
    }

    /**
     * @notice Maximum flash loan amount
     */
    function maxFlashLoan(address token) public view override returns (uint256) {
        if (token != address(this)) return 0;
        return MAX_SUPPLY - totalSupply();
    }

    // Override required functions
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        // Update snapshots before transfer
        if (_currentSnapshotId > 0) {
            if (from != address(0) && !_snapshotted[_currentSnapshotId][from]) {
                _snapshotBalances[_currentSnapshotId][from] = balanceOf(from);
                _snapshotted[_currentSnapshotId][from] = true;
            }
            if (to != address(0) && !_snapshotted[_currentSnapshotId][to]) {
                _snapshotBalances[_currentSnapshotId][to] = balanceOf(to);
                _snapshotted[_currentSnapshotId][to] = true;
            }
            if (_snapshotTotalSupply[_currentSnapshotId] == 0) {
                _snapshotTotalSupply[_currentSnapshotId] = totalSupply();
            }
        }

        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Get implementation version
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
