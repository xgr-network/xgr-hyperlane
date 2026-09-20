import fs from "node:fs";
import path from "node:path";
import {
  AbiCoder,
  Contract,
  JsonRpcProvider,
  Wallet,
  concat,
  getAddress,
  keccak256,
  solidityPacked,
} from "ethers";

const env = (name, fallback = undefined) => {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === "") throw new Error(`missing ${name}`);
  return value;
};

const XGR_RPC_URL = env("XGR_RPC_URL");
const DESTINATION_RPC_URL = env("DESTINATION_RPC_URL");
const XGR_MAILBOX = getAddress(env("XGR_MAILBOX"));
const XGR_MERKLE_TREE_HOOK = getAddress(env("XGR_MERKLE_TREE_HOOK"));
const DESTINATION_MAILBOX = getAddress(env("DESTINATION_MAILBOX"));
const RELAYER_PRIVATE_KEY = env("RELAYER_PRIVATE_KEY");
const ATTESTATION_DESTINATION = env("XGR_ATTESTATION_DESTINATION", "base");

const ORIGIN_CHAIN_ID = BigInt(env("XGR_CHAIN_ID", "1643"));
const ORIGIN_DOMAIN = Number(env("XGR_DOMAIN", "1643"));
const DESTINATION_CHAIN_ID = BigInt(env("DESTINATION_CHAIN_ID", "8453"));
const DESTINATION_DOMAIN = Number(env("DESTINATION_DOMAIN", "8453"));

const START_BLOCK = Number(env("XGR_START_BLOCK", "0"));
const CONFIRMATIONS = Number(env("XGR_CONFIRMATIONS", "1"));
const POLL_MS = Number(env("POLL_INTERVAL_MS", "3000"));
const LOG_CHUNK = Number(env("XGR_LOG_CHUNK", "2000"));
const STATE_PATH = env("RELAYER_STATE_PATH", "/data/native-relayer-state.json");

const xgr = new JsonRpcProvider(XGR_RPC_URL, Number(ORIGIN_CHAIN_ID), {
  staticNetwork: true,
});
const destinationProvider = new JsonRpcProvider(
  DESTINATION_RPC_URL,
  Number(DESTINATION_CHAIN_ID),
  { staticNetwork: true },
);
const wallet = new Wallet(RELAYER_PRIVATE_KEY, destinationProvider);

const mailboxAbi = [
  "event Dispatch(address indexed sender,uint32 indexed destination,bytes32 indexed recipient,bytes message)",
  "function delivered(bytes32 messageId) view returns (bool)",
  "function process(bytes metadata,bytes message) payable",
];
const hookAbi = [
  "event InsertedIntoTree(bytes32 messageId,uint32 index)",
];

const xgrMailbox = new Contract(XGR_MAILBOX, mailboxAbi, xgr);
const hook = new Contract(XGR_MERKLE_TREE_HOOK, hookAbi, xgr);
const destinationMailbox = new Contract(DESTINATION_MAILBOX, mailboxAbi, wallet);
const coder = AbiCoder.defaultAbiCoder();

const lower = (value) => String(value).toLowerCase();
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
    return {
      nextBlock: START_BLOCK,
      leaves: [],
      indices: {},
      messages: {},
    };
  }
}

