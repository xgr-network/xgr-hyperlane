import fs from "node:fs";
import path from "node:path";
import {
  AbiCoder,
  Contract,
  JsonRpcProvider,
  Wallet,
  getAddress,
  getBytes,
  keccak256,
  solidityPacked,
} from "ethers";
import {
  addLeaf,
  branchRoot,
  buildProofFromNodes,
  snapshotNodes,
} from "./merkle.mjs";

const env = (name, fallback = undefined) => {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === "") throw new Error(`missing ${name}`);
  return value;
};

const legacy = (name) => process.env[name];

// Generic route configuration. Legacy XGR_* origin variables remain accepted so
// an existing XGR -> Base deployment can upgrade without rewriting its env file.
const ORIGIN_RPC_URL = env("ORIGIN_RPC_URL", legacy("XGR_RPC_URL"));
const ORIGIN_CHAIN_ID = BigInt(
  env("ORIGIN_CHAIN_ID", legacy("XGR_CHAIN_ID") ?? "1643"),
);
const ORIGIN_DOMAIN = Number(
  env("ORIGIN_DOMAIN", legacy("XGR_DOMAIN") ?? String(ORIGIN_CHAIN_ID)),
);
const ORIGIN_MAILBOX = getAddress(
  env("ORIGIN_MAILBOX", legacy("XGR_MAILBOX")),
);
const ORIGIN_MERKLE_TREE_HOOK = getAddress(
  env("ORIGIN_MERKLE_TREE_HOOK", legacy("XGR_MERKLE_TREE_HOOK")),
);

const ATTESTATION_RPC_URL = env(
  "ATTESTATION_RPC_URL",
  legacy("XGR_RPC_URL"),
);
const ATTESTATION_CHAIN_ID = BigInt(
  env("ATTESTATION_CHAIN_ID", legacy("XGR_CHAIN_ID") ?? "1643"),
);
const ATTESTATION_ROUTE = env(
  "ATTESTATION_ROUTE",
  legacy("XGR_ATTESTATION_DESTINATION") ?? "base",
);
const ATTESTATION_SIGNATURE_FORMAT = env(
  "ATTESTATION_SIGNATURE_FORMAT",
  "eip2537",
).toLowerCase();
if (
  ATTESTATION_SIGNATURE_FORMAT !== "eip2537" &&
  ATTESTATION_SIGNATURE_FORMAT !== "compressed"
) {
  throw new Error(
    "ATTESTATION_SIGNATURE_FORMAT must be eip2537 or compressed",
  );
}

const DESTINATION_RPC_URL = env("DESTINATION_RPC_URL");
const DESTINATION_CHAIN_ID = BigInt(env("DESTINATION_CHAIN_ID"));
const DESTINATION_DOMAIN = Number(env("DESTINATION_DOMAIN"));
const DESTINATION_MAILBOX = getAddress(env("DESTINATION_MAILBOX"));
const RELAYER_PRIVATE_KEY = env("RELAYER_PRIVATE_KEY");

const START_BLOCK = Number(
  env("ORIGIN_START_BLOCK", legacy("XGR_START_BLOCK") ?? "0"),
);
const CONFIRMATIONS = Number(
  env("ORIGIN_CONFIRMATIONS", legacy("XGR_CONFIRMATIONS") ?? "1"),
);
const POLL_MS = Number(env("POLL_INTERVAL_MS", "3000"));
const LOG_CHUNK = Number(
  env("ORIGIN_LOG_CHUNK", legacy("XGR_LOG_CHUNK") ?? "2000"),
);
const COMPACT_AFTER_LEAVES = Number(
  env("RELAYER_COMPACT_AFTER_LEAVES", "10000"),
);
const STATE_PATH = env(
  "RELAYER_STATE_PATH",
  "/data/native-relayer-state.json",
);

