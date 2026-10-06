// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {XGRILNInterchainISMV2} from "../contracts/XGRILNInterchainISMV2.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRILNInterchainISMV2Test is Test {
    XGRILNInterchainISMV2 internal ism;

    address internal constant SOURCE_REGISTRY =
        0x1010101010101010101010101010101010101010;
    address internal constant SOURCE_GATEWAY =
        0x1111111111111111111111111111111111111111;
    address internal constant SOURCE_ROUTER =
        0x2222222222222222222222222222222222222222;
    address internal constant SOURCE_MAILBOX =
        0x3333333333333333333333333333333333333333;
    address internal constant SOURCE_HOOK =
        0x4444444444444444444444444444444444444444;
    address internal constant DEST_ROUTER =
        0x5555555555555555555555555555555555555555;

    function setUp() public {
        vm.deal(address(this), 10 ether);
        MockXGRInterchainBLSVerifier verifier =
            new MockXGRInterchainBLSVerifier();

        address[] memory validators = new address[](3);
        bytes[] memory compressed = new bytes[](3);
        bytes[] memory eip = new bytes[](3);
        bytes[] memory proofs = new bytes[](3);

        for (uint256 i = 0; i < 3; i++) {
            validators[i] = address(uint160(0xA1 + i));
            compressed[i] = _bytes(48, uint8(i + 1));
            eip[i] = _bytes(128, uint8(i + 11));
            proofs[i] = _bytes(96, uint8(i + 21));
        }

        XGRInterchainValidatorRegistryV2 registry =
            new XGRInterchainValidatorRegistryV2{value: 3 ether}(
                1643,
                1643,
                address(verifier),
                1,
                1 ether,
                0.1 ether,
                validators,
                compressed,
                eip,
                proofs
            );

        ism = new XGRILNInterchainISMV2(
            address(registry),
            8453,
            8453,
            SOURCE_REGISTRY,
            SOURCE_GATEWAY,
            SOURCE_ROUTER,
            SOURCE_MAILBOX,
            SOURCE_HOOK,
            DEST_ROUTER
        );
    }

    function testMessageSpecificAuthorizationVerifies() public view {
        bytes memory message = _message();
        bytes32 messageId = keccak256(message);
        bytes32[32] memory proof = _singleLeafProof();

        bytes memory metadata = abi.encode(
            uint32(0),
            proof,
            uint32(0),
            uint64(1),
            uint64(123456),
            uint256(1000),
            messageId,
            hex"03",
            _bytes(96, 0x77)
        );

        assertTrue(ism.verify(metadata, message));
    }

    function testDifferentAuthorizedMessageIdRejected() public view {
        bytes memory message = _message();
        bytes32[32] memory proof = _singleLeafProof();

        bytes memory metadata = abi.encode(
            uint32(0),
            proof,
            uint32(0),
            uint64(1),
            uint64(123456),
            uint256(1000),
            bytes32(uint256(0xDEAD)),
            hex"03",
            _bytes(96, 0x77)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testWrongWarpSenderRejected() public view {
        bytes memory message = abi.encodePacked(
            uint8(3),
            uint32(7),
            uint32(8453),
            bytes32(uint256(uint160(address(0x9999)))),
            uint32(1643),
            bytes32(uint256(uint160(DEST_ROUTER))),
            bytes("iln")
        );

        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            uint64(123456),
            uint256(1000),
            keccak256(message),
            hex"03",
            _bytes(96, 0x77)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function _message() internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(3),
            uint32(7),
            uint32(8453),
            bytes32(uint256(uint160(SOURCE_ROUTER))),
            uint32(1643),
            bytes32(uint256(uint160(DEST_ROUTER))),
            bytes("iln")
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
