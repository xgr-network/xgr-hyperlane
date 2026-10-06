import {
  AbiCoder,
  JsonRpcProvider,
  getAddress,
  getBytes,
  hexlify,
} from "ethers";

const RPC_URL =
  process.env.BASE_RPC_URL ?? "https://base-rpc.publicnode.com";
const TX_HASH =
  process.env.BASE_V1_REGISTRY_DEPLOY_TX ??
  "0x5331761a279fd2f187c28439a7b54048f072427f4d0807cb712b88b631883778";

const XGR_CHAIN_ID = 1643n;
const BASE_DOMAIN = 8453n;
const BASE_BLS_VERIFIER =
  "0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93";

const provider = new JsonRpcProvider(RPC_URL, 8453, {
  staticNetwork: true,
});
const coder = AbiCoder.defaultAbiCoder();

const tx = await provider.getTransaction(TX_HASH);
if (!tx) {
  throw new Error("Base V1 registry deployment transaction not found");
}
if (tx.to !== null) {
  throw new Error("expected a contract-creation transaction");
}

const marker = coder.encode(
  ["uint64", "uint32", "address"],
  [XGR_CHAIN_ID, BASE_DOMAIN, BASE_BLS_VERIFIER],
);
const data = tx.data.toLowerCase();
const markerBody = marker.slice(2).toLowerCase();

const first = data.indexOf(markerBody);
if (first < 2) {
  throw new Error("constructor argument marker not found in deployment input");
}
const second = data.indexOf(markerBody, first + markerBody.length);
if (second !== -1) {
  throw new Error("constructor argument marker is ambiguous");
}

const encodedArgs = `0x${data.slice(first)}`;
const decoded = coder.decode(
  [
    "uint64",
    "uint32",
    "address",
    "uint256",
    "uint256",
    "address[]",
    "bytes[]",
    "bytes[]",
    "bytes[]",
  ],
  encodedArgs,
);

const [
  originChainId,
  destinationDomain,
  verifier,
  minimumDeactivationReserveWei,
  maxExecutorReimbursementWei,
  validators,
  compressedKeys,
  eip2537Keys,
  possessionProofs,
] = decoded;

if (
  BigInt(originChainId) !== XGR_CHAIN_ID ||
  BigInt(destinationDomain) !== BASE_DOMAIN ||
  getAddress(verifier) !== getAddress(BASE_BLS_VERIFIER)
) {
  throw new Error("decoded constructor identity does not match Base V1 registry");
}
if (
  validators.length !== 3 ||
  compressedKeys.length !== validators.length ||
  eip2537Keys.length !== validators.length ||
  possessionProofs.length !== validators.length
) {
  throw new Error("unexpected Base V1 bootstrap set shape");
}

const result = {
  transaction: TX_HASH,
  originChainId: originChainId.toString(),
  destinationDomain: Number(destinationDomain),
  verifier: getAddress(verifier),
  minimumDeactivationReserveWei:
    minimumDeactivationReserveWei.toString(),
  maxExecutorReimbursementWei:
    maxExecutorReimbursementWei.toString(),
  validators: validators.map(getAddress),
  compressedKeys: compressedKeys.map((value) =>
    hexlify(getBytes(value)),
  ),
  eip2537Keys: eip2537Keys.map((value) =>
    hexlify(getBytes(value)),
  ),
  possessionProofs: possessionProofs.map((value) =>
    hexlify(getBytes(value)),
  ),
};

console.log(JSON.stringify(result, null, 2));
console.log("");
console.log("# DeployILNBaseRegistries environment");
console.log(
  `BASE_DESTINATION_MINIMUM_RESERVE_WEI=${result.minimumDeactivationReserveWei}`,
);
console.log(
  `BASE_DESTINATION_MAX_REIMBURSEMENT_WEI=${result.maxExecutorReimbursementWei}`,
);
for (let i = 0; i < result.possessionProofs.length; i++) {
  console.log(
    `BASE_DESTINATION_BOOTSTRAP_PROOF_${i}=${result.possessionProofs[i]}`,
  );
}
