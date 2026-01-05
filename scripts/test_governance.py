#!/usr/bin/env python3
"""
Nexus Protocol - Governance End-to-End Test

Tests the complete governance lifecycle:
1. Create proposal
2. Advance to Active voting period
3. Cast vote
4. Advance to Succeeded state
5. Queue in Timelock
6. Advance past timelock delay
7. Execute proposal

Handles Anvil block mining carefully to avoid timeouts.
"""

import subprocess
import json
import time
import sys
from typing import Tuple, Optional

# Configuration
RPC_URL = "http://localhost:8545"
API_URL = "http://localhost:8080"
CAST = "/home/whaylon/.foundry/bin/cast"

# Anvil test accounts
ACCOUNT0 = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ACCOUNT0_PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ACCOUNT1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
ACCOUNT1_PK = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

# State enum
STATES = {
    0: "Pending",
    1: "Active",
    2: "Canceled",
    3: "Defeated",
    4: "Succeeded",
    5: "Queued",
    6: "Expired",
    7: "Executed"
}


def run_cast(args: list, timeout: int = 30) -> Tuple[bool, str]:
    """Run a cast command and return success status and output."""
    try:
        result = subprocess.run(
            [CAST] + args,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        output = result.stdout.strip()
        if result.returncode != 0:
            return False, result.stderr.strip()
        return True, output
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except Exception as e:
        return False, str(e)


def get_block_number() -> int:
    """Get current block number."""
    success, output = run_cast(["block-number", "--rpc-url", RPC_URL])
    if success:
        return int(output)
    raise Exception(f"Failed to get block number: {output}")


def mine_blocks(count: int, batch_size: int = 100, delay: float = 0.1) -> bool:
    """Mine blocks in small batches to avoid Anvil timeouts."""
    mined = 0
    while mined < count:
        batch = min(batch_size, count - mined)
        hex_batch = hex(batch)
        success, output = run_cast(["rpc", "anvil_mine", hex_batch, "--rpc-url", RPC_URL], timeout=10)
        if not success:
            print(f"  Warning: mine failed, retrying... ({output})")
            time.sleep(1)
            continue
        mined += batch
        if mined % 1000 == 0 or mined >= count:
            current = get_block_number()
            print(f"  Mined {mined}/{count} blocks (current: {current})")
        time.sleep(delay)
    return True


def increase_time(seconds: int) -> bool:
    """Increase EVM time by specified seconds."""
    hex_seconds = hex(seconds)
    success, output = run_cast(["rpc", "anvil_increaseTime", hex_seconds, "--rpc-url", RPC_URL])
    if not success:
        print(f"Failed to increase time: {output}")
        return False
    # Mine one block to apply the time change
    mine_blocks(1)
    return True


def call_contract(address: str, sig: str, args: list = None) -> str:
    """Call a contract function (read-only)."""
    cmd = ["call", address, sig]
    if args:
        cmd.extend(args)
    cmd.extend(["--rpc-url", RPC_URL])
    success, output = run_cast(cmd)
    if not success:
        raise Exception(f"Call failed: {output}")
    # Strip scientific notation if present
    return output.split()[0] if ' ' in output else output


def send_tx(address: str, sig: str, args: list, private_key: str, value: str = None) -> str:
    """Send a transaction to a contract."""
    cmd = ["send", address, sig] + args
    if value:
        cmd.extend(["--value", value])
    cmd.extend(["--private-key", private_key, "--rpc-url", RPC_URL])
    success, output = run_cast(cmd, timeout=60)
    if not success:
        raise Exception(f"Transaction failed: {output}")
    return output


def get_contracts() -> dict:
    """Fetch contract addresses from API."""
    import urllib.request
    with urllib.request.urlopen(f"{API_URL}/api/v1/contracts/31337") as response:
        data = json.loads(response.read().decode())
        return {c["db_name"]: c["address"] for c in data["data"]["contracts"]}


def get_proposal_state(governor: str, proposal_id: str) -> int:
    """Get proposal state as integer."""
    result = call_contract(governor, "state(uint256)(uint8)", [proposal_id])
    return int(result)


def print_status(governor: str, proposal_id: str):
    """Print current proposal status."""
    state = get_proposal_state(governor, proposal_id)
    block = get_block_number()
    print(f"  Block: {block}, State: {state} ({STATES.get(state, 'Unknown')})")


def test_governance_direct_voting():
    """Test 1: Create proposal and vote with direct voting power."""
    print("\n" + "=" * 60)
    print("TEST 1: DIRECT VOTING GOVERNANCE")
    print("=" * 60)

    # Get contracts
    print("\n[1/7] Getting contract addresses...")
    contracts = get_contracts()
    token = contracts["nexusToken"]
    governor = contracts["nexusGovernor"]
    timelock = contracts["nexusTimelock"]
    print(f"  Token: {token}")
    print(f"  Governor: {governor}")
    print(f"  Timelock: {timelock}")

    # Check voting power
    votes = call_contract(token, "getVotes(address)(uint256)", [ACCOUNT0])
    print(f"  Account0 voting power: {int(votes) / 1e18:.0f} NXS")

    # Get governor parameters
    voting_delay = int(call_contract(governor, "votingDelay()(uint256)"))
    voting_period = int(call_contract(governor, "votingPeriod()(uint256)"))
    print(f"  Voting delay: {voting_delay} blocks")
    print(f"  Voting period: {voting_period} blocks")

    # Create proposal
    print("\n[2/7] Creating proposal...")
    description = f"Test Proposal Direct: Update quorum - {int(time.time())}"
    calldata = subprocess.run(
        [CAST, "calldata", "updateQuorumNumerator(uint256)", "4"],
        capture_output=True, text=True
    ).stdout.strip()

    tx_output = send_tx(
        governor,
        "propose(address[],uint256[],bytes[],string)",
        [f"[{governor}]", "[0]", f"[{calldata}]", description],
        ACCOUNT0_PK
    )

    # Extract proposal ID from logs
    # The proposal ID is in the first log topic after the event signature
    import re
    proposal_id_match = re.search(r'0x[a-fA-F0-9]{64}(?=.*data)', tx_output)
    if not proposal_id_match:
        # Try to compute it
        proposal_id = call_contract(
            governor,
            "hashProposal(address[],uint256[],bytes[],bytes32)(uint256)",
            [f"[{governor}]", "[0]", f"[{calldata}]",
             subprocess.run([CAST, "keccak", description], capture_output=True, text=True).stdout.strip()]
        )
    else:
        proposal_id = proposal_id_match.group()

    # Get proposal ID from the proposalSnapshot since we know the proposal was just created
    snapshot = call_contract(governor, "proposalSnapshot(uint256)(uint256)",
                            [str(int(call_contract(governor, "proposalCount()(uint256)") if "proposalCount" in dir() else "0"))])

    # Let's get it directly from the event log parsing
    for line in tx_output.split('\n'):
        if 'data' in line and '0x' in line:
            # Parse the log data to get proposal ID
            pass

    # Simpler approach - calculate the proposal ID
    desc_hash = subprocess.run([CAST, "keccak", description], capture_output=True, text=True).stdout.strip()
    proposal_id = subprocess.run(
        [CAST, "call", governor, "hashProposal(address[],uint256[],bytes[],bytes32)(uint256)",
         f"[{governor}]", "[0]", f"[{calldata}]", desc_hash, "--rpc-url", RPC_URL],
        capture_output=True, text=True
    ).stdout.strip().split()[0]

    print(f"  Proposal ID: {proposal_id}")
    print_status(governor, proposal_id)

    # Advance to voting period
    print("\n[3/7] Advancing to Active voting period...")
    snapshot_block = int(call_contract(governor, "proposalSnapshot(uint256)(uint256)", [proposal_id]))
    current_block = get_block_number()
    blocks_needed = snapshot_block - current_block + 1
    print(f"  Need to mine {blocks_needed} blocks to reach snapshot block {snapshot_block}")
    mine_blocks(blocks_needed)
    print_status(governor, proposal_id)

    # Cast vote
    print("\n[4/7] Casting vote FOR...")
    send_tx(governor, "castVote(uint256,uint8)", [proposal_id, "1"], ACCOUNT0_PK)

    # Check votes
    votes_result = call_contract(governor, "proposalVotes(uint256)(uint256,uint256,uint256)", [proposal_id])
    print(f"  Votes - Against: 0, For: {int(votes_result.split()[0]) / 1e18 if len(votes_result.split()) > 0 else 'N/A'}, Abstain: 0")
    print_status(governor, proposal_id)

    # Advance past voting period
    print("\n[5/7] Advancing past voting deadline...")
    deadline = int(call_contract(governor, "proposalDeadline(uint256)(uint256)", [proposal_id]))
    current_block = get_block_number()
    blocks_needed = deadline - current_block + 1
    print(f"  Need to mine {blocks_needed} blocks to reach deadline {deadline}")
    mine_blocks(blocks_needed)
    print_status(governor, proposal_id)

    state = get_proposal_state(governor, proposal_id)
    if state != 4:
        print(f"  ERROR: Expected Succeeded (4), got {STATES.get(state, state)}")
        return False

    # Queue proposal
    print("\n[6/7] Queueing proposal in Timelock...")
    send_tx(
        governor,
        "queue(address[],uint256[],bytes[],bytes32)",
        [f"[{governor}]", "[0]", f"[{calldata}]", desc_hash],
        ACCOUNT0_PK
    )
    print_status(governor, proposal_id)

    # Get eta and advance time
    eta = int(call_contract(governor, "proposalEta(uint256)(uint256)", [proposal_id]))
    print(f"  Proposal ETA: {eta}")

    # Get current timestamp
    current_block_data = subprocess.run(
        [CAST, "block", "--rpc-url", RPC_URL, "-j"],
        capture_output=True, text=True
    )
    current_time = int(json.loads(current_block_data.stdout)["timestamp"], 16)
    time_to_wait = eta - current_time + 1

    print(f"  Current time: {current_time}, need to wait {time_to_wait} seconds")

    if time_to_wait > 0:
        print(f"  Advancing time by {time_to_wait} seconds...")
        increase_time(time_to_wait)

    print_status(governor, proposal_id)

    # Execute proposal
    print("\n[7/7] Executing proposal...")
    send_tx(
        governor,
        "execute(address[],uint256[],bytes[],bytes32)",
        [f"[{governor}]", "[0]", f"[{calldata}]", desc_hash],
        ACCOUNT0_PK
    )
    print_status(governor, proposal_id)

    state = get_proposal_state(governor, proposal_id)
    if state == 7:
        print("\n" + "=" * 60)
        print("TEST 1 PASSED: Proposal executed successfully!")
        print("=" * 60)
        return True
    else:
        print(f"\n  ERROR: Expected Executed (7), got {STATES.get(state, state)}")
        return False


def test_governance_with_delegation():
    """Test 2: Create proposal using delegated voting power."""
    print("\n" + "=" * 60)
    print("TEST 2: DELEGATED VOTING GOVERNANCE")
    print("=" * 60)

    # Get contracts
    print("\n[1/9] Getting contract addresses...")
    contracts = get_contracts()
    token = contracts["nexusToken"]
    governor = contracts["nexusGovernor"]
    timelock = contracts["nexusTimelock"]

    # Check initial state
    print("\n[2/9] Checking initial state...")
    acct0_votes = int(call_contract(token, "getVotes(address)(uint256)", [ACCOUNT0])) / 1e18
    acct1_votes = int(call_contract(token, "getVotes(address)(uint256)", [ACCOUNT1])) / 1e18
    print(f"  Account0 voting power: {acct0_votes:.0f} NXS")
    print(f"  Account1 voting power: {acct1_votes:.0f} NXS")

    # Transfer tokens to Account1 first
    print("\n[3/9] Transferring tokens to Account1...")
    send_tx(token, "transfer(address,uint256)", [ACCOUNT1, str(int(100000 * 1e18))], ACCOUNT0_PK)

    # Delegate from Account0 to Account1
    print("\n[4/9] Setting up delegation (Account0 -> Account1)...")
    send_tx(token, "delegate(address)", [ACCOUNT1], ACCOUNT0_PK)
    send_tx(token, "delegate(address)", [ACCOUNT1], ACCOUNT1_PK)

    # Check new voting power
    acct0_votes = int(call_contract(token, "getVotes(address)(uint256)", [ACCOUNT0])) / 1e18
    acct1_votes = int(call_contract(token, "getVotes(address)(uint256)", [ACCOUNT1])) / 1e18
    print(f"  Account0 voting power: {acct0_votes:.0f} NXS")
    print(f"  Account1 voting power: {acct1_votes:.0f} NXS")

    # Create proposal from Account1 (now has voting power)
    print("\n[5/9] Creating proposal from Account1 (with delegated power)...")
    description = f"Test Proposal Delegation: Update quorum - {int(time.time())}"
    calldata = subprocess.run(
        [CAST, "calldata", "updateQuorumNumerator(uint256)", "4"],
        capture_output=True, text=True
    ).stdout.strip()

    send_tx(
        governor,
        "propose(address[],uint256[],bytes[],string)",
        [f"[{governor}]", "[0]", f"[{calldata}]", description],
        ACCOUNT1_PK  # Account1 creates the proposal
    )

    desc_hash = subprocess.run([CAST, "keccak", description], capture_output=True, text=True).stdout.strip()
    proposal_id = subprocess.run(
        [CAST, "call", governor, "hashProposal(address[],uint256[],bytes[],bytes32)(uint256)",
         f"[{governor}]", "[0]", f"[{calldata}]", desc_hash, "--rpc-url", RPC_URL],
        capture_output=True, text=True
    ).stdout.strip().split()[0]

    print(f"  Proposal ID: {proposal_id}")
    print_status(governor, proposal_id)

    # Advance to voting period
    print("\n[6/9] Advancing to Active voting period...")
    snapshot_block = int(call_contract(governor, "proposalSnapshot(uint256)(uint256)", [proposal_id]))
    current_block = get_block_number()
    blocks_needed = snapshot_block - current_block + 1
    print(f"  Mining {blocks_needed} blocks...")
    mine_blocks(blocks_needed)
    print_status(governor, proposal_id)

    # Vote from Account1 with delegated power
    print("\n[7/9] Account1 voting FOR (with delegated power)...")
    send_tx(governor, "castVote(uint256,uint8)", [proposal_id, "1"], ACCOUNT1_PK)
    print_status(governor, proposal_id)

    # Advance past voting period
    print("\n[8/9] Advancing past voting deadline...")
    deadline = int(call_contract(governor, "proposalDeadline(uint256)(uint256)", [proposal_id]))
    current_block = get_block_number()
    blocks_needed = deadline - current_block + 1
    print(f"  Mining {blocks_needed} blocks...")
    mine_blocks(blocks_needed)
    print_status(governor, proposal_id)

    state = get_proposal_state(governor, proposal_id)
    if state != 4:
        print(f"  ERROR: Expected Succeeded (4), got {STATES.get(state, state)}")
        return False

    # Queue and execute
    print("\n[9/9] Queueing and executing proposal...")
    send_tx(
        governor,
        "queue(address[],uint256[],bytes[],bytes32)",
        [f"[{governor}]", "[0]", f"[{calldata}]", desc_hash],
        ACCOUNT1_PK
    )

    eta = int(call_contract(governor, "proposalEta(uint256)(uint256)", [proposal_id]))
    current_block_data = subprocess.run(
        [CAST, "block", "--rpc-url", RPC_URL, "-j"],
        capture_output=True, text=True
    )
    current_time = int(json.loads(current_block_data.stdout)["timestamp"], 16)
    time_to_wait = eta - current_time + 1

    if time_to_wait > 0:
        print(f"  Advancing time by {time_to_wait} seconds...")
        increase_time(time_to_wait)

    send_tx(
        governor,
        "execute(address[],uint256[],bytes[],bytes32)",
        [f"[{governor}]", "[0]", f"[{calldata}]", desc_hash],
        ACCOUNT1_PK
    )
    print_status(governor, proposal_id)

    state = get_proposal_state(governor, proposal_id)
    if state == 7:
        print("\n" + "=" * 60)
        print("TEST 2 PASSED: Delegated proposal executed successfully!")
        print("=" * 60)

        # Restore delegation
        print("\n[Cleanup] Restoring delegation to self...")
        send_tx(token, "delegate(address)", [ACCOUNT0], ACCOUNT0_PK)
        send_tx(token, "delegate(address)", [ACCOUNT1], ACCOUNT1_PK)

        return True
    else:
        print(f"\n  ERROR: Expected Executed (7), got {STATES.get(state, state)}")
        return False


if __name__ == "__main__":
    print("=" * 60)
    print("NEXUS PROTOCOL - GOVERNANCE END-TO-END TEST")
    print("=" * 60)

    try:
        # Test 1: Direct voting
        result1 = test_governance_direct_voting()

        if result1:
            # Test 2: Delegated voting
            result2 = test_governance_with_delegation()
        else:
            result2 = False
            print("\nSkipping Test 2 due to Test 1 failure")

        print("\n" + "=" * 60)
        print("FINAL RESULTS")
        print("=" * 60)
        print(f"  Test 1 (Direct Voting): {'PASSED' if result1 else 'FAILED'}")
        print(f"  Test 2 (Delegated Voting): {'PASSED' if result2 else 'FAILED'}")

        sys.exit(0 if result1 and result2 else 1)

    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
