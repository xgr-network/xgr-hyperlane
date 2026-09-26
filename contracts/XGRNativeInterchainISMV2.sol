// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXGRInterchainValidatorSetV2} from "./IXGRInterchainValidatorSetV2.sol";
import {IXGRInterchainBLSVerifier} from "./XGRInterchainValidatorRegistry.sol";

/// @notice Hyperlane ISM for messages from a configured external origin, secured by native XGR
///         interchain BLS validator subset.
/// @dev The relayer is untrusted. It supplies only the message inclusion proof
///      and an already-completed XGR quorum attestation. The ISM reconstructs
///      the signed checkpoint payload and verifies it against the current
///      destination registry set.
///
/// Metadata ABI:
/// abi.encode(
///   uint32 messageIndex,
///   bytes32[32] merkleProof,
///   uint32 checkpointIndex,
///   uint64 setId,
///   bytes signerBitmap,
///   bytes aggregateSignature
/// )
contract XGRNativeInterchainISMV2 {
    bytes private constant CHECKPOINT_DOMAIN_V1 = "XGR_INTERCHAIN_CHECKPOINT_V1";
    uint256 private constant TREE_DEPTH = 32;
    uint256 private constant COMPRESSED_G2_SIGNATURE_LENGTH = 96;
    uint256 private constant EIP2537_G2_SIGNATURE_LENGTH = 256;
    uint8 private constant VERIFIER_FORMAT_COMPRESSED = 1;
    uint8 private constant VERIFIER_FORMAT_EIP2537 = 2;
    uint8 private constant MODULE_TYPE_CUSTOM = 0;

    IXGRInterchainValidatorSetV2 public immutable registry;
    IXGRInterchainBLSVerifier public immutable verifier;

    uint64 public immutable membershipOriginChainId;
    uint64 public immutable checkpointOriginChainId;
    uint32 public immutable originDomain;
    uint32 public immutable destinationDomain;
    address public immutable originMailbox;
    address public immutable originMerkleTreeHook;

    error InvalidConfiguration();

    constructor(
        address registry_,
        uint64 checkpointOriginChainId_,
        uint32 originDomain_,
        address originMailbox_,
        address originMerkleTreeHook_
    ) {
        if (
            registry_ == address(0) ||
            checkpointOriginChainId_ == 0 ||
            originDomain_ == 0 ||
            originMailbox_ == address(0) ||
            originMerkleTreeHook_ == address(0)
        ) revert InvalidConfiguration();

        IXGRInterchainValidatorSetV2 registryView = IXGRInterchainValidatorSetV2(registry_);
        uint64 membershipOrigin = registryView.originChainId();
        uint32 destination = registryView.destinationDomain();
        address verifierAddress = registryView.verifier();
        uint8 format = registryView.verifierKeyFormat();

        if (
            membershipOrigin == 0 ||
            destination == 0 ||
            verifierAddress == address(0) ||
            (format != VERIFIER_FORMAT_COMPRESSED && format != VERIFIER_FORMAT_EIP2537)
        ) {
            revert InvalidConfiguration();
        }

        registry = registryView;
        verifier = IXGRInterchainBLSVerifier(verifierAddress);
        membershipOriginChainId = membershipOrigin;
        checkpointOriginChainId = checkpointOriginChainId_;
        originDomain = originDomain_;
        destinationDomain = destination;
        originMailbox = originMailbox_;
        originMerkleTreeHook = originMerkleTreeHook_;
    }

    function moduleType() external pure returns (uint8) {
        return MODULE_TYPE_CUSTOM;
    }

    function verify(bytes calldata metadata, bytes calldata message)
        external
        view
        returns (bool)
    {
        if (message.length < 77) return false;
        if (_messageOrigin(message) != originDomain) return false;
        if (_messageDestination(message) != destinationDomain) return false;

        (
            uint32 messageIndex,
            bytes32[32] memory proof,
            uint32 checkpointIndex,
            uint64 metadataSetId,
            bytes memory signerBitmap,
            bytes memory aggregateSignature
        ) = abi.decode(
            metadata,
            (uint32, bytes32[32], uint32, uint64, bytes, bytes)
        );

        if (messageIndex > checkpointIndex) return false;
        if (metadataSetId == 0) return false;
        uint8 format = registry.verifierKeyFormat();
        if (
            (format == VERIFIER_FORMAT_COMPRESSED &&
                aggregateSignature.length != COMPRESSED_G2_SIGNATURE_LENGTH) ||
            (format == VERIFIER_FORMAT_EIP2537 &&
                aggregateSignature.length != EIP2537_G2_SIGNATURE_LENGTH)
        ) return false;

        bytes32 signedRoot = _branchRoot(
            keccak256(message),
            proof,
            uint256(messageIndex)
        );
        if (signedRoot == bytes32(0)) return false;

        (
            address[] memory validators,
            bytes[] memory publicKeys,
            uint64 currentSetId
        ) = registry.getValidatorSetForVerification();

        if (
            currentSetId != metadataSetId ||
            validators.length == 0 ||
            validators.length != publicKeys.length
        ) return false;

        uint256 threshold = (2 * validators.length + 2) / 3;
        if (!_bitmapHasQuorum(signerBitmap, validators.length, threshold)) {
            return false;
        }

        bytes memory checkpointPayload = encodeCheckpointPayload(
            currentSetId,
            signedRoot,
            checkpointIndex
        );

        return verifier.verify(
            checkpointPayload,
            publicKeys,
            signerBitmap,
            aggregateSignature
        );
    }

    /// @notice Reconstructs the exact byte payload signed by XGR 3.0 nodes.
    function encodeCheckpointPayload(
        uint64 setId,
        bytes32 root,
        uint32 checkpointIndex
    ) public view returns (bytes memory) {
        if (setId == 0 || root == bytes32(0)) revert InvalidConfiguration();

        return abi.encodePacked(
            CHECKPOINT_DOMAIN_V1,
            bytes8(checkpointOriginChainId),
            bytes4(destinationDomain),
            bytes8(setId),
            bytes20(originMailbox),
            bytes20(originMerkleTreeHook),
            root,
            bytes4(checkpointIndex)
        );
    }

    function _messageOrigin(bytes calldata message) private pure returns (uint32) {
        return uint32(bytes4(message[5:9]));
    }

    function _messageDestination(bytes calldata message) private pure returns (uint32) {
        return uint32(bytes4(message[41:45]));
    }

    function _branchRoot(
        bytes32 item,
        bytes32[32] memory branch,
        uint256 index
    ) private pure returns (bytes32 current) {
        current = item;
        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            bytes32 sibling = branch[i];
            if (((index >> i) & 1) == 1) {
                current = keccak256(abi.encodePacked(sibling, current));
            } else {
                current = keccak256(abi.encodePacked(current, sibling));
            }
        }
    }

    // Same big-endian validator-index bitmap convention used by the native
    // registry and XGR node attestation worker.
    function _bitmapHasQuorum(
        bytes memory bitmap,
        uint256 validatorCount,
        uint256 threshold
    ) private pure returns (bool) {
        if (validatorCount == 0 || threshold == 0 || bitmap.length == 0) {
            return false;
        }

        uint256 maxBitmapLength = (validatorCount + 7) / 8;
        if (bitmap.length > maxBitmapLength || bitmap[0] == bytes1(0)) {
            return false;
        }

        uint256 count;
        for (uint256 i = 0; i < validatorCount; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (uint8(bitmap[bitmap.length - 1 - byteFromEnd]) & uint8(1 << bitIndex)) != 0
            ) {
                count++;
            }
        }

        for (uint256 i = validatorCount; i < bitmap.length * 8; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (uint8(bitmap[bitmap.length - 1 - byteFromEnd]) & uint8(1 << bitIndex)) != 0
            ) {
                return false;
            }
        }

        return count >= threshold;
    }
}
