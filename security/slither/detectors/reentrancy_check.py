"""
Nexus Protocol - Custom Slither Detector
Checks for reentrancy vulnerabilities specific to DeFi patterns.
"""

from slither.detectors.abstract_detector import AbstractDetector, DetectorClassification
from slither.core.declarations import Function
from slither.slithir.operations import HighLevelCall, LowLevelCall
from slither.analyses.data_dependency.data_dependency import is_dependent


class NexusReentrancyDetector(AbstractDetector):
    """
    Custom detector for reentrancy in Nexus Protocol contracts.
    Focuses on staking, bridge, and token operations.
    """

    ARGUMENT = "nexus-reentrancy"
    HELP = "Detects potential reentrancy in Nexus Protocol patterns"
    IMPACT = DetectorClassification.HIGH
    CONFIDENCE = DetectorClassification.MEDIUM

    WIKI = "https://github.com/nexus-protocol/security/wiki/reentrancy"
    WIKI_TITLE = "Nexus Reentrancy Detector"
    WIKI_DESCRIPTION = "Detects reentrancy patterns in staking, bridge, and token operations"
    WIKI_EXPLOIT_SCENARIO = """
    A malicious contract could exploit reentrancy in:
    1. Staking: Complete unbonding before state update
    2. Bridge: Unlock tokens multiple times
    3. Rewards: Claim rewards multiple times
    """
    WIKI_RECOMMENDATION = """
    1. Use nonReentrant modifier from OpenZeppelin
    2. Follow checks-effects-interactions pattern
    3. Update state before external calls
    """

    # Functions that are critical for reentrancy checks
    CRITICAL_FUNCTIONS = [
        "stake",
        "unstake",
        "withdraw",
        "claim",
        "claimRewards",
        "completeUnbonding",
        "unlockTokens",
        "executeLargeTransfer",
    ]

    def _detect(self):
        results = []

        for contract in self.compilation_unit.contracts_derived:
            # Skip interfaces and abstract contracts
            if contract.is_interface or contract.is_abstract:
                continue

            for function in contract.functions_and_modifiers:
                if function.name in self.CRITICAL_FUNCTIONS:
                    issues = self._check_function(function)
                    if issues:
                        for issue in issues:
                            results.append(self.generate_result(issue))

        return results

    def _check_function(self, function: Function):
        """Check a function for reentrancy vulnerabilities."""
        issues = []

        # Check if function has nonReentrant modifier
        has_reentrancy_guard = any(
            "nonReentrant" in str(mod) or "ReentrancyGuard" in str(mod)
            for mod in function.modifiers
        )

        if not has_reentrancy_guard:
            # Check for external calls followed by state changes
            external_calls = []
            state_changes = []

            for node in function.nodes:
                for ir in node.irs:
                    if isinstance(ir, (HighLevelCall, LowLevelCall)):
                        external_calls.append((node, ir))

                if node.state_variables_written:
                    state_changes.append((node, node.state_variables_written))

            # Check for external call before state change
            for call_node, call_ir in external_calls:
                for state_node, state_vars in state_changes:
                    if call_node.node_id < state_node.node_id:
                        issues.append([
                            f"Potential reentrancy in {function.canonical_name}\n",
                            f"External call at node {call_node}\n",
                            f"State change after external call: {state_vars}\n",
                        ])

        return issues


class NexusBridgeSecurityDetector(AbstractDetector):
    """
    Custom detector for bridge-specific security issues.
    """

    ARGUMENT = "nexus-bridge"
    HELP = "Detects potential issues in bridge operations"
    IMPACT = DetectorClassification.HIGH
    CONFIDENCE = DetectorClassification.MEDIUM

    WIKI = "https://github.com/nexus-protocol/security/wiki/bridge"
    WIKI_TITLE = "Nexus Bridge Security Detector"
    WIKI_DESCRIPTION = "Detects security issues in cross-chain bridge operations"
    WIKI_EXPLOIT_SCENARIO = """
    Issues detected:
    1. Missing signature verification
    2. Replay attack vulnerabilities
    3. Rate limit bypass
    """
    WIKI_RECOMMENDATION = """
    1. Always verify signatures from multiple relayers
    2. Use nonces to prevent replay attacks
    3. Implement proper rate limiting
    """

    def _detect(self):
        results = []

        for contract in self.compilation_unit.contracts_derived:
            if "Bridge" in contract.name:
                issues = self._check_bridge_contract(contract)
                if issues:
                    for issue in issues:
                        results.append(self.generate_result(issue))

        return results

    def _check_bridge_contract(self, contract):
        """Check bridge contract for security issues."""
        issues = []

        # Check for processedTransfers mapping usage
        has_replay_protection = False
        for variable in contract.state_variables:
            if "processed" in variable.name.lower():
                has_replay_protection = True
                break

        if not has_replay_protection:
            issues.append([
                f"Bridge contract {contract.name} may lack replay protection\n",
                "Consider using a mapping to track processed transfers\n",
            ])

        # Check for rate limiting
        has_rate_limit = False
        for variable in contract.state_variables:
            if "limit" in variable.name.lower() or "daily" in variable.name.lower():
                has_rate_limit = True
                break

        if not has_rate_limit:
            issues.append([
                f"Bridge contract {contract.name} may lack rate limiting\n",
                "Consider implementing daily transfer limits\n",
            ])

        return issues


class NexusAccessControlDetector(AbstractDetector):
    """
    Custom detector for access control issues.
    """

    ARGUMENT = "nexus-access-control"
    HELP = "Detects access control issues in Nexus contracts"
    IMPACT = DetectorClassification.HIGH
    CONFIDENCE = DetectorClassification.HIGH

    WIKI = "https://github.com/nexus-protocol/security/wiki/access-control"
    WIKI_TITLE = "Nexus Access Control Detector"
    WIKI_DESCRIPTION = "Detects access control issues in privileged functions"
    WIKI_EXPLOIT_SCENARIO = """
    Issues detected:
    1. Missing access control on sensitive functions
    2. Incorrect role assignments
    3. Missing pause functionality
    """
    WIKI_RECOMMENDATION = """
    1. Use OpenZeppelin AccessControl
    2. Implement role-based permissions
    3. Add pause functionality for emergencies
    """

    # Functions that should be protected
    PROTECTED_FUNCTIONS = [
        "mint",
        "burn",
        "pause",
        "unpause",
        "upgrade",
        "setAdmin",
        "grantRole",
        "revokeRole",
        "slash",
        "emergencyWithdraw",
        "setTreasury",
    ]

    def _detect(self):
        results = []

        for contract in self.compilation_unit.contracts_derived:
            if contract.is_interface or contract.is_abstract:
                continue

            for function in contract.functions:
                if function.name in self.PROTECTED_FUNCTIONS:
                    if not self._has_access_control(function):
                        results.append(self.generate_result([
                            f"Function {function.canonical_name} lacks access control\n",
                            "Consider adding onlyRole or onlyOwner modifier\n",
                        ]))

        return results

    def _has_access_control(self, function: Function):
        """Check if function has access control modifiers."""
        access_control_keywords = [
            "onlyOwner",
            "onlyRole",
            "onlyAdmin",
            "requiresAuth",
            "onlyAuthorized",
        ]

        for modifier in function.modifiers:
            if any(keyword in str(modifier) for keyword in access_control_keywords):
                return True

        # Check for require statements with msg.sender
        for node in function.nodes:
            if "require" in str(node) and "msg.sender" in str(node):
                return True

        return False
