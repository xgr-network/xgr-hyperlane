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

    bytes internal BLS_A;
    bytes internal BLS_B;
    bytes internal BLS_C;
    bytes internal BLS_D;
    bytes internal EIP_A;
    bytes internal EIP_B;
    bytes internal EIP_C;
    bytes internal EIP_D;
    uint64 internal deadline;

    uint256 internal constant MIN_RESERVE = 1 ether;
    uint256 internal constant MAX_REIMBURSEMENT = 0.1 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);
        verifier = new MockXGRInterchainBLSVerifier();
        BLS_A = _key(0xA1);
        BLS_B = _key(0xB2);
        BLS_C = _key(0xC3);
        BLS_D = _key(0xD4);
        EIP_A = _eipKey(0xA1);
        EIP_B = _eipKey(0xB2);
        EIP_C = _eipKey(0xC3);
        EIP_D = _eipKey(0xD4);
        deadline = uint64(block.timestamp + 1 hours);
        vm.txGasPrice(1 gwei);

        address[] memory validators = new address[](3);
        validators[0] = A;
        validators[1] = B;
        validators[2] = C;

        bytes[] memory keys = new bytes[](3);
        keys[0] = BLS_A;
        keys[1] = BLS_B;
        keys[2] = BLS_C;

        bytes[] memory eipKeys = new bytes[](3);
        eipKeys[0] = EIP_A;
        eipKeys[1] = EIP_B;
        eipKeys[2] = EIP_C;

        bytes[] memory proofs = new bytes[](3);
        proofs[0] = hex"01";
        proofs[1] = hex"02";
        proofs[2] = hex"03";

        registry = new XGRInterchainValidatorRegistry{value: 3 * MIN_RESERVE}(
            1643,
            8453,
            address(verifier),
            MIN_RESERVE,
            MAX_REIMBURSEMENT,
            validators,
            keys,
            eipKeys,
            proofs
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
            _transition(1, D, BLS_D, EIP_D),
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
            _transition(1, D, BLS_D, EIP_D),
            hex"01",
            hex"1234"
        );
    }

    function testBitmapOutsideCurrentSetCannotIncreaseQuorum() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"83",
            hex"1234"
        );
    }

    function testVerifierFailureRejectsTransition() public {
        verifier.setResult(false);
        vm.expectRevert(XGRInterchainValidatorRegistry.InsufficientQuorum.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
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
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function testRemoveCreditsExecutorAndValidatorWithoutExternalCalls() public {
        uint256 beforeBalance = address(registry).balance;

        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );

        (bool active,, uint256 reserve) = registry.getValidator(A);
        assertFalse(active);
        assertEq(reserve, 0);
        uint256 reimbursement = registry.claimableWei(address(this));
        assertGt(reimbursement, 0);
        assertLe(reimbursement, MAX_REIMBURSEMENT);
        assertEq(registry.claimableWei(A), MIN_RESERVE - reimbursement);
        assertEq(address(registry).balance, beforeBalance);

        (, uint64 setId) = registry.getValidatorStatus(A);
        assertEq(setId, 2);
    }

    function testExecutorCanClaimReimbursementAfterRemoval() public {
        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );

        uint256 reimbursement = registry.claimableWei(address(this));
        uint256 before = address(this).balance;
        registry.claim();
        assertEq(address(this).balance, before + reimbursement);
        assertEq(registry.claimableWei(address(this)), 0);
    }

    function testStaleSetIdCannotReplay() public {
        registry.applyMembership(
            _transition(2, A, BLS_A, EIP_A),
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
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function testConstructorRejectsReserveFloorBelowReimbursementCap() public {
        address[] memory validators = new address[](1);
        validators[0] = A;
        bytes[] memory keys = new bytes[](1);
        keys[0] = BLS_A;
        bytes[] memory eipKeys = new bytes[](1);
        eipKeys[0] = EIP_A;
        bytes[] memory proofs = new bytes[](1);
        proofs[0] = hex"01";

        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidBootstrap.selector);
        new XGRInterchainValidatorRegistry{value: MIN_RESERVE}(
            1643,
            8453,
            address(verifier),
            0.01 ether,
            0.1 ether,
            validators,
            keys,
            eipKeys,
            proofs
        );
    }

    function testAddRejectsDuplicateBLSKey() public {
        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidTransition.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_A, EIP_A),
            hex"03",
            hex"1234"
        );
    }

    function testExpiredProofCannotExecute() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(XGRInterchainValidatorRegistry.InvalidTransition.selector);
        registry.applyMembership{value: MIN_RESERVE}(
            _transition(1, D, BLS_D, EIP_D),
            hex"03",
            hex"1234"
        );
    }

    function _transition(
        uint8 action,
        address validator,
        bytes memory blsKey,
        bytes memory eipKey
    ) internal view returns (XGRInterchainValidatorRegistry.MembershipTransition memory) {
        return XGRInterchainValidatorRegistry.MembershipTransition({
            expectedSetId: 1,
            validUntil: deadline,
            action: action,
            validator: validator,
            blsPublicKey: blsKey,
            blsPublicKeyEIP2537: eipKey
        });
    }

    function _key(uint8 seed) internal pure returns (bytes memory out) {
        out = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            out[i] = bytes1(seed);
        }
    }

    function _eipKey(uint8 seed) internal pure returns (bytes memory out) {
        out = new bytes(128);
        for (uint256 i = 0; i < 128; i++) {
            out[i] = bytes1(seed);
        }
    }

    receive() external payable {}
}
