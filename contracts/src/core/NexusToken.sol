// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

/**
 * @title NexusToken
 * @author Nexus Protocol Team
 * @notice The primary governance and utility token for the Nexus Protocol ecosystem.
 * @dev Implements ERC-20 with the following extensions:
 *      - ERC20Votes: Enables on-chain governance voting with delegation
 *      - ERC20Permit: Gasless approvals via EIP-2612 signatures
 *      - ERC20FlashMint: ERC-3156 compliant flash loan functionality
 *      - Custom Snapshots: Historical balance queries at specific block numbers
 *      - AccessControl: Role-based access control for privileged operations
 *      - Pausable: Emergency pause functionality for all transfers
 *
 * Security Considerations:
 *      - SEC-007: All calculations use explicit rounding (round DOWN for user claims, UP for debts)
 *      - SEC-013: Events emitted for all state changes
 *      - SEC-015: All unchecked blocks documented with safety proofs
 *
 * Supply Cap: 1 billion tokens (1e27 with 18 decimals)
 */
contract NexusToken is ERC20, ERC20Permit, ERC20Votes, ERC20FlashMint, AccessControl, Pausable {
    using Checkpoints for Checkpoints.Trace208;
    using SafeCast for uint256;

    // ============ Constants ============

    /// @notice Maximum total supply: 1 billion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice Flash loan fee in basis points (0.1% = 10 bps)
    uint256 public constant FLASH_LOAN_FEE_BPS = 10;

    /// @notice Basis points denominator for fee calculations
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // ============ Roles ============

    /// @notice Role for administrative functions (role management, fee configuration)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for minting new tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role for pausing/unpausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============ State Variables ============

    /// @notice Counter for snapshot IDs, incremented for each new snapshot
    uint256 private _currentSnapshotId;

    /// @notice Mapping from snapshot ID to the block number at which it was taken
    mapping(uint256 snapshotId => uint256 blockNumber) private _snapshotBlocks;

    /// @notice Per-account balance snapshots using Checkpoints library
    mapping(address account => Checkpoints.Trace208) private _accountBalanceCheckpoints;

    /// @notice Total supply snapshots using Checkpoints library
    Checkpoints.Trace208 private _totalSupplyCheckpoints;

    /// @notice Address that receives flash loan fees (zero address = fees are burned)
    address public flashFeeReceiver;

    // ============ Events ============

    /// @notice Emitted when a new snapshot is created
    /// @param id The snapshot ID
    /// @param blockNumber The block number at which the snapshot was taken
    event Snapshot(uint256 indexed id, uint256 blockNumber);

    /// @notice Emitted when the flash fee receiver is updated
    /// @param previousReceiver The previous fee receiver address
    /// @param newReceiver The new fee receiver address
    event FlashFeeReceiverUpdated(address indexed previousReceiver, address indexed newReceiver);

    /// @notice Emitted when tokens are minted
    /// @param to The recipient of the minted tokens
    /// @param amount The amount of tokens minted
    /// @param minter The address that triggered the mint
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);

    /// @notice Emitted when tokens are burned
    /// @param from The address whose tokens were burned
    /// @param amount The amount of tokens burned
    event TokensBurned(address indexed from, uint256 amount);

    /// @notice Emitted when a flash loan is executed
    /// @param receiver The flash loan receiver contract
    /// @param token The token address (always this contract)
    /// @param amount The loan amount
    /// @param fee The fee charged for the loan
    event FlashLoanExecuted(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );

    // ============ Errors ============

    /// @notice Thrown when minting would exceed the maximum supply cap
    /// @param requested The amount requested to mint
    /// @param available The remaining mintable amount before cap
    error ExceedsMaxSupply(uint256 requested, uint256 available);

    /// @notice Thrown when querying a snapshot that doesn't exist
    /// @param snapshotId The invalid snapshot ID
    error InvalidSnapshotId(uint256 snapshotId);

    /// @notice Thrown when setting flash fee receiver to an invalid address
    error InvalidFeeReceiver();

    /// @notice Thrown when a flash loan amount is zero
    error ZeroFlashLoanAmount();

    // ============ Constructor ============

    /**
     * @notice Initializes the NexusToken contract
     * @dev Sets up roles and grants them to the deployer:
     *      - DEFAULT_ADMIN_ROLE: Can manage all other roles
     *      - ADMIN_ROLE: Can configure contract parameters
     *      - MINTER_ROLE: Can mint new tokens
     *      - PAUSER_ROLE: Can pause/unpause the contract
     * @param initialAdmin The address that will receive all initial roles
     */
    constructor(
        address initialAdmin
    ) ERC20("Nexus Token", "NEXUS") ERC20Permit("Nexus Token") {
        // Grant roles to initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);

        // Set ADMIN_ROLE as the admin for MINTER_ROLE and PAUSER_ROLE
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
    }

    // ============ External Functions ============

    /**
     * @notice Mints new tokens to the specified address
     * @dev Requirements:
     *      - Caller must have MINTER_ROLE
     *      - Contract must not be paused
     *      - Total supply after minting must not exceed MAX_SUPPLY
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     *
     * Emits a {TokensMinted} event.
     * Emits a {Transfer} event (from ERC20).
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 newSupply = totalSupply() + amount;
        if (newSupply > MAX_SUPPLY) {
            revert ExceedsMaxSupply(amount, MAX_SUPPLY - totalSupply());
        }
        _mint(to, amount);
        emit TokensMinted(to, amount, _msgSender());
    }

    /**
     * @notice Burns tokens from the caller's balance
     * @dev Requirements:
     *      - Contract must not be paused
     *      - Caller must have sufficient balance
     * @param amount The amount of tokens to burn
     *
     * Emits a {TokensBurned} event.
     * Emits a {Transfer} event to zero address (from ERC20).
     */
    function burn(uint256 amount) external whenNotPaused {
        _burn(_msgSender(), amount);
        emit TokensBurned(_msgSender(), amount);
    }

    /**
     * @notice Burns tokens from a specified account using allowance
     * @dev Requirements:
     *      - Contract must not be paused
     *      - Caller must have sufficient allowance from `account`
     *      - `account` must have sufficient balance
     * @param account The account whose tokens will be burned
     * @param amount The amount of tokens to burn
     *
     * Emits a {TokensBurned} event.
     * Emits a {Transfer} event to zero address (from ERC20).
     */
    function burnFrom(address account, uint256 amount) external whenNotPaused {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
        emit TokensBurned(account, amount);
    }

    /**
     * @notice Creates a new snapshot at the current block
     * @dev Requirements:
     *      - Caller must have ADMIN_ROLE
     *
     * The snapshot ID is incremented atomically and the current block number
     * is recorded. Historical balances can then be queried using balanceOfAt().
     *
     * @return snapshotId The ID of the newly created snapshot
     *
     * Emits a {Snapshot} event.
     */
    function snapshot() external onlyRole(ADMIN_ROLE) returns (uint256 snapshotId) {
        // SAFETY: _currentSnapshotId is bounded by practical limits of block production rate
        // and contract lifetime. Overflow is not possible in reasonable use.
        unchecked {
            _currentSnapshotId++;
        }
        snapshotId = _currentSnapshotId;
        _snapshotBlocks[snapshotId] = block.number;

        emit Snapshot(snapshotId, block.number);
    }

    /**
     * @notice Pauses all token transfers
     * @dev Requirements:
     *      - Caller must have PAUSER_ROLE
     *      - Contract must not already be paused
     *
     * While paused, transfers, minting, and burning are disabled.
     *
     * Emits a {Paused} event.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses token transfers
     * @dev Requirements:
     *      - Caller must have PAUSER_ROLE
     *      - Contract must be paused
     *
     * Emits an {Unpaused} event.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Sets the address that receives flash loan fees
     * @dev Requirements:
     *      - Caller must have ADMIN_ROLE
     *      - Can be set to address(0) to burn fees instead
     * @param newReceiver The new fee receiver address (or zero to burn fees)
     *
     * Emits a {FlashFeeReceiverUpdated} event.
     */
    function setFlashFeeReceiver(address newReceiver) external onlyRole(ADMIN_ROLE) {
        address previousReceiver = flashFeeReceiver;
        flashFeeReceiver = newReceiver;
        emit FlashFeeReceiverUpdated(previousReceiver, newReceiver);
    }

    // ============ View Functions ============

    /**
     * @notice Returns the balance of an account at a specific snapshot
     * @dev Uses the Checkpoints library for efficient historical lookups
     * @param account The account to query
     * @param snapshotId The snapshot ID to query
     * @return The balance at the specified snapshot
     *
     * Requirements:
     *      - snapshotId must be valid (1 <= snapshotId <= currentSnapshotId)
     */
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256) {
        if (snapshotId == 0 || snapshotId > _currentSnapshotId) {
            revert InvalidSnapshotId(snapshotId);
        }

        uint256 blockNumber = _snapshotBlocks[snapshotId];

        // If the snapshot block is the current block or hasn't been mined yet,
        // return the current balance
        if (blockNumber >= block.number) {
            return balanceOf(account);
        }

        // Look up the balance at the snapshot block using checkpoints
        return _accountBalanceCheckpoints[account].upperLookupRecent(blockNumber.toUint48());
    }

    /**
     * @notice Returns the total supply at a specific snapshot
     * @param snapshotId The snapshot ID to query
     * @return The total supply at the specified snapshot
     *
     * Requirements:
     *      - snapshotId must be valid (1 <= snapshotId <= currentSnapshotId)
     */
    function totalSupplyAt(uint256 snapshotId) external view returns (uint256) {
        if (snapshotId == 0 || snapshotId > _currentSnapshotId) {
            revert InvalidSnapshotId(snapshotId);
        }

        uint256 blockNumber = _snapshotBlocks[snapshotId];

        // If the snapshot block is the current block, return current total supply
        if (blockNumber >= block.number) {
            return totalSupply();
        }

        // Look up the total supply at the snapshot block
        return _totalSupplyCheckpoints.upperLookupRecent(blockNumber.toUint48());
    }

    /**
     * @notice Returns the current snapshot ID
     * @return The current snapshot ID (0 if no snapshots have been taken)
     */
    function getCurrentSnapshotId() external view returns (uint256) {
        return _currentSnapshotId;
    }

    /**
     * @notice Returns the block number for a given snapshot ID
     * @param snapshotId The snapshot ID to query
     * @return The block number at which the snapshot was taken
     */
    function getSnapshotBlock(uint256 snapshotId) external view returns (uint256) {
        if (snapshotId == 0 || snapshotId > _currentSnapshotId) {
            revert InvalidSnapshotId(snapshotId);
        }
        return _snapshotBlocks[snapshotId];
    }

    // ============ Flash Loan Functions ============

    /**
     * @notice Returns the maximum flash loan amount for a token
     * @dev Overrides ERC20FlashMint to respect the MAX_SUPPLY cap
     *      SEC-007: Uses explicit calculation to ensure we don't exceed cap
     * @param token The token address (must be this contract)
     * @return The maximum amount that can be flash loaned
     */
    function maxFlashLoan(address token) public view override returns (uint256) {
        if (token != address(this)) {
            return 0;
        }
        // Maximum flash loan is limited by remaining supply cap
        // This ensures minted flash loan tokens don't exceed MAX_SUPPLY
        uint256 currentSupply = totalSupply();
        if (currentSupply >= MAX_SUPPLY) {
            return 0;
        }
        // SAFETY: We already checked currentSupply < MAX_SUPPLY above
        unchecked {
            return MAX_SUPPLY - currentSupply;
        }
    }

    /**
     * @notice Calculates the flash loan fee
     * @dev SEC-007: Rounds UP to favor the protocol when calculating fees
     *      Fee = (amount * FLASH_LOAN_FEE_BPS + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR
     * @param token The token address (must be this contract)
     * @param amount The loan amount
     * @return fee The fee to be charged (rounds up)
     */
    function _flashFee(address token, uint256 amount) internal view override returns (uint256 fee) {
        // Silence unused variable warning
        token;

        // SEC-007: Round UP for fee calculation to favor protocol
        // fee = ceil(amount * FLASH_LOAN_FEE_BPS / BPS_DENOMINATOR)
        // Using: ceil(a/b) = (a + b - 1) / b
        //
        // SAFETY: amount * FLASH_LOAN_FEE_BPS cannot overflow because:
        // - amount <= MAX_SUPPLY = 1e27
        // - FLASH_LOAN_FEE_BPS = 10
        // - 1e27 * 10 = 1e28 < type(uint256).max
        unchecked {
            fee = (amount * FLASH_LOAN_FEE_BPS + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        }
    }

    /**
     * @notice Returns the flash loan fee receiver address
     * @return The address that receives flash loan fees
     */
    function _flashFeeReceiver() internal view override returns (address) {
        return flashFeeReceiver;
    }

    /**
     * @notice Executes a flash loan
     * @dev Overrides ERC20FlashMint to add pause check and custom events
     * @param receiver The receiver of the flash loan
     * @param token The token to loan (must be this contract)
     * @param amount The amount to loan
     * @param data Arbitrary data passed to the receiver
     * @return true if the flash loan succeeded
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) public override whenNotPaused returns (bool) {
        if (amount == 0) {
            revert ZeroFlashLoanAmount();
        }

        uint256 fee = flashFee(token, amount);

        // Execute the parent flash loan logic
        bool success = super.flashLoan(receiver, token, amount, data);

        // Emit custom event for tracking
        emit FlashLoanExecuted(address(receiver), token, amount, fee);

        return success;
    }

    // ============ Internal Functions ============

    /**
     * @notice Hook called on every token transfer
     * @dev Overrides both ERC20 and ERC20Votes to:
     *      - Enforce pause status
     *      - Update voting checkpoints
     *      - Update balance checkpoints for snapshots
     * @param from The sender address (zero for mints)
     * @param to The receiver address (zero for burns)
     * @param value The transfer amount
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Votes) whenNotPaused {
        // Call parent implementation (handles voting checkpoints and supply cap)
        super._update(from, to, value);

        // Update balance checkpoints for snapshot functionality
        _updateBalanceCheckpoints(from, to, value);
    }

    /**
     * @notice Updates the balance checkpoints for snapshot queries
     * @dev Called after every transfer to maintain historical balance data
     * @param from The sender address (zero for mints)
     * @param to The receiver address (zero for burns)
     * @param value The transfer amount
     */
    function _updateBalanceCheckpoints(address from, address to, uint256 value) private {
        uint48 currentBlock = block.number.toUint48();

        if (from == address(0)) {
            // Mint: update total supply checkpoint
            uint256 newTotalSupply = totalSupply();
            _totalSupplyCheckpoints.push(currentBlock, newTotalSupply.toUint208());
        } else {
            // Transfer from: update sender's balance checkpoint
            uint256 fromBalance = balanceOf(from);
            _accountBalanceCheckpoints[from].push(currentBlock, fromBalance.toUint208());
        }

        if (to == address(0)) {
            // Burn: update total supply checkpoint
            uint256 newTotalSupply = totalSupply();
            _totalSupplyCheckpoints.push(currentBlock, newTotalSupply.toUint208());
        } else if (from != address(0)) {
            // Transfer to (not mint): update receiver's balance checkpoint
            uint256 toBalance = balanceOf(to);
            _accountBalanceCheckpoints[to].push(currentBlock, toBalance.toUint208());
        }

        // For mints, we need to update the recipient's checkpoint separately
        if (from == address(0) && to != address(0)) {
            uint256 toBalance = balanceOf(to);
            _accountBalanceCheckpoints[to].push(currentBlock, toBalance.toUint208());
        }
    }

    /**
     * @notice Returns the nonce for an address
     * @dev Required override due to multiple inheritance from ERC20Permit and Nonces
     * @param owner The address to query
     * @return The current nonce
     */
    function nonces(
        address owner
    ) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    // ============ ERC165 Support ============

    /**
     * @notice Checks if the contract supports an interface
     * @dev Overrides AccessControl to add ERC165 interface support
     * @param interfaceId The interface identifier to check
     * @return true if the interface is supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
