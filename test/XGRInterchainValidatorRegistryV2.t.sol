// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRInterchainValidatorRegistryV2Test is Test {
    MockXGRInterchainBLSVerifier internal verifier;

    address internal constant A = address(0xA1);
    address internal constant B = address(0xB2);
    address internal constant C = address(0xC3);
    address internal constant D = address(0xD4);

    function testCompressedVerifierUsesCompressedKeys() public {
        verifier = new MockXGRInterchainBLSVerifier();
        XGRInterchainValidatorRegistryV2 registry = _deploy(
            XGRInterchainValidatorRegistryV2.VERIFIER_FORMAT_COMPRESSED()
        );

        (address[] memory validators, bytes[] memory keys, uint64 setId) =
            registry.getValidatorSetForVerification();

        assertEq(validators.length, 3);
        assertEq(keys.length, 3);
        assertEq(keys[0].length, 48);
        assertEq(setId, 1);

        registry.applyMembership{value: 1 ether}(
            XGRInterchainValidatorRegistryV2.MembershipTransition({
                expectedSetId: 1,
                validUntil: uint64(block.timestamp + 5 minutes),
                action: 1,
                validator: D,
                blsPublicKey: _bytes(48, 0x44),
                blsPublicKeyEIP2537: _bytes(128, 0x54)
            }),
            hex"03",
            _bytes(96, 0x66)
        );

        (, uint64 newSetId) = registry.getValidatorStatus(D);
        assertEq(newSetId, 2);
    }

    function testEIP2537VerifierUsesEIP2537Keys() public {
        verifier = new MockXGRInterchainBLSVerifier();
        XGRInterchainValidatorRegistryV2 registry = _deploy(
            XGRInterchainValidatorRegistryV2.VERIFIER_FORMAT_EIP2537()
        );

        (, bytes[] memory keys,) = registry.getValidatorSetForVerification();
        assertEq(keys.length, 3);
        assertEq(keys[0].length, 128);
    }

    function testCanonicalMembershipPayloadUnchanged() public {
        verifier = new MockXGRInterchainBLSVerifier();
        XGRInterchainValidatorRegistryV2 registry = _deploy(
            XGRInterchainValidatorRegistryV2.VERIFIER_FORMAT_COMPRESSED()
        );

        bytes memory compressed = hex"a695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c68759";
        bytes memory eip = hex"000000000000000000000000000000000695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590000000000000000000000000000000010ea7912ef7a227c01298a7c7a96b1851b23021741c71938f39638b1d368aaa621452426b5d8199773a2cb5b2743a5da";
        bytes memory expected = hex"5847525f494e544552434841494e5f5632000000000000066b0000066b0000000000000007000000006553f1000111111111111111111111111111111111111111110030a695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590080000000000000000000000000000000000695ad325dfc7e1191fbc9f186f58eff42a634029731b18380ff89bf42c464a42cb8ca55b200f051f57f1e1893c687590000000000000000000000000000000010ea7912ef7a227c01298a7c7a96b1851b23021741c71938f39638b1d368aaa621452426b5d8199773a2cb5b2743a5da";

        assertEq(
            registry.encodeMembershipPayload(
                1643,
                1643,
                7,
                1700000000,
                1,
                address(0x1111111111111111111111111111111111111111),
                compressed,
                eip
            ),
            expected
        );
    }

    function testRejectsUnknownVerifierFormat() public {
        verifier = new MockXGRInterchainBLSVerifier();
        address[] memory validators = _validators();
        bytes[] memory keys = _keys(48, 1);
        bytes[] memory eipKeys = _keys(128, 11);
        bytes[] memory proofs = _keys(96, 21);

        vm.expectRevert(XGRInterchainValidatorRegistryV2.InvalidBootstrap.selector);
        new XGRInterchainValidatorRegistryV2{value: 3 ether}(
            1643,
            1643,
            address(verifier),
            9,
            1 ether,
            0.1 ether,
            validators,
            keys,
            eipKeys,
            proofs
        );
    }

    function _deploy(uint8 format)
        internal
        returns (XGRInterchainValidatorRegistryV2 registry)
    {
        vm.deal(address(this), 20 ether);
        registry = new XGRInterchainValidatorRegistryV2{value: 3 ether}(
            1643,
            1643,
            address(verifier),
            format,
            1 ether,
            0.1 ether,
            _validators(),
            _keys(48, 1),
            _keys(128, 11),
            _keys(format == 1 ? 96 : 256, 21)
        );
    }

    function _validators() internal pure returns (address[] memory validators) {
        validators = new address[](3);
        validators[0] = A;
        validators[1] = B;
        validators[2] = C;
    }

    function _keys(uint256 length, uint8 start)
        internal
        pure
        returns (bytes[] memory out)
    {
        out = new bytes[](3);
        for (uint256 i = 0; i < 3; i++) {
            out[i] = _bytes(length, start + uint8(i));
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