for (const [name, value] of [
  ["ORIGIN_DOMAIN", ORIGIN_DOMAIN],
  ["DESTINATION_DOMAIN", DESTINATION_DOMAIN],
  ["ORIGIN_START_BLOCK", START_BLOCK],
  ["ORIGIN_CONFIRMATIONS", CONFIRMATIONS],
  ["ORIGIN_LOG_CHUNK", LOG_CHUNK],
  ["POLL_INTERVAL_MS", POLL_MS],
  ["RELAYER_COMPACT_AFTER_LEAVES", COMPACT_AFTER_LEAVES],
]) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${name} must be a non-negative safe integer`);
  }
}
if (CONFIRMATIONS < 1) {
  throw new Error("ORIGIN_CONFIRMATIONS must be at least 1");
}
if (LOG_CHUNK < 1) {
  throw new Error("ORIGIN_LOG_CHUNK must be at least 1");
}
if (POLL_MS < 250) {
  throw new Error("POLL_INTERVAL_MS must be at least 250");
}
const origin = new JsonRpcProvider(
  ORIGIN_RPC_URL,
  Number(ORIGIN_CHAIN_ID),
  { staticNetwork: true },
);
const attestationProvider = new JsonRpcProvider(
  ATTESTATION_RPC_URL,
  Number(ATTESTATION_CHAIN_ID),
  { staticNetwork: true },
);
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
  {
    type: "function",
    name: "tree",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "branch", type: "bytes32[32]" },
          { name: "count", type: "uint256" },
        ],
      },
    ],
  },
];

const originMailbox = new Contract(ORIGIN_MAILBOX, mailboxAbi, origin);
const originHook = new Contract(ORIGIN_MERKLE_TREE_HOOK, hookAbi, origin);
const destinationMailbox = new Contract(
  DESTINATION_MAILBOX,
  mailboxAbi,
  wallet,
);
const coder = AbiCoder.defaultAbiCoder();

const lower = (value) => String(value).toLowerCase();
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function validateState(state) {
  if (!Number.isSafeInteger(state.nextBlock) || state.nextBlock < 1) {
    throw new Error("relayer state nextBlock is invalid");
  }
  if (!Number.isSafeInteger(state.treeCount) || state.treeCount < 0) {
    throw new Error("relayer state treeCount is invalid");
  }
  if (!Number.isSafeInteger(state.snapshotCount) || state.snapshotCount < 0) {
    throw new Error("relayer state snapshotCount is invalid");
  }
  if (!state.nodes || typeof state.nodes !== "object") {
    throw new Error("relayer state nodes is invalid");
  }
  state.indices ??= {};
  state.messages ??= {};
  return state;
}

function saveState(state) {
  fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true });
  const tmp = `${STATE_PATH}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state));
  fs.renameSync(tmp, STATE_PATH);
}

async function readTreeSnapshot(blockTag) {
  const raw = await originHook.tree({ blockTag });
  const branch = Array.from(raw.branch ?? raw[0]);
  const count = Number(raw.count ?? raw[1]);
  if (!Number.isSafeInteger(count) || count < 0) {
    throw new Error("origin MerkleTreeHook returned invalid tree count");
  }
  return { branch, count };
}

async function bootstrapState() {
  if (START_BLOCK < 1) {
    throw new Error(
      "ORIGIN_START_BLOCK must be at least 1 for a fresh state so the MerkleTreeHook can be snapshotted at the preceding block",
    );
  }
  const snapshotBlock = START_BLOCK - 1;
  const { branch, count } = await readTreeSnapshot(snapshotBlock);
  return validateState({
    version: 2,
    nextBlock: START_BLOCK,
    snapshotBlock,
    snapshotCount: count,
    treeCount: count,
    nodes: snapshotNodes(branch, count),
    indices: {},
    messages: {},
  });
}

function migrateLegacyState(legacyState) {
  if (!Array.isArray(legacyState.leaves)) {
    throw new Error("legacy relayer state leaves is invalid");
  }
  const state = {
    version: 2,
    nextBlock: legacyState.nextBlock,
    snapshotBlock: 0,
    snapshotCount: 0,
    treeCount: 0,
    nodes: {},
    indices: legacyState.indices ?? {},
    messages: legacyState.messages ?? {},
  };
  for (let i = 0; i < legacyState.leaves.length; i++) {
    addLeaf(state, i, legacyState.leaves[i]);
  }
  return validateState(state);
}

