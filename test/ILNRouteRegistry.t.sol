// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ILNRouteRegistry} from "../contracts/ILNRouteRegistry.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract ILNRouteRegistryTest is Test {
    ILNRouteRegistry internal registry;
    XGRInterchainValidatorRegistryV2 internal validatorSet;

    address internal constant GATEWAY =
        0x1111111111111111111111111111111111111111;
    address internal constant ROUTER =
        0x2222222222222222222222222222222222222222;
    address internal constant MAILBOX =
        0x3333333333333333333333333333333333333333;
    address internal constant HOOK =
        0x4444444444444444444444444444444444444444;
    address internal constant DEST_ROUTER =
        0x5555555555555555555555555555555555555555;

    function setUp() public {
        vm.deal(address(this), 1 ether);
        MockXGRInterchainBLSVerifier verifier =
            new MockXGRInterchainBLSVerifier();

        (
            address[] memory validators,
            bytes[] memory compressed,
            bytes[] memory eip,
            bytes[] memory proofs
        ) = _bootstrap();

        validatorSet =
            new XGRInterchainValidatorRegistryV2{value: 3}(
                1643,
                1643,
                address(verifier),
                2,
                1,
                1,
                validators,
                compressed,
                eip,
                proofs
            );

        registry = new ILNRouteRegistry(8453, address(validatorSet));
    }

    function testRouteAddMatchesNodeTuple() public {
        ILNRouteRegistry.Proposal memory proposal =
            ILNRouteRegistry.Proposal({
                proposalType: registry.ROUTE_ADD(),
                destinationDomain: 1643,
                setId: 1,
                nonce: 1,
                validUntil: uint64(block.timestamp + 5 minutes),
                gateway: GATEWAY,
                sourceRouter: ROUTER,
                mailbox: MAILBOX,
                merkleTreeHook: HOOK,
                destinationRouter: DEST_ROUTER,
                validatorFeeWei: 1000
            });

        registry.execute(
            proposal,
            hex"03",
            _bytes(256, 0x77)
        );

        (
            uint64 sourceChainId,
            uint32 sourceDomain,
            address gateway,
            address sourceRouter,
            address mailbox,
            address hook,
            address destinationRouter,
            uint256 fee,
            bool enabled
        ) = registry.getRoute(1643);

        assertEq(sourceChainId, uint64(block.chainid));
        assertEq(sourceDomain, 8453);
        assertEq(gateway, GATEWAY);
        assertEq(sourceRouter, ROUTER);
        assertEq(mailbox, MAILBOX);
        assertEq(hook, HOOK);
        assertEq(destinationRouter, DEST_ROUTER);
        assertEq(fee, 1000);
        assertTrue(enabled);
        assertEq(registry.nextNonce(), 2);
    }

    function testOneOfThreeGovernanceRejected() public {
        ILNRouteRegistry.Proposal memory proposal =
            ILNRouteRegistry.Proposal({
                proposalType: registry.ROUTE_ADD(),
                destinationDomain: 1643,
                setId: 1,
                nonce: 1,
                validUntil: uint64(block.timestamp + 5 minutes),
                gateway: GATEWAY,
                sourceRouter: ROUTER,
                mailbox: MAILBOX,
                merkleTreeHook: HOOK,
                destinationRouter: DEST_ROUTER,
                validatorFeeWei: 1000
            });

        vm.expectRevert(ILNRouteRegistry.InsufficientQuorum.selector);
        registry.execute(
            proposal,
            hex"01",
            _bytes(256, 0x77)
        );
    }

    function _bootstrap()
        internal
        pure
        returns (
            address[] memory validators,
            bytes[] memory compressed,
            bytes[] memory eip,
            bytes[] memory proofs
        )
    {
        validators = new address[](3);
        compressed = new bytes[](3);
        eip = new bytes[](3);
        proofs = new bytes[](3);

        for (uint256 i = 0; i < 3; i++) {
            validators[i] = address(uint160(0xA1 + i));
            compressed[i] = _bytes(48, uint8(i + 1));
            eip[i] = _bytes(128, uint8(i + 11));
            proofs[i] = _bytes(256, uint8(i + 21));
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
