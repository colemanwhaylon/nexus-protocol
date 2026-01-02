// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NexusForwarder
 * @author Nexus Protocol Team
 * @notice ERC-2771 trusted forwarder for gasless meta-transactions
 * @dev Enables users to sign transactions off-chain and have relayers submit them on-chain.
 *      This eliminates the need for users to hold ETH for gas fees.
 *
 * Features:
 *      - EIP-712 typed data signing for secure signature verification
 *      - Nonce management to prevent replay attacks
 *      - Deadline enforcement for request expiration
 *      - Gas limit specification by the signer
 *      - Relayer role for authorized submission
 *      - Batch execution for multiple requests
 *      - Emergency pause capability
 *
 * Security Considerations:
 *      - Only RELAYER_ROLE can execute forwarded requests
 *      - Nonces prevent replay attacks
 *      - Deadlines prevent stale request execution
 *      - Gas limits prevent griefing attacks
 *      - Reentrancy guard on execute functions
 */
contract NexusForwarder is EIP712, Nonces, AccessControl, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    // ============ Constants ============

    /// @notice Role for administrative operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for relayers who can submit meta-transactions
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @notice EIP-712 typehash for ForwardRequest
    bytes32 private constant FORWARD_REQUEST_TYPEHASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
    );

    /// @notice Minimum gas buffer for post-call operations
    uint256 private constant GAS_BUFFER = 40_000;

    // ============ Structs ============

    /// @notice Structure for a forward request
    struct ForwardRequest {
        address from;      // Original signer
        address to;        // Target contract
        uint256 value;     // ETH value to send
        uint256 gas;       // Gas limit for the call
        uint256 nonce;     // Unique nonce for replay protection
        uint48 deadline;   // Request expiration timestamp
        bytes data;        // Calldata to execute
    }

    /// @notice Structure for batch execution results
    struct ExecutionResult {
        bool success;
        bytes returnData;
    }

    // ============ State Variables ============

    /// @notice Total number of successful executions
    uint256 public totalExecutions;

    /// @notice Total gas sponsored by relayers
    uint256 public totalGasSponsored;

    /// @notice Mapping of contracts that are allowed as targets
    mapping(address target => bool allowed) public allowedTargets;

    /// @notice Whether target whitelist is enforced
    bool public enforceTargetWhitelist;

    // ============ Events ============

    /// @notice Emitted when a request is executed
    event RequestExecuted(
        address indexed from,
        address indexed to,
        uint256 nonce,
        bool success,
        bytes returnData
    );

    /// @notice Emitted when a batch of requests is executed
    event BatchExecuted(
        uint256 indexed batchId,
        uint256 successCount,
        uint256 failureCount
    );

    /// @notice Emitted when a target is added/removed from whitelist
    event TargetWhitelistUpdated(address indexed target, bool allowed);

    /// @notice Emitted when whitelist enforcement is toggled
    event WhitelistEnforcementUpdated(bool enforced);

    /// @notice Emitted when relayer receives tip
    event RelayerTipped(address indexed relayer, uint256 amount);

    // ============ Errors ============

    /// @notice Thrown when signature is invalid
    error InvalidSignature();

    /// @notice Thrown when signer doesn't match from address
    error SignerMismatch(address signer, address from);

    /// @notice Thrown when request has expired
    error RequestExpired(uint48 deadline, uint256 currentTime);

    /// @notice Thrown when nonce is invalid
    error InvalidNonce(uint256 expected, uint256 provided);

    /// @notice Thrown when gas limit is too low
    error InsufficientGas(uint256 required, uint256 provided);

    /// @notice Thrown when target is not whitelisted
    error TargetNotAllowed(address target);

    /// @notice Thrown when call fails
    error CallFailed(bytes returnData);

    /// @notice Thrown when value transfer fails
    error ValueTransferFailed();

    /// @notice Thrown when batch is empty
    error EmptyBatch();

    /// @notice Thrown when arrays have different lengths
    error ArrayLengthMismatch();

    // ============ Constructor ============

    /**
     * @notice Initializes the forwarder
     * @param admin The initial admin address
     * @param relayer The initial relayer address
     */
    constructor(
        address admin,
        address relayer
    ) EIP712("NexusForwarder", "1") {
        require(admin != address(0), "Invalid admin");
        require(relayer != address(0), "Invalid relayer");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(RELAYER_ROLE, relayer);

        // Set ADMIN_ROLE as admin for RELAYER_ROLE
        _setRoleAdmin(RELAYER_ROLE, ADMIN_ROLE);
    }

    // ============ External Functions ============

    /**
     * @notice Execute a single forward request
     * @param request The forward request to execute
     * @param signature The EIP-712 signature from the signer
     * @return success Whether the call succeeded
     * @return returnData The return data from the call
     */
    function execute(
        ForwardRequest calldata request,
        bytes calldata signature
    )
        external
        payable
        onlyRole(RELAYER_ROLE)
        whenNotPaused
        nonReentrant
        returns (bool success, bytes memory returnData)
    {
        // Verify the request
        _verifyRequest(request, signature);

        // Execute the call
        (success, returnData) = _executeCall(request);

        // Update stats
        unchecked {
            ++totalExecutions;
        }

        emit RequestExecuted(request.from, request.to, request.nonce, success, returnData);
    }

    /**
     * @notice Execute multiple forward requests in a batch
     * @param requests Array of forward requests
     * @param signatures Array of corresponding signatures
     * @return results Array of execution results
     */
    function executeBatch(
        ForwardRequest[] calldata requests,
        bytes[] calldata signatures
    )
        external
        payable
        onlyRole(RELAYER_ROLE)
        whenNotPaused
        nonReentrant
        returns (ExecutionResult[] memory results)
    {
        uint256 length = requests.length;
        if (length == 0) revert EmptyBatch();
        if (length != signatures.length) revert ArrayLengthMismatch();

        results = new ExecutionResult[](length);
        uint256 successCount;
        uint256 failureCount;

        for (uint256 i = 0; i < length;) {
            // Verify each request
            if (_tryVerifyRequest(requests[i], signatures[i])) {
                // Execute the call
                (bool success, bytes memory returnData) = _executeCall(requests[i]);
                results[i] = ExecutionResult(success, returnData);

                if (success) {
                    unchecked { ++successCount; }
                } else {
                    unchecked { ++failureCount; }
                }

                emit RequestExecuted(
                    requests[i].from,
                    requests[i].to,
                    requests[i].nonce,
                    success,
                    returnData
                );
            } else {
                results[i] = ExecutionResult(false, "");
                unchecked { ++failureCount; }
            }

            unchecked { ++i; }
        }

        unchecked {
            totalExecutions += successCount;
        }

        emit BatchExecuted(block.number, successCount, failureCount);
    }

    /**
     * @notice Verify a forward request without executing it
     * @param request The forward request to verify
     * @param signature The signature to verify
     * @return valid Whether the request is valid
     */
    function verify(
        ForwardRequest calldata request,
        bytes calldata signature
    ) external view returns (bool valid) {
        return _tryVerifyRequest(request, signature);
    }

    // ============ Admin Functions ============

    /**
     * @notice Add or remove a target from the whitelist
     * @param target The target address
     * @param allowed Whether the target is allowed
     */
    function setTargetAllowed(address target, bool allowed) external onlyRole(ADMIN_ROLE) {
        allowedTargets[target] = allowed;
        emit TargetWhitelistUpdated(target, allowed);
    }

    /**
     * @notice Set multiple targets' whitelist status
     * @param targets Array of target addresses
     * @param allowed Whether the targets are allowed
     */
    function setTargetsAllowed(address[] calldata targets, bool allowed) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < targets.length;) {
            allowedTargets[targets[i]] = allowed;
            emit TargetWhitelistUpdated(targets[i], allowed);
            unchecked { ++i; }
        }
    }

    /**
     * @notice Toggle whitelist enforcement
     * @param enforced Whether to enforce the whitelist
     */
    function setEnforceWhitelist(bool enforced) external onlyRole(ADMIN_ROLE) {
        enforceTargetWhitelist = enforced;
        emit WhitelistEnforcementUpdated(enforced);
    }

    /**
     * @notice Pause the forwarder
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the forwarder
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Withdraw accumulated ETH tips
     * @param to The recipient address
     */
    function withdrawTips(address payable to) external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = to.call{value: balance}("");
            if (!success) revert ValueTransferFailed();
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get the current nonce for an address
     * @param owner The address to check
     * @return The current nonce
     */
    function getNonce(address owner) external view returns (uint256) {
        return nonces(owner);
    }

    /**
     * @notice Get the domain separator for EIP-712
     * @return The domain separator
     */
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Check if a target is allowed
     * @param target The target address to check
     * @return Whether the target is allowed
     */
    function isTargetAllowed(address target) external view returns (bool) {
        if (!enforceTargetWhitelist) return true;
        return allowedTargets[target];
    }

    /**
     * @notice Get the EIP-712 hash for a forward request
     * @param request The forward request
     * @return The typed data hash
     */
    function getRequestHash(ForwardRequest calldata request) external view returns (bytes32) {
        return _hashTypedDataV4(_hashRequest(request));
    }

    // ============ Internal Functions ============

    /**
     * @notice Hash a forward request according to EIP-712
     * @param request The request to hash
     * @return The struct hash
     */
    function _hashRequest(ForwardRequest calldata request) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FORWARD_REQUEST_TYPEHASH,
            request.from,
            request.to,
            request.value,
            request.gas,
            request.nonce,
            request.deadline,
            keccak256(request.data)
        ));
    }

    /**
     * @notice Verify a forward request
     * @param request The request to verify
     * @param signature The signature to verify
     */
    function _verifyRequest(
        ForwardRequest calldata request,
        bytes calldata signature
    ) internal {
        // Check deadline
        if (block.timestamp > request.deadline) {
            revert RequestExpired(request.deadline, block.timestamp);
        }

        // Check target whitelist
        if (enforceTargetWhitelist && !allowedTargets[request.to]) {
            revert TargetNotAllowed(request.to);
        }

        // Check gas
        if (gasleft() < request.gas + GAS_BUFFER) {
            revert InsufficientGas(request.gas + GAS_BUFFER, gasleft());
        }

        // Verify nonce and consume it
        uint256 currentNonce = nonces(request.from);
        if (request.nonce != currentNonce) {
            revert InvalidNonce(currentNonce, request.nonce);
        }
        _useNonce(request.from);

        // Verify signature
        bytes32 digest = _hashTypedDataV4(_hashRequest(request));
        address signer = ECDSA.recover(digest, signature);
        if (signer != request.from) {
            revert SignerMismatch(signer, request.from);
        }
    }

    /**
     * @notice Try to verify a request without reverting
     * @param request The request to verify
     * @param signature The signature to verify
     * @return valid Whether verification succeeded
     */
    function _tryVerifyRequest(
        ForwardRequest calldata request,
        bytes calldata signature
    ) internal view returns (bool valid) {
        // Check deadline
        if (block.timestamp > request.deadline) {
            return false;
        }

        // Check target whitelist
        if (enforceTargetWhitelist && !allowedTargets[request.to]) {
            return false;
        }

        // Check nonce
        if (request.nonce != nonces(request.from)) {
            return false;
        }

        // Verify signature
        bytes32 digest = _hashTypedDataV4(_hashRequest(request));
        address signer = ECDSA.recover(digest, signature);
        return signer == request.from;
    }

    /**
     * @notice Execute a call to the target
     * @param request The forward request
     * @return success Whether the call succeeded
     * @return returnData The return data from the call
     */
    function _executeCall(
        ForwardRequest calldata request
    ) internal returns (bool success, bytes memory returnData) {
        // Prepare calldata with ERC-2771 suffix (original sender appended)
        bytes memory callData = abi.encodePacked(request.data, request.from);

        // Execute the call
        (success, returnData) = request.to.call{
            gas: request.gas,
            value: request.value
        }(callData);

        // Track gas sponsored
        unchecked {
            totalGasSponsored += request.gas;
        }
    }

    // ============ Receive Function ============

    /**
     * @notice Receive ETH for tips
     */
    receive() external payable {
        emit RelayerTipped(msg.sender, msg.value);
    }
}
