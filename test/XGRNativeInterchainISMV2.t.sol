// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {XGRNativeInterchainISMV2} from "../contracts/XGRNativeInterchainISMV2.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRNativeInterchainISMV2Test is Test {
    XGRNativeInterchainISMV2 internal ism;

    address internal constant ORIGIN_MAILBOX = 0x1111111111111111111111111111111111111111;
    address internal constant ORIGIN_HOOK = 0x2222222222222222222222222222222222222222;

    function setUp() public {
        vm.deal(address(this), 10 ether);
        MockXGRInterchainBLSVerifier verifier = new MockXGRInterchainBLSVerifier();

        address[] memory validators = new address[](3);
        bytes[] memory keys = new bytes[](3);
        bytes[] memory eipKeys = new bytes[](3);
        bytes[] memory proofs = new bytes[](3);
        for (uint256 i = 0; i < 3; i++) {
            validators[i] = address(uint160(0xA1 + i));
            keys[i] = _bytes(48, uint8(i + 1));
            eipKeys[i] = _bytes(128, uint8(i + 11));
            proofs[i] = _bytes(96, uint8(i + 21));
        }

        XGRInterchainValidatorRegistryV2 registry =
            new XGRInterchainValidatorRegistryV2{value: 3 ether}(
                1643,
                1643,
                address(verifier),
                XGRInterchainValidatorRegistryV2.VERIFIER_FORMAT_COMPRESSED(),
                1 ether,
                0.1 ether,
                validators,
                keys,
                eipKeys,
                proofs
            );

        ism = new XGRNativeInterchainISMV2(
            address(registry),
            8453,
            8453,
            ORIGIN_MAILBOX,
            ORIGIN_HOOK
        );
    }

    function testMembershipAuthorityAndCheckpointOriginAreSeparate() public view {
        assertEq(ism.membershipOriginChainId(), 1643);
        assertEq(ism.checkpointOriginChainId(), 8453);
        assertEq(ism.originDomain(), 8453);
        assertEq(ism.destinationDomain(), 1643);
    }

    function testCanonicalCheckpointPayloadUsesExternalOriginChainId() public view {
        bytes32 root = 0x3333333333333333333333333333333333333333333333333333333333333333;
        bytes memory expected = abi.encodePacked(
            bytes("XGR_INTERCHAIN_CHECKPOINT_V1"),
            bytes8(uint64(8453)),
            bytes4(uint32(1643)),
            bytes8(uint64(1)),
            bytes20(ORIGIN_MAILBOX),
            bytes20(ORIGIN_HOOK),
            root,
            bytes4(uint32(42))
        );
        assertEq(ism.encodeCheckpointPayload(1, root, 42), expected);
    }

    function testTwoOfThreeCompressedQuorumVerifies() public view {
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(96, 0x44)
        );
        assertTrue(ism.verify(metadata, _message(8453, 1643)));
    }

    function testWrongCompressedSignatureLengthRejected() public view {
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(256, 0x44)
        );
        assertFalse(ism.verify(metadata, _message(8453, 1643)));
    }

    function testWrongOriginRejected() public view {
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(96, 0x44)
        );
        assertFalse(ism.verify(metadata, _message(1, 1643)));
    }

    function testOneOfThreeRejected() public view {
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"01",
            _bytes(96, 0x44)
        );
        assertFalse(ism.verify(metadata, _message(8453, 1643)));
    }

    function _message(uint32 origin, uint32 destination)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(3),
            uint32(7),
            origin,
            bytes32(uint256(uint160(address(0x1234)))),
            destination,
            bytes32(uint256(uint160(address(0x5678)))),
            bytes("xgr-native-ism-v2-test")
        );
    }

    function _singleLeafProof()
        internal
        pure
        returns (bytes32[32] memory proof)
    {
        bytes32 zero;
        for (uint256 i = 0; i < 32; i++) {
            proof[i] = zero;
            zero = keccak256(abi.encodePacked(zero, zero));
        }
    }

    function _bytes(uint256 length, uint8 value)
        internal
        pure
        returns (bytes memory out)
    {
        out = new bytes(length);
        for (uint256 i = 0; i < length; i++) out[i] = bytes1(value);
    }
}
