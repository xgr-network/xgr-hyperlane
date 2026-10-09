// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXGRInterchainValidatorSet} from "./IXGRInterchainValidatorSet.sol";
import {IXGRInterchainBLSVerifier} from "./XGRInterchainValidatorRegistry.sol";

/// @notice Message-specific ILN ISM compatible with the existing Base V1
///         destination validator registry.
/// @dev This preserves the v3.1.1 Base validator-set contract. Like the
///      previous V1 ISM, an attestation must reference the current set at
///      delivery time. The v3.1.2 message-specific authorization is still
///      strictly stronger than the old root-only checkpoint authorization.
contract XGRILNInterchainISM {
    bytes private constant CHECKPOINT_DOMAIN_V1 =
        "XGR_ILN_CHECKPOINT_V1";

    uint256 private constant TREE_DEPTH = 32;
    uint256 private constant EIP2537_G2_SIGNATURE_LENGTH = 256;
    uint8 private constant MODULE_TYPE_CUSTOM = 0;

    IXGRInterchainValidatorSet public immutable registry;
    IXGRInterchainBLSVerifier public immutable verifier;

    uint64 public immutable sourceChainId;
    uint32 public immutable originDomain;
    uint32 public immutable destinationDomain;
    address public immutable sourceILNRegistry;
    address public immutable sourceGateway;
    address public immutable sourceRouter;
    address public immutable originMailbox;
    address public immutable originMerkleTreeHook;
    address public immutable destinationRouter;

    error InvalidConfiguration();

    constructor(
        address validatorRegistry_,
        uint64 sourceChainId_,
        uint32 originDomain_,
        address sourceILNRegistry_,
        address sourceGateway_,
        address sourceRouter_,
        address originMailbox_,
        address originMerkleTreeHook_,
        address destinationRouter_
    ) {
        if (
            validatorRegistry_ == address(0) ||
            sourceChainId_ == 0 ||
            originDomain_ == 0 ||
            sourceILNRegistry_ == address(0) ||
            sourceGateway_ == address(0) ||
            sourceRouter_ == address(0) ||
            originMailbox_ == address(0) ||
            originMerkleTreeHook_ == address(0) ||
            destinationRouter_ == address(0)
        ) revert InvalidConfiguration();

        IXGRInterchainValidatorSet registryView =
            IXGRInterchainValidatorSet(validatorRegistry_);

        uint64 registryOriginChainId =
            registryView.originChainId();
        uint32 destination =
            registryView.destinationDomain();
        address verifierAddress =
            registryView.verifier();

        if (
            registryOriginChainId != sourceChainId_ ||
            destination == 0 ||
            verifierAddress == address(0)
        ) revert InvalidConfiguration();

        registry = registryView;
        verifier = IXGRInterchainBLSVerifier(verifierAddress);
        sourceChainId = sourceChainId_;
        originDomain = originDomain_;
        destinationDomain = destination;
        sourceILNRegistry = sourceILNRegistry_;
        sourceGateway = sourceGateway_;
        sourceRouter = sourceRouter_;
        originMailbox = originMailbox_;
        originMerkleTreeHook = originMerkleTreeHook_;
        destinationRouter = destinationRouter_;
    }

    function moduleType() external pure returns (uint8) {
        return MODULE_TYPE_CUSTOM;
    }

    function verify(
        bytes calldata metadata,
        bytes calldata message
    ) external view returns (bool) {
        if (message.length < 77) return false;
        if (_messageOrigin(message) != originDomain) return false;
        if (_messageDestination(message) != destinationDomain) return false;
        if (
            _messageSender(message) !=
            bytes32(uint256(uint160(sourceRouter)))
        ) return false;
        if (
            _messageRecipient(message) !=
            bytes32(uint256(uint160(destinationRouter)))
        ) return false;

        (
            uint32 messageIndex,
            bytes32[32] memory proof,
            uint32 checkpointIndex,
            uint64 setId,
            uint64 sourceBlockNumber,
            uint256 routeValidatorFeeWei,
            bytes32 authorizedMessageId,
            bytes memory signerBitmap,
            bytes memory aggregateSignature
        ) = abi.decode(
            metadata,
            (
                uint32,
                bytes32[32],
                uint32,
                uint64,
                uint64,
                uint256,
                bytes32,
                bytes,
                bytes
            )
        );

        if (
            messageIndex > checkpointIndex ||
            setId == 0 ||
            sourceBlockNumber == 0 ||
            routeValidatorFeeWei == 0 ||
            aggregateSignature.length != EIP2537_G2_SIGNATURE_LENGTH
        ) return false;

        bytes32 actualMessageId = keccak256(message);
        if (
            authorizedMessageId == bytes32(0) ||
            authorizedMessageId != actualMessageId
        ) return false;

        bytes32 signedRoot = _branchRoot(
            actualMessageId,
            proof,
            uint256(messageIndex)
        );
        if (signedRoot == bytes32(0)) return false;

        (
            address[] memory validators,
            bytes[] memory publicKeys,
            uint64 currentSetId
        ) = registry.getValidatorSetEIP2537();

        if (
            currentSetId != setId ||
            validators.length == 0 ||
            validators.length != publicKeys.length
        ) return false;

        uint256 threshold =
            (2 * validators.length + 2) / 3;
        if (
            !_bitmapHasQuorum(
                signerBitmap,
                validators.length,
                threshold
            )
        ) return false;

        bytes memory payload = encodeCheckpointPayload(
            setId,
            sourceBlockNumber,
            routeValidatorFeeWei,
            authorizedMessageId,
            signedRoot,
            checkpointIndex
        );

        return verifier.verify(
            payload,
            publicKeys,
            signerBitmap,
            aggregateSignature
        );
    }

    function encodeCheckpointPayload(
        uint64 setId,
        uint64 sourceBlockNumber,
        uint256 routeValidatorFeeWei,
        bytes32 authorizedMessageId,
        bytes32 root,
        uint32 checkpointIndex
    ) public view returns (bytes memory) {
        if (
            setId == 0 ||
            sourceBlockNumber == 0 ||
            routeValidatorFeeWei == 0 ||
            authorizedMessageId == bytes32(0) ||
            root == bytes32(0)
        ) revert InvalidConfiguration();

        return abi.encodePacked(
            CHECKPOINT_DOMAIN_V1,
            bytes8(sourceChainId),
            bytes4(originDomain),
            bytes4(destinationDomain),
            bytes8(setId),
            bytes8(sourceBlockNumber),
            bytes20(sourceILNRegistry),
            bytes20(sourceGateway),
            bytes20(sourceRouter),
            bytes20(originMailbox),
            bytes20(originMerkleTreeHook),
            bytes20(destinationRouter),
            bytes32(routeValidatorFeeWei),
            authorizedMessageId,
            root,
            bytes4(checkpointIndex)
        );
    }

    function _messageOrigin(bytes calldata message)
        private
        pure
        returns (uint32)
    {
        return uint32(bytes4(message[5:9]));
    }

    function _messageSender(bytes calldata message)
        private
        pure
        returns (bytes32)
    {
        return bytes32(message[9:41]);
    }

    function _messageDestination(bytes calldata message)
        private
        pure
        returns (uint32)
    {
        return uint32(bytes4(message[41:45]));
    }

    function _messageRecipient(bytes calldata message)
        private
        pure
        returns (bytes32)
    {
        return bytes32(message[45:77]);
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
                current = keccak256(
                    abi.encodePacked(sibling, current)
                );
            } else {
                current = keccak256(
                    abi.encodePacked(current, sibling)
                );
            }
        }
    }

    function _bitmapHasQuorum(
        bytes memory bitmap,
        uint256 validatorCount,
        uint256 threshold
    ) private pure returns (bool) {
        if (
            validatorCount == 0 ||
            threshold == 0 ||
            bitmap.length == 0
        ) return false;

        uint256 maxBitmapLength =
            (validatorCount + 7) / 8;
        if (
            bitmap.length > maxBitmapLength ||
            bitmap[0] == bytes1(0)
        ) return false;

        uint256 count;
        for (uint256 i = 0; i < validatorCount; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (
                    uint8(bitmap[bitmap.length - 1 - byteFromEnd]) &
                    uint8(1 << bitIndex)
                ) != 0
            ) count++;
        }

        for (uint256 i = validatorCount; i < bitmap.length * 8; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (
                    uint8(bitmap[bitmap.length - 1 - byteFromEnd]) &
                    uint8(1 << bitIndex)
                ) != 0
            ) return false;
        }

        return count >= threshold;
    }
}
