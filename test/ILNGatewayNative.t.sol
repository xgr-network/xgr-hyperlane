// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ILNRouteRegistry} from "../contracts/ILNRouteRegistry.sol";
import {ILNGateway} from "../contracts/ILNGateway.sol";
import {XGRInterchainValidatorRegistryV2} from "../contracts/XGRInterchainValidatorRegistryV2.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";
import {MockILNNativeWarpRouter} from "../contracts/test/MockILNNativeWarpRouter.sol";

contract ILNGatewayNativeTest is Test {
    address internal constant MAILBOX =
        0x3333333333333333333333333333333333333333;
    address internal constant HOOK =
        0x4444444444444444444444444444444444444444;
    address internal constant DEST_ROUTER =
        0x5555555555555555555555555555555555555555;
    address internal constant USER = address(0xBEEF);

    function testNativeGatewayForwardsPrincipalAndKeepsValidatorFee() public {
        vm.deal(address(this), 1 ether);
        vm.deal(USER, 10 ether);

        MockXGRInterchainBLSVerifier verifier =
            new MockXGRInterchainBLSVerifier();

        (
            address[] memory validators,
            bytes[] memory compressed,
            bytes[] memory eip,
            bytes[] memory proofs
        ) = _bootstrap();

        XGRInterchainValidatorRegistryV2 validatorSet =
            new XGRInterchainValidatorRegistryV2{value: 3}(
                1643,
                8453,
                address(verifier),
                2,
                1,
                1,
                validators,
                compressed,
                eip,
                proofs
            );

        ILNRouteRegistry routeRegistry =
            new ILNRouteRegistry(1643, address(validatorSet));
        MockILNNativeWarpRouter router =
            new MockILNNativeWarpRouter();

        ILNGateway gateway = new ILNGateway(
            address(routeRegistry),
            address(router),
            MAILBOX,
            HOOK,
            address(validatorSet),
            false
        );

        ILNRouteRegistry.Proposal memory proposal =
            ILNRouteRegistry.Proposal({
                proposalType: routeRegistry.ROUTE_ADD(),
                destinationDomain: 8453,
                setId: 1,
                nonce: 1,
                validUntil: uint64(block.timestamp + 5 minutes),
                gateway: address(gateway),
                sourceRouter: address(router),
                mailbox: MAILBOX,
                merkleTreeHook: HOOK,
                destinationRouter: DEST_ROUTER,
                validatorFeeWei: 1000
            });

        routeRegistry.execute(
            proposal,
            hex"03",
            _bytes(256, 0x66)
        );

        uint256 amount = 1 ether;
        bytes32 recipient =
            bytes32(uint256(uint160(address(0xCAFE))));

        (
            uint256 validatorFee,
            uint256 routerNativeValue,
            uint256 total
        ) = gateway.quoteILN(8453, recipient, amount);

        assertEq(validatorFee, 1000);
        assertEq(routerNativeValue, amount + 0.01 ether);
        assertEq(total, amount + 0.01 ether + 1000);

        vm.prank(USER);
        bytes32 messageId = gateway.bridge{value: total}(
            8453,
            recipient,
            amount
        );

        assertTrue(messageId != bytes32(0));
        assertEq(router.lockedWei(), amount);
        assertEq(address(gateway).balance, validatorFee);
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
