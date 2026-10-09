// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRNativeInterchainISM} from "../contracts/XGRNativeInterchainISM.sol";
import {XGRInterchainValidatorRegistry} from "../contracts/XGRInterchainValidatorRegistry.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRNativeInterchainISMTest is Test {
    MockXGRInterchainBLSVerifier internal verifier;
    XGRInterchainValidatorRegistry internal registry;
    XGRNativeInterchainISM internal ism;

    address internal constant ORIGIN_MAILBOX = 0x1111111111111111111111111111111111111111;
    address internal constant ORIGIN_HOOK = 0x2222222222222222222222222222222222222222;

    function setUp() public {
        vm.deal(address(this), 10 ether);
        verifier = new MockXGRInterchainBLSVerifier();

        address[] memory validators = new address[](3);
        validators[0] = address(0xA1);
        validators[1] = address(0xB2);
        validators[2] = address(0xC3);

        bytes[] memory keys = new bytes[](3);
        bytes[] memory eipKeys = new bytes[](3);
        bytes[] memory proofs = new bytes[](3);
        for (uint256 i = 0; i < 3; i++) {
            keys[i] = _bytes(48, uint8(i + 1));
            eipKeys[i] = _bytes(128, uint8(i + 11));
            proofs[i] = hex"01";
        }

        registry = new XGRInterchainValidatorRegistry{value: 3 ether}(
            1643,
            8453,
            address(verifier),
            1 ether,
            0.1 ether,
            validators,
            keys,
            eipKeys,
            proofs
        );

        ism = new XGRNativeInterchainISM(
            address(registry),
            1643,
            ORIGIN_MAILBOX,
            ORIGIN_HOOK
        );
    }

    function testCanonicalCheckpointPayloadMatchesXGRNodeVector() public view {
        bytes memory payload = ism.encodeCheckpointPayload(
            7,
            0x3333333333333333333333333333333333333333333333333333333333333333,
            42
        );

        assertEq(
            payload,
            hex"5847525f494e544552434841494e5f434845434b504f494e545f5631000000000000066b0000210500000000000000071111111111111111111111111111111111111111222222222222222222222222222222222222222233333333333333333333333333333333333333333333333333333333333333330000002a"
        );
    }

    function testCurrentTwoOfThreeQuorumVerifies() public view {
        bytes memory message = _message(1643, 8453);
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(256, 0x44)
        );

        assertTrue(ism.verify(metadata, message));
    }

    function testOneOfThreeQuorumRejected() public view {
        bytes memory message = _message(1643, 8453);
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"01",
            _bytes(256, 0x44)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testStaleSetIdRejected() public view {
        bytes memory message = _message(1643, 8453);
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(2),
            hex"03",
            _bytes(256, 0x44)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testOutOfRangeBitmapRejected() public view {
        bytes memory message = _message(1643, 8453);
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"83",
            _bytes(256, 0x44)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testWrongOriginRejected() public view {
        bytes memory message = _message(1, 8453);
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(256, 0x44)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testWrongDestinationRejected() public view {
        bytes memory message = _message(1643, 1);
        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(256, 0x44)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testMessageCannotUseOlderCheckpoint() public view {
        bytes memory message = _message(1643, 8453);
        bytes memory metadata = abi.encode(
            uint32(1),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            hex"03",
            _bytes(256, 0x44)
        );

        assertFalse(ism.verify(metadata, message));
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
            bytes("xgr-native-ism-test")
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
        for (uint256 i = 0; i < length; i++) {
            out[i] = bytes1(value);
        }
    }
}
