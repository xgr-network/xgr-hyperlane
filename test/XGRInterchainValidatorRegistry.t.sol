// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XGRInterchainValidatorRegistry} from "../contracts/XGRInterchainValidatorRegistry.sol";
import {MockXGRInterchainBLSVerifier} from "../contracts/test/MockXGRInterchainBLSVerifier.sol";

contract XGRInterchainValidatorRegistryTest is Test {
    MockXGRInterchainBLSVerifier internal verifier;
    XGRInterchainValidatorRegistry internal registry;

    address internal constant A = address(0xA1);
    address internal constant B = address(0xB2);
    address internal constant C = address(0xC3);
    address internal constant D = address(0xD4);

    bytes internal constant BLS_A = hex"01";
    bytes internal constant BLS_B = hex"02";
    bytes internal constant BLS_C = hex"03";
    bytes internal constant BLS_D = hex"04";

    uint256 internal constant MIN_RESERVE = 1 ether;
    uint256 internal constant MAX_REIMBURSEMENT = 0.1 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);
        verifier = new MockXGRInterchainBLSVerifier();

        address[] memory validators = new address[](3);
        validators[0] = A;
        validators[1] = B;
        validators[2] = C;

        bytes[] memory keys = new bytes[](3);
        keys[0] = BLS_A;
        keys[1] = BLS_B;
        keys[2] = BLS_C;

        registry = new XGRInterchainValidatorRegistry{value: 3 * MIN_RESERVE}(
            1643,
            8453,
            address(verifier),
            MIN_RESERVE,
            MAX_REIMBURSEMENT,
            validators,
            keys
        );
    }

    function testBootstrapState() public view {
        (address[] memory validators, bytes[] memory keys, uint64 setId) = registry.getValidatorSet();
        assertEq(validators.length, 3);
        assertEq(keys.length, 3);
        assertEq(setId, 1);
        assertEq(registry.quorumThreshold(), 2);

        (bool active,, uint256 reserve) = registry.getValidator(A);
        assertTrue(active);
        assertEq(reserve, MIN_RESERVE);
    }

    function testAddRequiresQuorumAndLocksReserve() public {
        registry.applyMembership{value: MIN_RESERVE}(
            1,
            1,
            D,
            BLS_D,
            hex"03",
            hex"1234"
        );

        (bool active, bytes memory key, uint256 reserve) = registry.getValidator(D);
        assertTrue(active);
        assertEq(key, BLS_D);
        assertEq(reserve, MIN_RESERVE);
        (, uint64 setId) = registry.getValidatorStatus(D);
        assertEq(setId, 2);
    }

    function testOneOfThreeCannotAdd() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            1,
            1,
            D,
            BLS_D,
            hex"01",
            hex"1234"
        );
    }

    function testBitmapOutsideCurrentSetCannotIncreaseQuorum() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            1,
            1,
            D,
            BLS_D,
            hex"83",
            hex"1234"
        );
    }

    function testVerifierFailureRejectsTransition() public {
        verifier.setResult(false);
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            1,
            1,
            D,
            BLS_D,
            hex"03",
            hex"1234"
        );
    }

    function testAddRejectsReserveBelowFloor() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                XGRInterchainValidatorRegistry.InsufficientReserve.selector,
                MIN_RESERVE,
                MIN_RESERVE - 1
            )
        );
        registry.applyMembership{value: MIN_RESERVE - 1}(
            1,
            1,
            D,
            BLS_D,
            hex"03",
            hex"1234"
        );
    }

    function testRemoveCreditsExecutorAndValidatorWithoutExternalCalls() public {
        uint256 beforeBalance = address(registry).balance;

        registry.applyMembership(
            1,
            2,
            A,
            BLS_A,
            hex"03",
            hex"1234"
        );

        (bool active,, uint256 reserve) = registry.getValidator(A);
        assertFalse(active);
        assertEq(reserve, 0);
        assertEq(registry.claimableWei(address(this)), MAX_REIMBURSEMENT);
        assertEq(registry.claimableWei(A), MIN_RESERVE - MAX_REIMBURSEMENT);
        assertEq(address(registry).balance, beforeBalance);

        (, uint64 setId) = registry.getValidatorStatus(A);
        assertEq(setId, 2);
    }

    function testExecutorCanClaimReimbursementAfterRemoval() public {
        registry.applyMembership(
            1,
            2,
            A,
            BLS_A,
            hex"03",
            hex"1234"
        );

        uint256 before = address(this).balance;
        registry.claim();
        assertEq(address(this).balance, before + MAX_REIMBURSEMENT);
        assertEq(registry.claimableWei(address(this)), 0);
    }

    function testStaleSetIdCannotReplay() public {
        registry.applyMembership(
            1,
            2,
            A,
            BLS_A,
            hex"03",
            hex"1234"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                XGRInterchainValidatorRegistry.StaleSetId.selector,
                uint64(2),
                uint64(1)
            )
        );
        registry.applyMembership{value: MIN_RESERVE}(
            1,
            1,
            D,
            BLS_D,
            hex"03",
            hex"1234"
        );
    }

    function testConstructorRejectsReserveFloorBelowReimbursementCap() public {
        address[] memory validators = new address[](1);
        validators[0] = A;
        bytes[] memory keys = new bytes[](1);
        keys[0] = BLS_A;

        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidBootstrap.selector);
        new XGRInterchainValidatorRegistry{value: MIN_RESERVE}(
            1643,
            8453,
            address(verifier),
            0.01 ether,
            0.1 ether,
            validators,
            keys
        );
    }

    receive() external payable {}
}