async function loadState() {
  try {
    const state = JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
    if (state.version === 2) return validateState(state);
    const migrated = migrateLegacyState(state);
    saveState(migrated);
    console.log(
      JSON.stringify({
        event: "native_relayer_state_migrated",
        route: ATTESTATION_ROUTE,
        treeCount: migrated.treeCount,
      }),
    );
    return migrated;
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
    const state = await bootstrapState();
    saveState(state);
    console.log(
      JSON.stringify({
        event: "native_relayer_state_bootstrapped",
        route: ATTESTATION_ROUTE,
        snapshotBlock: state.snapshotBlock,
        snapshotCount: state.snapshotCount,
      }),
    );
    return state;
  }
}

async function compactState(state, force = false) {
  if (Object.keys(state.messages).length !== 0) return;
  if (!force && state.treeCount - state.snapshotCount < COMPACT_AFTER_LEAVES) return;

  const snapshotBlock = state.nextBlock - 1;
  const { branch, count } = await readTreeSnapshot(snapshotBlock);
  if (count !== state.treeCount) {
    throw new Error(
      `compaction tree count mismatch: rpc ${count}, indexed ${state.treeCount}`,
    );
  }

  state.snapshotBlock = snapshotBlock;
  state.snapshotCount = count;
  state.nodes = snapshotNodes(branch, count);
  state.indices = {};
  saveState(state);

  console.log(
    JSON.stringify({
      event: "native_relayer_state_compacted",
      route: ATTESTATION_ROUTE,
      snapshotBlock,
      snapshotCount: count,
    }),
  );
}

async function assertNetworks() {
  const [originNetwork, attestationNetwork, destinationNetwork] =
    await Promise.all([
      origin.getNetwork(),
      attestationProvider.getNetwork(),
      destinationProvider.getNetwork(),
    ]);

  if (originNetwork.chainId !== ORIGIN_CHAIN_ID) {
    throw new Error(
      `origin RPC chain id mismatch: got ${originNetwork.chainId}, expected ${ORIGIN_CHAIN_ID}`,
    );
  }
  if (attestationNetwork.chainId !== ATTESTATION_CHAIN_ID) {
    throw new Error(
      `attestation RPC chain id mismatch: got ${attestationNetwork.chainId}, expected ${ATTESTATION_CHAIN_ID}`,
    );
  }
  if (destinationNetwork.chainId !== DESTINATION_CHAIN_ID) {
    throw new Error(
      `destination RPC chain id mismatch: got ${destinationNetwork.chainId}, expected ${DESTINATION_CHAIN_ID}`,
    );
  }
}

async function scanOrigin(state) {
  const head = await origin.getBlockNumber();
  const confirmedHead = head - CONFIRMATIONS;
  if (confirmedHead < state.nextBlock) return;

  for (let from = state.nextBlock; from <= confirmedHead; from += LOG_CHUNK) {
    const to = Math.min(from + LOG_CHUNK - 1, confirmedHead);
    const [dispatches, inserts] = await Promise.all([
      originMailbox.queryFilter(originMailbox.filters.Dispatch(), from, to),
      originHook.queryFilter(originHook.filters.InsertedIntoTree(), from, to),
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
      addLeaf(state, index, id);
      if (state.messages[id] !== undefined) {
        state.indices[id] = index;
      }
    }

    state.nextBlock = to + 1;
    saveState(state);
  }
}

function aggregateSignature(attestation) {
  const signature =
    ATTESTATION_SIGNATURE_FORMAT === "compressed"
      ? attestation.aggregateSignatureCompressed
      : attestation.aggregateSignature;

  if (!signature) {
    throw new Error(
      `attestation is missing ${ATTESTATION_SIGNATURE_FORMAT} aggregate signature`,
    );
  }

  const expectedLength =
    ATTESTATION_SIGNATURE_FORMAT === "compressed" ? 96 : 256;
  const actualLength = getBytes(signature).length;
  if (actualLength !== expectedLength) {
    throw new Error(
      `unexpected ${ATTESTATION_SIGNATURE_FORMAT} aggregate signature length: got ${actualLength}, expected ${expectedLength}`,
    );
  }
  return signature;
}

async function getAttestation() {
  const attestation = await attestationProvider.send(
    "xgr_getInterchainAttestation",
    [ATTESTATION_ROUTE],
  );

  if (
    attestation.chain &&
    lower(attestation.chain) !== lower(ATTESTATION_ROUTE)
  ) {
    throw new Error("attestation route mismatch");
  }
  if (BigInt(attestation.originChainId) !== ORIGIN_CHAIN_ID) {
    throw new Error("attestation origin chain id mismatch");
  }
  if (
    attestation.originDomain !== undefined &&
    Number(attestation.originDomain) !== ORIGIN_DOMAIN
  ) {
    throw new Error("attestation origin domain mismatch");
  }
  if (Number(attestation.destinationDomain) !== DESTINATION_DOMAIN) {
    throw new Error("attestation destination domain mismatch");
  }
  if (lower(attestation.mailbox) !== lower(ORIGIN_MAILBOX)) {
    throw new Error("attestation mailbox mismatch");
  }
  if (
    lower(attestation.merkleTreeHook) !==
    lower(ORIGIN_MERKLE_TREE_HOOK)
  ) {
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
      ORIGIN_MAILBOX,
      ORIGIN_MERKLE_TREE_HOOK,
      attestation.root,
      Number(attestation.index),
    ],
  );
  if (lower(expectedPayload) !== lower(attestation.payload)) {
    throw new Error("attestation canonical payload mismatch");
  }

  aggregateSignature(attestation);
  return attestation;
}

