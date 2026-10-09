// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRInterchainValidatorRegistry} from "../contracts/XGRInterchainValidatorRegistry.sol";
import {XGRILNInterchainISM} from "../contracts/XGRILNInterchainISM.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRILNInterchainISMTest is Test {
    XGRILNInterchainISM internal ism;

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
            proofs[i] = _bytes(256, uint8(i + 21));
        }

        XGRInterchainValidatorRegistry registry =
            new XGRInterchainValidatorRegistry{value: 3 ether}(
                1643,
                8453,
                address(verifier),
                1 ether,
                0.1 ether,
                validators,
                compressed,
                eip,
                proofs
            );

        ism = new XGRILNInterchainISM(
            address(registry),
            1643,
            1643,
            SOURCE_GATEWAY,
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

        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            uint64(123456),
            uint256(1),
            messageId,
            hex"03",
            _bytes(256, 0x77)
        );

        assertTrue(ism.verify(metadata, message));
    }

    function testDifferentAuthorizedMessageRejected() public view {
        bytes memory message = _message();

        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            uint64(123456),
            uint256(1),
            bytes32(uint256(0xDEAD)),
            hex"03",
            _bytes(256, 0x77)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function testOneOfThreeRejected() public view {
        bytes memory message = _message();

        bytes memory metadata = abi.encode(
            uint32(0),
            _singleLeafProof(),
            uint32(0),
            uint64(1),
            uint64(123456),
            uint256(1),
            keccak256(message),
            hex"01",
            _bytes(256, 0x77)
        );

        assertFalse(ism.verify(metadata, message));
    }

    function _message() internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(3),
            uint32(7),
            uint32(1643),
            bytes32(uint256(uint160(SOURCE_ROUTER))),
            uint32(8453),
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
            zero = keccak256(
                abi.encodePacked(zero, zero)
            );
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
