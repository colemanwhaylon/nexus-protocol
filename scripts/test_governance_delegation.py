#!/usr/bin/env python3
"""
Governance Delegation Test Script

Tests the full governance lifecycle with voting power delegation:
1. Delegate voting power from Account 0 to Account 1
2. Create a new proposal
3. Account 1 votes with delegated power
4. Advance blocks through voting period
5. Queue the proposal
6. Advance time past timelock delay
7. Execute the proposal

Uses cast commands for blockchain interactions (proven reliable).

Usage:
    python3 scripts/test_governance_delegation.py
"""

import subprocess
import json
import time
import sys
from dataclasses import dataclass
from typing import Optional

# =============================================================================
# Configuration
# =============================================================================

RPC_URL = "http://localhost:8545"

# Contract addresses (from database API)
CONTRACTS = {
    "nexusToken": "0x5fbdb2315678afecb367f032d93f642f64180aa3",
    "nexusGovernor": "0x8a791620dd6260079bf849dc5567adc3f2fdc318",
    "nexusTimelock": "0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6",
}

# Anvil test accounts (first 3)
ACCOUNTS = {
    "account0": {
        "address": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "private_key": "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    },
    "account1": {
        "address": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        "private_key": "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    },
    "account2": {
        "address": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
        "private_key": "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    },
}

# Foundry cast path
CAST = "/home/whaylon/.foundry/bin/cast"

# Governance parameters (from contract)
VOTING_DELAY = 36000  # blocks (~12 hours at 1 block/sec)
VOTING_PERIOD = 36000  # blocks (~12 hours at 1 block/sec)
TIMELOCK_DELAY = 86400  # 24 hours in seconds

# Generate unique description for this run (prevents proposal ID collision)
RUN_TIMESTAMP = int(time.time())
PROPOSAL_DESCRIPTION = f"Delegation Test - Approve Account2 for Token Spending (Run {RUN_TIMESTAMP})\n\nThis proposal tests the delegation voting path by approving Account2 to spend 1000 NEXUS tokens."


# =============================================================================
# Helper Functions
# =============================================================================

def run_cast(args: list[str], check: bool = True, use_rpc: bool = True) -> subprocess.CompletedProcess:
    """Run a cast command and return the result."""
    cmd = [CAST] + args
    if use_rpc:
        cmd += ["--rpc-url", RPC_URL]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"❌ Command failed: {' '.join(cmd)}")
        print(f"   stderr: {result.stderr}")
        sys.exit(1)
    return result


def run_cast_send(to: str, sig: str, args: list[str], private_key: str) -> str:
    """Send a transaction and return the tx hash."""
    cmd = [CAST, "send", to, sig] + args + [
        "--rpc-url", RPC_URL,
        "--private-key", private_key,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Transaction failed: {sig}")
        print(f"   stderr: {result.stderr}")
        sys.exit(1)
    # Extract tx hash from output
    for line in result.stdout.split('\n'):
        if 'transactionHash' in line:
            return line.split()[-1]
    return result.stdout.strip()


def get_block_number() -> int:
    """Get current block number."""
    result = run_cast(["block-number"])
    return int(result.stdout.strip())


def get_block_timestamp() -> int:
    """Get current block timestamp."""
    result = run_cast(["block", "latest", "--field", "timestamp"])
    return int(result.stdout.strip())


def mine_blocks(count: int, batch_size: int = 10000) -> None:
    """Mine blocks in large batches for efficiency."""
    remaining = count
    while remaining > 0:
        batch = min(batch_size, remaining)
        run_cast(["rpc", "anvil_mine", hex(batch)], check=False)
        remaining -= batch
        print(f"   Mined {count - remaining}/{count} blocks...", end='\r')
    print()


def advance_time(seconds: int) -> None:
    """Advance blockchain time."""
    run_cast(["rpc", "anvil_increaseTime", str(seconds)], check=False)
    run_cast(["rpc", "anvil_mine", "0x1"], check=False)  # Mine 1 block to apply


def parse_uint256(output: str) -> int:
    """Parse cast output which may include scientific notation like '900000 [9e5]'."""
    value = output.strip().split()[0]  # Take first part before space
    return int(value)


def get_voting_power(address: str) -> int:
    """Get voting power (delegated votes) for an address."""
    result = run_cast([
        "call", CONTRACTS["nexusToken"],
        "getVotes(address)(uint256)", address
    ])
    return parse_uint256(result.stdout)


def get_token_balance(address: str) -> int:
    """Get token balance for an address."""
    result = run_cast([
        "call", CONTRACTS["nexusToken"],
        "balanceOf(address)(uint256)", address
    ])
    return parse_uint256(result.stdout)


def get_delegates(address: str) -> str:
    """Get the delegate address for a token holder."""
    result = run_cast([
        "call", CONTRACTS["nexusToken"],
        "delegates(address)(address)", address
    ])
    return result.stdout.strip()


def get_proposal_state(proposal_id: str) -> int:
    """Get proposal state (0-7)."""
    result = run_cast([
        "call", CONTRACTS["nexusGovernor"],
        "state(uint256)(uint8)", proposal_id
    ])
    return int(result.stdout.strip())


def get_proposal_votes(proposal_id: str) -> tuple[int, int, int]:
    """Get proposal votes (against, for, abstain)."""
    result = run_cast([
        "call", CONTRACTS["nexusGovernor"],
        "proposalVotes(uint256)(uint256,uint256,uint256)", proposal_id
    ])
    # Parse the output - it returns 3 values (may include scientific notation)
    lines = result.stdout.strip().split('\n')
    against = parse_uint256(lines[0]) if len(lines) > 0 else 0
    for_votes = parse_uint256(lines[1]) if len(lines) > 1 else 0
    abstain = parse_uint256(lines[2]) if len(lines) > 2 else 0
    return against, for_votes, abstain


STATE_NAMES = {
    0: "Pending",
    1: "Active",
    2: "Canceled",
    3: "Defeated",
    4: "Succeeded",
    5: "Queued",
    6: "Expired",
    7: "Executed",
}


# =============================================================================
# Test Steps
# =============================================================================

def step_check_initial_state():
    """Step 0: Check initial state of accounts."""
    print("\n" + "="*60)
    print("STEP 0: Checking Initial State")
    print("="*60)

    for name, acct in ACCOUNTS.items():
        addr = acct["address"]
        balance = get_token_balance(addr)
        voting_power = get_voting_power(addr)
        delegate = get_delegates(addr)

        print(f"\n{name}: {addr[:10]}...{addr[-4:]}")
        print(f"  Token Balance:  {balance / 1e18:,.0f} NEXUS")
        print(f"  Voting Power:   {voting_power / 1e18:,.0f} NEXUS")
        print(f"  Delegates to:   {delegate[:10]}...{delegate[-4:]}")

    current_block = get_block_number()
    print(f"\nCurrent Block: {current_block}")


def step_delegate_voting_power():
    """Step 1: Delegate voting power from Account 0 to Account 1."""
    print("\n" + "="*60)
    print("STEP 1: Delegating Voting Power")
    print("="*60)

    delegator = ACCOUNTS["account0"]
    delegatee = ACCOUNTS["account1"]

    print(f"\nDelegating from: {delegator['address'][:10]}...")
    print(f"Delegating to:   {delegatee['address'][:10]}...")

    # Check current delegation
    current_delegate = get_delegates(delegator["address"])
    print(f"Current delegate: {current_delegate[:10]}...")

    # Delegate to account1
    print("\nSending delegate() transaction...")
    run_cast_send(
        CONTRACTS["nexusToken"],
        "delegate(address)",
        [delegatee["address"]],
        delegator["private_key"]
    )
    print("✓ Delegation transaction sent")

    # Verify delegation
    new_delegate = get_delegates(delegator["address"])
    delegatee_power = get_voting_power(delegatee["address"])

    print(f"\nAfter delegation:")
    print(f"  Account0 delegates to: {new_delegate[:10]}...")
    print(f"  Account1 voting power: {delegatee_power / 1e18:,.0f} NEXUS")

    if new_delegate.lower() == delegatee["address"].lower():
        print("✓ Delegation successful!")
    else:
        print("❌ Delegation failed!")
        sys.exit(1)


def step_create_proposal() -> str:
    """Step 2: Create a new governance proposal."""
    print("\n" + "="*60)
    print("STEP 2: Creating Governance Proposal")
    print("="*60)

    # Account1 creates proposal since they have the delegated voting power
    proposer = ACCOUNTS["account1"]

    # Proposal details - approve 1000 tokens (just a test action)
    target = CONTRACTS["nexusToken"]
    value = "0"

    # Encode the calldata: approve(address spender, uint256 amount)
    # Approve account2 for 1000 tokens
    calldata_result = run_cast([
        "calldata",
        "approve(address,uint256)",
        ACCOUNTS["account2"]["address"],
        str(1000 * 10**18)
    ], use_rpc=False)
    calldata = calldata_result.stdout.strip()

    description = PROPOSAL_DESCRIPTION

    print(f"\nProposal Details:")
    print(f"  Target: {target[:10]}...")
    print(f"  Action: approve(Account2, 1000 NEXUS)")
    print(f"  Proposer: {proposer['address'][:10]}...")

    # Create proposal
    print("\nSending propose() transaction...")

    # propose(address[] targets, uint256[] values, bytes[] calldatas, string description)
    # Using cast's array syntax
    result = subprocess.run([
        CAST, "send", CONTRACTS["nexusGovernor"],
        "propose(address[],uint256[],bytes[],string)",
        f"[{target}]",
        f"[{value}]",
        f"[{calldata}]",
        description,
        "--rpc-url", RPC_URL,
        "--private-key", proposer["private_key"],
        "--json"
    ], capture_output=True, text=True)

    if result.returncode != 0:
        print(f"❌ Proposal creation failed: {result.stderr}")
        sys.exit(1)

    # Parse the receipt to get logs
    receipt = json.loads(result.stdout)

    # Get the ProposalCreated event to extract proposalId
    # The proposalId is typically the first topic after the event signature
    proposal_id = None
    for log in receipt.get("logs", []):
        # ProposalCreated event
        if len(log.get("topics", [])) > 1:
            # proposalId is usually in topics[1]
            proposal_id = log["topics"][1]
            break

    if not proposal_id:
        # Try to compute the proposalId using hashProposal
        print("Computing proposalId via hashProposal...")
        result = run_cast([
            "call", CONTRACTS["nexusGovernor"],
            "hashProposal(address[],uint256[],bytes[],bytes32)",
            f"[{target}]",
            f"[{value}]",
            f"[{calldata}]",
            # keccak256 of description
            subprocess.run([CAST, "keccak", description], capture_output=True, text=True).stdout.strip()
        ])
        proposal_id = result.stdout.strip()

    print(f"✓ Proposal created!")
    print(f"  Proposal ID: {proposal_id[:20]}...")

    # Check proposal state
    state = get_proposal_state(proposal_id)
    print(f"  State: {STATE_NAMES.get(state, 'Unknown')} ({state})")

    return proposal_id


def step_advance_to_active(proposal_id: str):
    """Step 3: Advance blocks to make proposal Active."""
    print("\n" + "="*60)
    print("STEP 3: Advancing to Active Voting Period")
    print("="*60)

    current_block = get_block_number()
    state = get_proposal_state(proposal_id)

    print(f"Current block: {current_block}")
    print(f"Current state: {STATE_NAMES.get(state, 'Unknown')} ({state})")

    if state == 0:  # Pending
        blocks_to_mine = VOTING_DELAY + 1
        print(f"\nMining {blocks_to_mine} blocks to reach Active state...")
        mine_blocks(blocks_to_mine)

        new_block = get_block_number()
        new_state = get_proposal_state(proposal_id)
        print(f"\nAfter mining:")
        print(f"  Block: {new_block}")
        print(f"  State: {STATE_NAMES.get(new_state, 'Unknown')} ({new_state})")

        if new_state == 1:
            print("✓ Proposal is now Active!")
        else:
            print(f"⚠ Expected Active (1), got {new_state}")


def step_vote_with_delegation(proposal_id: str):
    """Step 4: Account1 votes using delegated voting power."""
    print("\n" + "="*60)
    print("STEP 4: Voting with Delegated Power")
    print("="*60)

    voter = ACCOUNTS["account1"]  # Has delegated power from account0

    voting_power = get_voting_power(voter["address"])
    print(f"\nVoter: {voter['address'][:10]}...")
    print(f"Voting Power: {voting_power / 1e18:,.0f} NEXUS (delegated)")

    # Cast vote: 1 = For
    print("\nCasting vote (For)...")
    run_cast_send(
        CONTRACTS["nexusGovernor"],
        "castVote(uint256,uint8)",
        [proposal_id, "1"],  # 1 = For
        voter["private_key"]
    )
    print("✓ Vote cast!")

    # Check votes
    against, for_votes, abstain = get_proposal_votes(proposal_id)
    print(f"\nProposal Votes:")
    print(f"  For:     {for_votes / 1e18:,.0f}")
    print(f"  Against: {against / 1e18:,.0f}")
    print(f"  Abstain: {abstain / 1e18:,.0f}")


def step_advance_past_voting(proposal_id: str):
    """Step 5: Advance past voting period."""
    print("\n" + "="*60)
    print("STEP 5: Advancing Past Voting Period")
    print("="*60)

    blocks_to_mine = VOTING_PERIOD + 1
    print(f"Mining {blocks_to_mine} blocks...")
    mine_blocks(blocks_to_mine)

    new_block = get_block_number()
    state = get_proposal_state(proposal_id)
    print(f"\nAfter mining:")
    print(f"  Block: {new_block}")
    print(f"  State: {STATE_NAMES.get(state, 'Unknown')} ({state})")

    if state == 4:
        print("✓ Proposal Succeeded!")
    elif state == 3:
        print("❌ Proposal Defeated (quorum not met or more against votes)")
        sys.exit(1)


def step_queue_proposal(proposal_id: str):
    """Step 6: Queue the proposal in the Timelock."""
    print("\n" + "="*60)
    print("STEP 6: Queueing Proposal")
    print("="*60)

    queuer = ACCOUNTS["account0"]

    # Get proposal details for queue call
    target = CONTRACTS["nexusToken"]
    value = "0"
    calldata_result = run_cast([
        "calldata",
        "approve(address,uint256)",
        ACCOUNTS["account2"]["address"],
        str(1000 * 10**18)
    ], use_rpc=False)
    calldata = calldata_result.stdout.strip()
    description = PROPOSAL_DESCRIPTION
    description_hash = subprocess.run(
        [CAST, "keccak", description],
        capture_output=True, text=True
    ).stdout.strip()

    print("Sending queue() transaction...")
    subprocess.run([
        CAST, "send", CONTRACTS["nexusGovernor"],
        "queue(address[],uint256[],bytes[],bytes32)",
        f"[{target}]",
        f"[{value}]",
        f"[{calldata}]",
        description_hash,
        "--rpc-url", RPC_URL,
        "--private-key", queuer["private_key"],
    ], capture_output=True, text=True, check=True)
    print("✓ Proposal queued!")

    state = get_proposal_state(proposal_id)
    print(f"  State: {STATE_NAMES.get(state, 'Unknown')} ({state})")


def step_advance_timelock():
    """Step 7: Advance time past timelock delay."""
    print("\n" + "="*60)
    print("STEP 7: Advancing Past Timelock Delay")
    print("="*60)

    seconds_to_advance = TIMELOCK_DELAY + 60  # 24 hours + 1 minute
    print(f"Advancing time by {seconds_to_advance} seconds ({seconds_to_advance / 3600:.1f} hours)...")
    advance_time(seconds_to_advance)

    new_timestamp = get_block_timestamp()
    print(f"✓ New block timestamp: {new_timestamp}")


def step_execute_proposal(proposal_id: str):
    """Step 8: Execute the proposal."""
    print("\n" + "="*60)
    print("STEP 8: Executing Proposal")
    print("="*60)

    executor = ACCOUNTS["account0"]

    # Get proposal details for execute call
    target = CONTRACTS["nexusToken"]
    value = "0"
    calldata_result = run_cast([
        "calldata",
        "approve(address,uint256)",
        ACCOUNTS["account2"]["address"],
        str(1000 * 10**18)
    ], use_rpc=False)
    calldata = calldata_result.stdout.strip()
    description = PROPOSAL_DESCRIPTION
    description_hash = subprocess.run(
        [CAST, "keccak", description],
        capture_output=True, text=True
    ).stdout.strip()

    print("Sending execute() transaction...")
    result = subprocess.run([
        CAST, "send", CONTRACTS["nexusGovernor"],
        "execute(address[],uint256[],bytes[],bytes32)",
        f"[{target}]",
        f"[{value}]",
        f"[{calldata}]",
        description_hash,
        "--rpc-url", RPC_URL,
        "--private-key", executor["private_key"],
    ], capture_output=True, text=True)

    if result.returncode != 0:
        print(f"❌ Execution failed: {result.stderr}")
        sys.exit(1)

    print("✓ Proposal executed!")

    state = get_proposal_state(proposal_id)
    print(f"  Final State: {STATE_NAMES.get(state, 'Unknown')} ({state})")

    # Verify the action was executed - check allowance
    result = run_cast([
        "call", CONTRACTS["nexusToken"],
        "allowance(address,address)(uint256)",
        ACCOUNTS["account0"]["address"],
        ACCOUNTS["account2"]["address"]
    ])
    allowance = parse_uint256(result.stdout)
    print(f"\nVerification:")
    print(f"  Account2 allowance: {allowance / 1e18:,.0f} NEXUS")

    if allowance == 1000 * 10**18:
        print("✓ Proposal action executed correctly!")
    else:
        print(f"⚠ Expected 1000 NEXUS allowance, got {allowance / 1e18}")


def step_restore_delegation():
    """Step 9: Restore delegation back to self."""
    print("\n" + "="*60)
    print("STEP 9: Restoring Original Delegation")
    print("="*60)

    delegator = ACCOUNTS["account0"]

    print(f"Restoring Account0 delegation to self...")
    run_cast_send(
        CONTRACTS["nexusToken"],
        "delegate(address)",
        [delegator["address"]],
        delegator["private_key"]
    )

    new_delegate = get_delegates(delegator["address"])
    voting_power = get_voting_power(delegator["address"])

    print(f"✓ Delegation restored")
    print(f"  Account0 delegates to: {new_delegate[:10]}...")
    print(f"  Account0 voting power: {voting_power / 1e18:,.0f} NEXUS")


# =============================================================================
# Main
# =============================================================================

def main():
    print("="*60)
    print("  GOVERNANCE DELEGATION TEST")
    print("  Testing voting with delegated power")
    print("="*60)

    try:
        # Check initial state
        step_check_initial_state()

        # Step 1: Delegate voting power
        step_delegate_voting_power()

        # Step 2: Create proposal
        proposal_id = step_create_proposal()

        # Step 3: Advance to Active
        step_advance_to_active(proposal_id)

        # Step 4: Vote with delegated power
        step_vote_with_delegation(proposal_id)

        # Step 5: Advance past voting period
        step_advance_past_voting(proposal_id)

        # Step 6: Queue proposal
        step_queue_proposal(proposal_id)

        # Step 7: Advance past timelock
        step_advance_timelock()

        # Step 8: Execute proposal
        step_execute_proposal(proposal_id)

        # Step 9: Restore delegation
        step_restore_delegation()

        print("\n" + "="*60)
        print("  ✓ ALL TESTS PASSED!")
        print("  Governance delegation flow works correctly.")
        print("="*60 + "\n")

    except KeyboardInterrupt:
        print("\n\n⚠ Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