function buildMetadata(state, id, attestation) {
  const messageIndex = state.indices[id];
  const checkpointIndex = Number(attestation.index);
  if (messageIndex === undefined || messageIndex > checkpointIndex) return null;
  if (checkpointIndex >= state.treeCount) return null;

  const proof = buildProofFromNodes(
    state.nodes,
    messageIndex,
    checkpointIndex,
    state.snapshotCount,
  );
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
      aggregateSignature(attestation),
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

  let deliveredAny = false;
  for (const [id, message] of Object.entries(state.messages)) {
    if (state.indices[id] === undefined) continue;

    if (await destinationMailbox.delivered(id)) {
      delete state.messages[id];
      delete state.indices[id];
      deliveredAny = true;
      saveState(state);
      continue;
    }

    const metadata = buildMetadata(state, id, attestation);
    if (!metadata) continue;

    const tx = await destinationMailbox.process(metadata, message);
    console.log(
      JSON.stringify({
        event: "relay_submitted",
        route: ATTESTATION_ROUTE,
        messageId: id,
        checkpointIndex: Number(attestation.index),
        setId: String(attestation.setId),
        signatureFormat: ATTESTATION_SIGNATURE_FORMAT,
        txHash: tx.hash,
      }),
    );
    const receipt = await tx.wait();
    if (!receipt || receipt.status !== 1) {
      throw new Error(`destination process failed for ${id}`);
    }

    delete state.messages[id];
    delete state.indices[id];
    deliveredAny = true;
    saveState(state);
  }

  if (deliveredAny && Object.keys(state.messages).length === 0) {
    // Compact immediately after clearing pending work; this bounds Base-origin
    // state even when the canonical Hyperlane tree is very busy.
    await compactState(state, true);
  }
}

async function main() {
  await assertNetworks();
  const state = await loadState();

  console.log(
    JSON.stringify({
      event: "native_relayer_started",
      route: ATTESTATION_ROUTE,
      originChainId: String(ORIGIN_CHAIN_ID),
      originDomain: ORIGIN_DOMAIN,
      destinationChainId: String(DESTINATION_CHAIN_ID),
      destinationDomain: DESTINATION_DOMAIN,
      attestationChainId: String(ATTESTATION_CHAIN_ID),
      signatureFormat: ATTESTATION_SIGNATURE_FORMAT,
      relayer: wallet.address,
      nextBlock: state.nextBlock,
      snapshotCount: state.snapshotCount,
      treeCount: state.treeCount,
    }),
  );

  for (;;) {
    try {
      await scanOrigin(state);
      await relayAvailable(state);
      await compactState(state);
    } catch (err) {
      console.error(
        JSON.stringify({
          event: "native_relayer_error",
          route: ATTESTATION_ROUTE,
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