function saveState(state) {
  fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true });
  const tmp = `${STATE_PATH}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state));
  fs.renameSync(tmp, STATE_PATH);
}

function zeroHashes() {
  const values = [];
  let current = "0x" + "00".repeat(32);
  for (let i = 0; i < 32; i++) {
    values.push(current);
    current = keccak256(concat([current, current]));
  }
  return values;
}

const ZERO_HASHES = zeroHashes();

function buildProof(leaves, targetIndex, checkpointIndex) {
  if (
    targetIndex < 0 ||
    checkpointIndex < targetIndex ||
    checkpointIndex >= leaves.length
  ) {
    throw new Error("invalid proof bounds");
  }

  let nodes = leaves.slice(0, checkpointIndex + 1);
  let index = targetIndex;
  const proof = [];

  for (let level = 0; level < 32; level++) {
    const siblingIndex = index ^ 1;
    proof.push(
      siblingIndex < nodes.length ? nodes[siblingIndex] : ZERO_HASHES[level],
    );

    const parents = [];
    for (let i = 0; i < nodes.length; i += 2) {
      const left = nodes[i] ?? ZERO_HASHES[level];
      const right = nodes[i + 1] ?? ZERO_HASHES[level];
      parents.push(keccak256(concat([left, right])));
    }
    nodes = parents;
    index = Math.floor(index / 2);
  }

  return proof;
}

function branchRoot(leaf, proof, index) {
  let current = leaf;
  const indexBits = BigInt(index);
  for (let i = 0; i < 32; i++) {
    current =
      ((indexBits >> BigInt(i)) & 1n) === 1n
        ? keccak256(concat([proof[i], current]))
        : keccak256(concat([current, proof[i]]));
  }
  return current;
}

async function assertNetworks() {
  const [originNetwork, destinationNetwork] = await Promise.all([
    xgr.getNetwork(),
    destinationProvider.getNetwork(),
  ]);
  if (originNetwork.chainId !== ORIGIN_CHAIN_ID) {
    throw new Error(
      `XGR RPC chain id mismatch: got ${originNetwork.chainId}, expected ${ORIGIN_CHAIN_ID}`,
    );
  }
  if (destinationNetwork.chainId !== DESTINATION_CHAIN_ID) {
    throw new Error(
      `destination RPC chain id mismatch: got ${destinationNetwork.chainId}, expected ${DESTINATION_CHAIN_ID}`,
    );
  }
}

async function scanOrigin(state) {
  const head = await xgr.getBlockNumber();
  const confirmedHead = head - CONFIRMATIONS;
  if (confirmedHead < state.nextBlock) return;

  for (let from = state.nextBlock; from <= confirmedHead; from += LOG_CHUNK) {
    const to = Math.min(from + LOG_CHUNK - 1, confirmedHead);
    const [dispatches, inserts] = await Promise.all([
      xgrMailbox.queryFilter(xgrMailbox.filters.Dispatch(), from, to),
      hook.queryFilter(hook.filters.InsertedIntoTree(), from, to),
    ]);

    for (const event of dispatches) {
      const destination = Number(event.args.destination);
      if (destination !== DESTINATION_DOMAIN) continue;
      const message = event.args.message;
      const id = lower(keccak256(message));
      state.messages[id] = message;
    }

    for (const event of inserts) {
      const id = lower(event.args.messageId);
      const index = Number(event.args.index);
      if (index < state.leaves.length) {
        if (lower(state.leaves[index]) !== id) {
          throw new Error(`merkle history mismatch at index ${index}`);
        }
      } else if (index === state.leaves.length) {
        state.leaves.push(id);
      } else {
        throw new Error(
          `merkle history gap: got index ${index}, expected ${state.leaves.length}`,
        );
      }
      state.indices[id] = index;
    }

    state.nextBlock = to + 1;
    saveState(state);
  }
}

async function getAttestation() {
  const attestation = await xgr.send("xgr_getInterchainAttestation", [
    ATTESTATION_DESTINATION,
  ]);

  if (BigInt(attestation.originChainId) !== ORIGIN_CHAIN_ID) {
    throw new Error("attestation origin chain id mismatch");
  }
  if (Number(attestation.destinationDomain) !== DESTINATION_DOMAIN) {
    throw new Error("attestation destination domain mismatch");
  }
  if (lower(attestation.mailbox) !== lower(XGR_MAILBOX)) {
    throw new Error("attestation mailbox mismatch");
  }
  if (lower(attestation.merkleTreeHook) !== lower(XGR_MERKLE_TREE_HOOK)) {
    throw new Error("attestation merkle tree hook mismatch");
  }

  const expectedPayload = solidityPacked(
    [
      "string",
      "uint64",
      "uint32",
      "uint64",
      "address",
      "address",
      "bytes32",
      "uint32",
    ],
    [
      "XGR_INTERCHAIN_CHECKPOINT_V1",
      ORIGIN_CHAIN_ID,
      DESTINATION_DOMAIN,
      BigInt(attestation.setId),
      XGR_MAILBOX,
      XGR_MERKLE_TREE_HOOK,
      attestation.root,
      Number(attestation.index),
    ],
  );
  if (lower(expectedPayload) !== lower(attestation.payload)) {
    throw new Error("attestation canonical payload mismatch");
  }

  return attestation;
}

function buildMetadata(state, id, attestation) {
  const messageIndex = state.indices[id];
  const checkpointIndex = Number(attestation.index);
  if (messageIndex === undefined || messageIndex > checkpointIndex) return null;
  if (checkpointIndex >= state.leaves.length) return null;

  const proof = buildProof(state.leaves, messageIndex, checkpointIndex);
  const root = branchRoot(id, proof, messageIndex);
  if (lower(root) !== lower(attestation.root)) {
    throw new Error(
      `local merkle root mismatch: computed ${root}, attested ${attestation.root}`,
    );
  }

  return coder.encode(
    ["uint32", "bytes32[32]", "uint32", "uint64", "bytes", "bytes"],
    [
      messageIndex,
      proof,
      checkpointIndex,
      BigInt(attestation.setId),
      attestation.signerBitmap,
      attestation.aggregateSignature,
    ],
  );
}

async function relayAvailable(state) {
  let attestation;
  try {
    attestation = await getAttestation();
  } catch (err) {
    if (String(err).includes("attestation not found")) return;
    throw err;
  }

  for (const [id, message] of Object.entries(state.messages)) {
    if (state.indices[id] === undefined) continue;

    if (await destinationMailbox.delivered(id)) {
      delete state.messages[id];
      saveState(state);
      continue;
    }

    const metadata = buildMetadata(state, id, attestation);
    if (!metadata) continue;

    const tx = await destinationMailbox.process(metadata, message);
    console.log(
      JSON.stringify({
        event: "relay_submitted",
        messageId: id,
        checkpointIndex: Number(attestation.index),
        setId: String(attestation.setId),
        txHash: tx.hash,
      }),
    );
    await tx.wait();

    delete state.messages[id];
    saveState(state);
  }
}

async function main() {
  await assertNetworks();
  const state = loadState();

  console.log(
    JSON.stringify({
      event: "native_relayer_started",
      originDomain: ORIGIN_DOMAIN,
      destinationDomain: DESTINATION_DOMAIN,
      relayer: wallet.address,
      nextBlock: state.nextBlock,
    }),
  );

  for (;;) {
    try {
      await scanOrigin(state);
      await relayAvailable(state);
    } catch (err) {
      console.error(
        JSON.stringify({
          event: "native_relayer_error",
          error: err instanceof Error ? err.message : String(err),
        }),
      );
    }
    await sleep(POLL_MS);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
