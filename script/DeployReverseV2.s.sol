// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {XGRNativeInterchainISMV2} from "../contracts/XGRNativeInterchainISMV2.sol";

/// @notice Deploys the reverse Base -> XGR validator registry on XGR mainnet.
/// @dev Public validator keys and possession proofs are intentionally embedded.
///      The deployer private key is read from DEPLOYER_PRIVATE_KEY at runtime and
///      must never be committed.
contract DeployReverseRegistryV2 is Script {
    uint64 internal constant XGR_CHAIN_ID = 1643;
    uint32 internal constant XGR_DOMAIN = 1643;
    address internal constant NATIVE_BLS_VERIFIER =
        0x0000000000000000000000000000000000002040;
    uint8 internal constant VERIFIER_FORMAT_COMPRESSED = 1;

    uint256 internal constant MINIMUM_DEACTIVATION_RESERVE_WEI = 1 ether;
    uint256 internal constant MAX_EXECUTOR_REIMBURSEMENT_WEI = 0.5 ether;

    function run() external returns (XGRInterchainValidatorRegistryV2 registry) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address[] memory validators = new address[](3);
        bytes[] memory compressedKeys = new bytes[](3);
        bytes[] memory eip2537Keys = new bytes[](3);
        bytes[] memory possessionProofs = new bytes[](3);

        // Canonical interchain ordering: 98F8, 7E8f, 7913.
        validators[0] = 0x98F8bC086454B8386788244eee9A43d5D0b4E63E;
        compressedKeys[0] = hex"a65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1";
        eip2537Keys[0] = hex"00000000000000000000000000000000065579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d10000000000000000000000000000000016ff663f783f1724010ed4271eb717536eef96f97a7fbc69593e9c2b841b12012945b436bf9055d99e2712411f66d2ab";
        possessionProofs[0] = hex"b2076f6177634a14050a68be00d8759f42e03b7686bc2336045ba10e6fa7ba8259cccf1cfed9e890844c00917a538c1d0ed102091a8978bec7c6d0c82d60c1df376b6db14389655ce2f741f546677e8dcc644511c0452ec335b7ac248487a0e1";

        validators[1] = 0x7E8f8Fd2A198F77dF298041b48D79b0df4c8B1fa;
        compressedKeys[1] = hex"a32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71";
        eip2537Keys[1] = hex"00000000000000000000000000000000032a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71000000000000000000000000000000000e07952cb4fa21c27354f2f8efdbc81a0f5e248641125b3c0a713079ebe780889aed234ac226c3d892b2acf3210eeb7c";
        possessionProofs[1] = hex"b28ce74de26284df847d9d3d8978ad0e5d84c51b4054dbc82b300c15bb7c2bfd1f1264d82cc0699771e835d46f3786ab001343c71f07531fa0da9b1e2ea3c8f6b0a88cd3066c81656b5e35d80f57a528a277ee5da8be4dc23f82b5b39959c4bf";

        validators[2] = 0x7913fDAe82C678F42B98Ca8076Fe7D13b3EdFF15;
        compressedKeys[2] = hex"b56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88";
        eip2537Keys[2] = hex"00000000000000000000000000000000156b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88000000000000000000000000000000000ff4b97c544a6915099d22d4b5abb6b35a3290cba39def4a1a8b902df5d94d9bc6bd98fe2f183e24fa16e41072de97fc";
        possessionProofs[2] = hex"a37fcc2668f5613990bbded924f361d423d70b4d7bf3504bcf1e9c2159cd2d99e3cb87f794beae5c5cf53b6b92fd82a905d003fe47b48dccf83bc59f25542456da92eefc6ae1f12e4485a39459d5c20d14fb75b97dacdf5ac6101017c1db1386";

        vm.startBroadcast(deployerPrivateKey);
        registry = new XGRInterchainValidatorRegistryV2{value: 3 ether}(
            XGR_CHAIN_ID,
            XGR_DOMAIN,
            NATIVE_BLS_VERIFIER,
            VERIFIER_FORMAT_COMPRESSED,
            MINIMUM_DEACTIVATION_RESERVE_WEI,
            MAX_EXECUTOR_REIMBURSEMENT_WEI,
            validators,
            compressedKeys,
            eip2537Keys,
            possessionProofs
        );
        vm.stopBroadcast();
    }
}

/// @notice Deploys the reverse Base -> XGR ISM after the registry has been
///         deployed and verified on XGR mainnet.
/// @dev REGISTRY_V2 must be the verified registry address from the previous step.
contract DeployReverseISMV2 is Script {
    uint64 internal constant BASE_CHAIN_ID = 8453;
    uint32 internal constant BASE_DOMAIN = 8453;

    address internal constant BASE_MAILBOX =
        0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D;
    address internal constant BASE_MERKLE_TREE_HOOK =
        0x19dc38aeae620380430C200a6E990D5Af5480117;

    function run() external returns (XGRNativeInterchainISMV2 ism) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address registry = vm.envAddress("REGISTRY_V2");

        vm.startBroadcast(deployerPrivateKey);
        ism = new XGRNativeInterchainISMV2(
            registry,
            BASE_CHAIN_ID,
            BASE_DOMAIN,
            BASE_MAILBOX,
            BASE_MERKLE_TREE_HOOK
        );
        vm.stopBroadcast();
    }
}
