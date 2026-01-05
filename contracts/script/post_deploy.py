#!/usr/bin/env python3
"""
Post-deployment script that reads Foundry broadcast JSON and
registers contract addresses in the database via API.

ALL CONFIGURATION COMES FROM THE DATABASE:
- Contract name mappings (Solidity→DB name)
- Deployer address (from network config)
- Network name (from network config)

The script does NOT contain any hardcoded contract names or addresses.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

try:
    import requests
except ImportError:
    print("ERROR: 'requests' package is required. Install with: pip install requests")
    sys.exit(1)


class DeploymentRegistrar:
    """Registers deployed contracts using DB-driven configuration."""

    def __init__(self, api_url: str, api_key: Optional[str] = None):
        self.api_url = api_url.rstrip('/')
        self.headers = {"Content-Type": "application/json"}
        if api_key:
            self.headers["X-API-Key"] = api_key
        self.config = None

    def fetch_config(self, chain_id: int) -> dict:
        """
        Fetch deployment configuration from API.
        Returns network config + contract mappings from database.
        """
        url = f"{self.api_url}/api/v1/contracts/config/{chain_id}"
        try:
            resp = requests.get(url, headers=self.headers, timeout=10)
        except requests.exceptions.ConnectionError:
            raise RuntimeError(f"Cannot connect to API at {self.api_url}. Is the backend running?")
        except requests.exceptions.Timeout:
            raise RuntimeError(f"API request timed out: {url}")

        if not resp.ok:
            raise RuntimeError(f"Failed to fetch config: {resp.status_code} - {resp.text}")

        data = resp.json()
        if not data.get("success"):
            raise RuntimeError(f"API error: {data.get('error')}")

        self.config = data["data"]
        return self.config

    def load_broadcast_json(self, chain_id: int, script_name: str = "DeployLocal.s.sol") -> dict:
        """Load the latest broadcast JSON from Foundry."""
        # Try to find broadcast file in expected locations
        script_dir = Path(__file__).parent
        possible_paths = [
            script_dir.parent / "broadcast" / script_name / str(chain_id) / "run-latest.json",
            script_dir / ".." / "broadcast" / script_name / str(chain_id) / "run-latest.json",
        ]

        broadcast_path = None
        for path in possible_paths:
            resolved = path.resolve()
            if resolved.exists():
                broadcast_path = resolved
                break

        if broadcast_path is None:
            searched = ", ".join(str(p.resolve()) for p in possible_paths)
            raise FileNotFoundError(
                f"Broadcast file not found. Searched:\n{searched}\n\n"
                f"Make sure you've run: forge script script/{script_name} --broadcast"
            )

        print(f"Loading broadcast from: {broadcast_path}")
        with open(broadcast_path) as f:
            return json.load(f)

    def extract_deployments(self, broadcast: dict) -> list[dict]:
        """
        Extract CREATE transactions from broadcast.
        Uses contract mappings FROM DATABASE - no hardcoded map.
        """
        if self.config is None:
            raise RuntimeError("Config not loaded. Call fetch_config() first.")

        # Build mapping from DB data (not hardcoded!)
        solidity_to_mapping = {
            m["solidity_name"]: m for m in self.config["mappings"]
        }

        deployments = []
        transactions = broadcast.get("transactions", [])

        for tx in transactions:
            if tx.get("transactionType") == "CREATE":
                solidity_name = tx.get("contractName")
                if solidity_name in solidity_to_mapping:
                    mapping = solidity_to_mapping[solidity_name]
                    deployments.append({
                        "solidity_name": solidity_name,
                        "db_name": mapping["db_name"],
                        "mapping_id": mapping["id"],
                        "address": tx.get("contractAddress"),
                        "tx_hash": tx.get("hash"),
                    })
                else:
                    print(f"  Skipping {solidity_name}: not in contract_mappings table")

        return deployments

    def register_contracts(self, chain_id: int, deployments: list[dict]) -> tuple[int, int]:
        """
        POST each contract to the API.
        Uses deployer address FROM DATABASE - not hardcoded.
        Returns (success_count, failure_count).
        """
        if self.config is None:
            raise RuntimeError("Config not loaded. Call fetch_config() first.")

        # Get deployer from network config (database-driven)
        default_deployer = self.config["network"].get("default_deployer")

        success_count = 0
        failure_count = 0

        for dep in deployments:
            payload = {
                "chain_id": chain_id,
                "contract_mapping_id": dep["mapping_id"],
                "address": dep["address"],
                "deployment_tx_hash": dep["tx_hash"],
            }
            # Only add deployed_by if we have a default deployer
            if default_deployer:
                payload["deployed_by"] = default_deployer

            try:
                resp = requests.post(
                    f"{self.api_url}/api/v1/contracts",
                    json=payload,
                    headers=self.headers,
                    timeout=10
                )
                if resp.ok:
                    print(f"  Registered {dep['db_name']}: {dep['address']}")
                    success_count += 1
                else:
                    print(f"  Failed {dep['db_name']}: {resp.status_code} - {resp.text}")
                    failure_count += 1
            except requests.exceptions.RequestException as e:
                print(f"  Failed {dep['db_name']}: {e}")
                failure_count += 1

        return success_count, failure_count


def main():
    parser = argparse.ArgumentParser(
        description="Register deployed contracts in database (DB-driven configuration)"
    )
    parser.add_argument(
        "--chain-id", type=int, default=31337,
        help="Chain ID (config fetched from database)"
    )
    parser.add_argument(
        "--api-url", default="http://localhost:8080",
        help="API URL"
    )
    parser.add_argument(
        "--api-key",
        help="API key (required for non-localhost networks)"
    )
    parser.add_argument(
        "--script", default="DeployLocal.s.sol",
        help="Deployment script name (for broadcast path)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be registered without actually registering"
    )
    args = parser.parse_args()

    print("=" * 60)
    print("Nexus Protocol - Post-Deployment Contract Registration")
    print("=" * 60)

    registrar = DeploymentRegistrar(args.api_url, args.api_key)

    # 1. Fetch config from database
    print(f"\n[1/4] Fetching config for chain {args.chain_id}...")
    try:
        config = registrar.fetch_config(args.chain_id)
    except RuntimeError as e:
        print(f"ERROR: {e}")
        sys.exit(1)

    network_name = config["network"]["network_name"]
    display_name = config["network"]["display_name"]
    deployer = config["network"].get("default_deployer", "not configured")
    mapping_count = len(config["mappings"])

    print(f"   Network: {display_name} ({network_name})")
    print(f"   Default deployer: {deployer}")
    print(f"   Contract mappings: {mapping_count}")

    # 2. Require API key for non-localhost (check from DB config, not hardcoded)
    if network_name != "localhost" and not args.api_key:
        print("\nERROR: API key required for non-localhost deployments")
        print("       Use --api-key flag to provide authentication")
        sys.exit(1)

    # 3. Load broadcast and extract deployments
    print(f"\n[2/4] Loading broadcast from {args.script}...")
    try:
        broadcast = registrar.load_broadcast_json(args.chain_id, args.script)
    except FileNotFoundError as e:
        print(f"ERROR: {e}")
        sys.exit(1)

    print(f"\n[3/4] Extracting deployments...")
    deployments = registrar.extract_deployments(broadcast)
    print(f"   Found {len(deployments)} contracts to register:")
    for dep in deployments:
        print(f"     - {dep['db_name']} ({dep['solidity_name']}): {dep['address']}")

    # 4. Register contracts
    if not deployments:
        print("\n[4/4] No contracts to register.")
        return

    if args.dry_run:
        print("\n[4/4] DRY RUN - Skipping registration")
        print("     Would register:")
        for dep in deployments:
            print(f"       {dep['db_name']}: {dep['address']}")
        return

    print(f"\n[4/4] Registering contracts...")
    success, failures = registrar.register_contracts(args.chain_id, deployments)

    # Summary
    print("\n" + "=" * 60)
    if failures == 0:
        print(f"SUCCESS: Registered {success} contracts")
    else:
        print(f"PARTIAL: Registered {success} contracts, {failures} failed")
        sys.exit(1)

    print("\nContracts are now accessible via:")
    print(f"  GET {args.api_url}/api/v1/contracts/{args.chain_id}")
    print("=" * 60)


if __name__ == "__main__":
    main()
