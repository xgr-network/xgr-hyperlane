#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from eth_account import Account
from web3 import Web3

RPC = "https://rpc.xgr.network"
CHAIN_ID = 1643
DESTINATION = 8453
MAILBOX = Web3.to_checksum_address("0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79")
KEY_PATH = Path(__file__).resolve().parent / "runtime-state" / "keys" / "relayer" / "consensus" / "validator.key"
BODY = b"xgr-hyperlane-beta-checkpoint-1"
MAX_QUOTE_WEI = Web3.to_wei("0.25", "ether")
MAX_TOTAL_WEI = Web3.to_wei("0.60", "ether")

ABI = [
    {
        "inputs": [
            {"internalType":"uint32","name":"destinationDomain","type":"uint32"},
            {"internalType":"bytes32","name":"recipientAddress","type":"bytes32"},
            {"internalType":"bytes","name":"messageBody","type":"bytes"}
        ],
        "name":"quoteDispatch",
        "outputs":[{"internalType":"uint256","name":"fee","type":"uint256"}],
        "stateMutability":"view",
        "type":"function"
    },
    {
        "inputs": [
            {"internalType":"uint32","name":"destinationDomain","type":"uint32"},
            {"internalType":"bytes32","name":"recipientAddress","type":"bytes32"},
            {"internalType":"bytes","name":"messageBody","type":"bytes"}
        ],
        "name":"dispatch",
        "outputs":[{"internalType":"bytes32","name":"messageId","type":"bytes32"}],
        "stateMutability":"payable",
        "type":"function"
    },
    {
        "anonymous":False,
        "inputs":[{"indexed":True,"internalType":"bytes32","name":"messageId","type":"bytes32"}],
        "name":"DispatchId",
        "type":"event"
    },
    {
        "inputs":[],
        "name":"localDomain",
        "outputs":[{"internalType":"uint32","name":"","type":"uint32"}],
        "stateMutability":"view",
        "type":"function"
    }
]

def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

if not KEY_PATH.is_file():
    fail("host-local relayer key is missing")

raw_key = KEY_PATH.read_text(encoding="utf-8").strip()
if raw_key.startswith("0x"):
    raw_key = raw_key[2:]
if len(raw_key) != 64:
    fail("unexpected relayer key format")

w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 30}))
if not w3.is_connected():
    fail("XGR RPC unavailable")
if w3.eth.chain_id != CHAIN_ID:
    fail(f"unexpected chain id {w3.eth.chain_id}")

account = Account.from_key(bytes.fromhex(raw_key))
contract = w3.eth.contract(address=MAILBOX, abi=ABI)
if contract.functions.localDomain().call() != CHAIN_ID:
    fail("Mailbox localDomain mismatch")

# Use the relayer EOA as a harmless bytes32 recipient for this infrastructure-only test.
recipient = bytes.fromhex("00" * 12 + account.address[2:])
fee = contract.functions.quoteDispatch(DESTINATION, recipient, BODY).call({"from": account.address})
if fee > MAX_QUOTE_WEI:
    fail(f"quote exceeds safety cap: {fee} wei")

gas_price = w3.eth.gas_price
fn = contract.functions.dispatch(DESTINATION, recipient, BODY)
gas_estimate = fn.estimate_gas({"from": account.address, "value": fee})
gas_limit = max(gas_estimate + 25000, int(gas_estimate * 1.20))
total_cap = fee + gas_limit * gas_price
if total_cap > MAX_TOTAL_WEI:
    fail(f"estimated maximum spend exceeds safety cap: {total_cap} wei")

tx = fn.build_transaction({
    "from": account.address,
    "nonce": w3.eth.get_transaction_count(account.address, "pending"),
    "chainId": CHAIN_ID,
    "value": fee,
    "gas": gas_limit,
    "gasPrice": gas_price,
})
signed = account.sign_transaction(tx)
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120, poll_latency=2)
if receipt.status != 1:
    fail(f"dispatch reverted: {tx_hash.hex()}")

events = contract.events.DispatchId().process_receipt(receipt)
if len(events) != 1:
    fail(f"expected one DispatchId event, got {len(events)}")
message_id = events[0]["args"]["messageId"].hex()

print(json.dumps({
    "sender": account.address,
    "destinationDomain": DESTINATION,
    "recipient": "0x" + recipient.hex(),
    "bodyUtf8": BODY.decode("utf-8"),
    "quoteWei": str(fee),
    "gasPriceWei": str(gas_price),
    "gasUsed": str(receipt.gasUsed),
    "blockNumber": receipt.blockNumber,
    "txHash": tx_hash.hex(),
    "messageId": message_id,
}, separators=(",", ":")))
