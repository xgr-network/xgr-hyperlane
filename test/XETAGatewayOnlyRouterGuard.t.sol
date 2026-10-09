// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {IXGRILNRegistry} from "../contracts/IXGRILNRegistry.sol";
import {MockXGRILNRegistry} from "../contracts/test/MockXGRILNRegistry.sol";
import {XETAGatewayOnlyRouterGuard} from "../contracts/XETAGatewayOnlyRouterGuard.sol";

contract GuardedRouterHarness is XETAGatewayOnlyRouterGuard {
    uint256 public sends;
    bytes32 internal remote;
    constructor(address reg, bytes32 id, uint32 domain)
        XETAGatewayOnlyRouterGuard(reg,id,domain) {}
    function transferRemote(uint32 destination, bytes32, uint256)
        external onlyXETAGateway(destination) { sends++; }
    function _xetaRouterState(uint32) internal view override
        returns (uint32, address, address, bytes32) {
        return (1643, address(0x1234), address(0x1235), remote);
    }
    function _xetaEnrollRemote(uint32, bytes32 x) internal override { remote = x; }
}

contract XETAGatewayOnlyRouterGuardTest is Test {
    bytes32 constant ROUTE = bytes32(uint256(7));
    uint32 constant DEST = 8453;
    address constant GATEWAY = address(0xCAFE);
    MockXGRILNRegistry registry;
    GuardedRouterHarness router;

    function setUp() public {
        registry = new MockXGRILNRegistry();
        router = new GuardedRouterHarness(address(registry),ROUTE,DEST);
        registry.setRoute(DEST, ROUTE, IXGRILNRegistry.RouteRecord({
            sourceChainId:uint64(block.chainid),sourceDomain:1643,gateway:GATEWAY,
            sourceRouter:address(router),mailbox:address(0x1234),merkleTreeHook:address(0x1235),
            destinationRouter:address(0x1236),validatorFeeWei:17,enabled:true
        }));
    }

    function testRouterIsClosedBeforeBootstrapping() public {
        vm.prank(GATEWAY);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAInvalidRoute.selector);
        router.transferRemote(DEST, bytes32(uint256(1)), 10);
    }

    function testDirectRouterTransferRejected() public {
        router.bootstrapXETARemoteRouter();
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAUnauthorizedGateway.selector);
        router.transferRemote(DEST, bytes32(uint256(1)), 10);
    }

    function testCanonicalGatewayAccepted() public {
        router.bootstrapXETARemoteRouter();
        vm.prank(GATEWAY);
        router.transferRemote(DEST, bytes32(uint256(1)), 10);
        assertEq(router.sends(),1);
    }

    function testCannotBootstrapTwice() public {
        router.bootstrapXETARemoteRouter();
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAAlreadyInitialized.selector);
        router.bootstrapXETARemoteRouter();
    }

    function testWrongDestinationRejected() public {
        router.bootstrapXETARemoteRouter();
        vm.prank(GATEWAY);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAInvalidRoute.selector);
        router.transferRemote(137,bytes32(uint256(1)),10);
    }

    function testDisabledRouteRejectsGateway() public {
        router.bootstrapXETARemoteRouter();
        registry.setRoute(DEST, ROUTE, IXGRILNRegistry.RouteRecord({
            sourceChainId:uint64(block.chainid),sourceDomain:1643,gateway:GATEWAY,
            sourceRouter:address(router),mailbox:address(0x1234),merkleTreeHook:address(0x1235),
            destinationRouter:address(0x1236),validatorFeeWei:17,enabled:false
        }));
        vm.prank(GATEWAY);
        vm.expectRevert(XETAGatewayOnlyRouterGuard.XETAInvalidRoute.selector);
        router.transferRemote(DEST,bytes32(uint256(1)),10);
    }
}
