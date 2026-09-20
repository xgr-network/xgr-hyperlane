// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXGRInterchainBLSVerifier {
    function verify(
        bytes calldata message,
        bytes[] calldata publicKeys,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature
    ) external view returns (bool);
}

/// @notice Destination-side trust anchor for XGR native interchain membership.
/// @dev No administrator can mutate membership after bootstrap. Every ADD/REMOVE
///      transition requires the current validator-set BLS quorum.
contract XGRInterchainValidatorRegistry {
    uint8 private constant ACTION_ADD = 1;
    uint8 private constant ACTION_REMOVE = 2;

    bytes private constant DOMAIN_V1 = "XGR_INTERCHAIN_V1";

    struct Validator {
        bool active;
        bytes blsPublicKey;
        uint256 deactivationReserveWei;
    }

    uint64 public immutable originChainId;
    uint32 public immutable destinationDomain;
    uint256 public immutable minimumDeactivationReserveWei;
    uint256 public immutable maxExecutorReimbursementWei;
    IXGRInterchainBLSVerifier public immutable verifier;

    uint64 public setId;

    mapping(address => Validator) private validatorInfo;
    address[] private activeValidators;
    mapping(address => uint256) private activeIndexPlusOne;

    error InvalidBootstrap();
    error InvalidTransition();
    error StaleSetId(uint64 expected, uint64 got);
    error InsufficientQuorum();
    error InsufficientReserve(uint256 required, uint256 supplied);
    error TransferFailed();

    event ValidatorAdded(address indexed validator, uint64 indexed setId, uint256 reserveWei);
    event ValidatorRemoved(address indexed validator, uint64 indexed setId, address indexed executor, uint256 reimbursementWei);
    event ReserveIncreased(address indexed validator, uint256 amountWei, uint256 newReserveWei);

    constructor(
        uint64 originChainId_,
        uint32 destinationDomain_,
        address verifier_,
        uint256 minimumDeactivationReserveWei_,
        uint256 maxExecutorReimbursementWei_,
        address[] memory initialValidators_,
        bytes[] memory initialBLSPublicKeys_
    ) payable {
        if (
            originChainId_ == 0 ||
            destinationDomain_ == 0 ||
            verifier_ == address(0) ||
            initialValidators_.length == 0 ||
            initialValidators_.length != initialBLSPublicKeys_.length
        ) revert InvalidBootstrap();

        originChainId = originChainId_;
        destinationDomain = destinationDomain_;
        verifier = IXGRInterchainBLSVerifier(verifier_);
        minimumDeactivationReserveWei = minimumDeactivationReserveWei_;
        maxExecutorReimbursementWei = maxExecutorReimbursementWei_;

        uint256 reservePerValidator = msg.value / initialValidators_.length;
        if (reservePerValidator < minimumDeactivationReserveWei_) revert InvalidBootstrap();
        if (reservePerValidator * initialValidators_.length != msg.value) revert InvalidBootstrap();

        for (uint256 i = 0; i < initialValidators_.length; i++) {
            address validator = initialValidators_[i];
            bytes memory blsKey = initialBLSPublicKeys_[i];
            if (validator == address(0) || blsKey.length == 0 || activeIndexPlusOne[validator] != 0) {
                revert InvalidBootstrap();
            }
            validatorInfo[validator] = Validator({
                active: true,
                blsPublicKey: blsKey,
                deactivationReserveWei: reservePerValidator
            });
            activeValidators.push(validator);
            activeIndexPlusOne[validator] = activeValidators.length;
        }

        setId = 1;
    }

    receive() external payable {
        Validator storage v = validatorInfo[msg.sender];
        if (!v.active) revert InvalidTransition();
        v.deactivationReserveWei += msg.value;
        emit ReserveIncreased(msg.sender, msg.value, v.deactivationReserveWei);
    }

    function getValidatorStatus(address validator) external view returns (bool active, uint64 currentSetId) {
        return (validatorInfo[validator].active, setId);
    }

    function getValidator(address validator)
        external
        view
        returns (bool active, bytes memory blsPublicKey, uint256 reserveWei)
    {
        Validator storage v = validatorInfo[validator];
        return (v.active, v.blsPublicKey, v.deactivationReserveWei);
    }

    function getValidatorSet()
        external
        view
        returns (address[] memory validators, bytes[] memory blsPublicKeys, uint64 currentSetId)
    {
        validators = activeValidators;
        blsPublicKeys = new bytes[](validators.length);
        for (uint256 i = 0; i < validators.length; i++) {
            blsPublicKeys[i] = validatorInfo[validators[i]].blsPublicKey;
        }
        return (validators, blsPublicKeys, setId);
    }

    function quorumThreshold() public view returns (uint256) {
        uint256 n = activeValidators.length;
        return (2 * n + 2) / 3;
    }

    /// @notice Executes a quorum-approved membership transition.
    /// @dev For ADD, msg.value becomes the validator's locked deactivation reserve.
    ///      For REMOVE, msg.value must be zero and the existing reserve finances the
    ///      successful executor; any remainder is returned to the validator.
    function applyMembership(
        uint64 expectedSetId,
        uint8 action,
        address validator,
        bytes calldata validatorBLSPublicKey,
        bytes calldata signerBitmap,
        bytes calldata aggregateSignature
    ) external payable {
        if (expectedSetId != setId) revert StaleSetId(setId, expectedSetId);
        if (validator == address(0) || validatorBLSPublicKey.length == 0) revert InvalidTransition();

        bytes memory message = encodeMembershipPayload(
            originChainId,
            destinationDomain,
            expectedSetId,
            action,
            validator,
            validatorBLSPublicKey
        );

        bytes[] memory currentKeys = new bytes[](activeValidators.length);
        for (uint256 i = 0; i < activeValidators.length; i++) {
            currentKeys[i] = validatorInfo[activeValidators[i]].blsPublicKey;
        }

        if (!_bitmapHasQuorum(signerBitmap, activeValidators.length, quorumThreshold())) {
            revert InsufficientQuorum();
        }
        if (!verifier.verify(message, currentKeys, signerBitmap, aggregateSignature)) {
            revert InsufficientQuorum();
        }

        if (action == ACTION_ADD) {
            _applyAdd(validator, validatorBLSPublicKey);
        } else if (action == ACTION_REMOVE) {
            _applyRemove(validator, validatorBLSPublicKey);
        } else {
            revert InvalidTransition();
        }

        unchecked {
            setId += 1;
        }
    }

    function encodeMembershipPayload(
        uint64 originChainId_,
        uint32 destinationDomain_,
        uint64 expectedSetId,
        uint8 action,
        address validator,
        bytes memory validatorBLSPublicKey
    ) public pure returns (bytes memory) {
        if (
            originChainId_ == 0 ||
            destinationDomain_ == 0 ||
            (action != ACTION_ADD && action != ACTION_REMOVE) ||
            validator == address(0) ||
            validatorBLSPublicKey.length == 0 ||
            validatorBLSPublicKey.length > type(uint16).max
        ) revert InvalidTransition();

        return abi.encodePacked(
            DOMAIN_V1,
            bytes8(originChainId_),
            bytes4(destinationDomain_),
            bytes8(expectedSetId),
            bytes1(action),
            bytes20(validator),
            bytes2(uint16(validatorBLSPublicKey.length)),
            validatorBLSPublicKey
        );
    }

    function _applyAdd(address validator, bytes calldata validatorBLSPublicKey) internal {
        if (validatorInfo[validator].active || activeIndexPlusOne[validator] != 0) revert InvalidTransition();
        if (msg.value < minimumDeactivationReserveWei) {
            revert InsufficientReserve(minimumDeactivationReserveWei, msg.value);
        }

        validatorInfo[validator] = Validator({
            active: true,
            blsPublicKey: validatorBLSPublicKey,
            deactivationReserveWei: msg.value
        });
        activeValidators.push(validator);
        activeIndexPlusOne[validator] = activeValidators.length;

        emit ValidatorAdded(validator, setId + 1, msg.value);
    }

    function _applyRemove(address validator, bytes calldata validatorBLSPublicKey) internal {
        if (msg.value != 0) revert InvalidTransition();

        Validator storage v = validatorInfo[validator];
        if (!v.active || keccak256(v.blsPublicKey) != keccak256(validatorBLSPublicKey)) {
            revert InvalidTransition();
        }

        uint256 indexPlusOne = activeIndexPlusOne[validator];
        if (indexPlusOne == 0) revert InvalidTransition();

        uint256 last = activeValidators.length;
        uint256 index = indexPlusOne - 1;
        if (index + 1 != last) {
            address moved = activeValidators[last - 1];
            activeValidators[index] = moved;
            activeIndexPlusOne[moved] = index + 1;
        }
        activeValidators.pop();
        delete activeIndexPlusOne[validator];

        uint256 reserve = v.deactivationReserveWei;
        v.active = false;
        v.deactivationReserveWei = 0;

        uint256 reimbursement = reserve;
        if (reimbursement > maxExecutorReimbursementWei) {
            reimbursement = maxExecutorReimbursementWei;
        }
        uint256 remainder = reserve - reimbursement;

        if (reimbursement != 0) {
            (bool okExecutor,) = payable(msg.sender).call{value: reimbursement}("");
            if (!okExecutor) revert TransferFailed();
        }
        if (remainder != 0) {
            (bool okValidator,) = payable(validator).call{value: remainder}("");
            if (!okValidator) revert TransferFailed();
        }

        emit ValidatorRemoved(validator, setId + 1, msg.sender, reimbursement);
    }

    function _bitmapHasQuorum(bytes calldata bitmap, uint256 validatorCount, uint256 threshold)
        internal
        pure
        returns (bool)
    {
        if (validatorCount == 0 || threshold == 0) return false;
        uint256 count;
        for (uint256 i = 0; i < validatorCount; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (uint8(bitmap[bitmap.length - 1 - byteFromEnd]) & uint8(1 << bitIndex)) != 0
            ) {
                count++;
            }
        }

        // Reject any set bit outside the current set.
        for (uint256 i = validatorCount; i < bitmap.length * 8; i++) {
            uint256 byteFromEnd = i >> 3;
            uint256 bitIndex = i & 7;
            if (
                byteFromEnd < bitmap.length &&
                (uint8(bitmap[bitmap.length - 1 - byteFromEnd]) & uint8(1 << bitIndex)) != 0
            ) return false;
        }

        return count >= threshold;
    }
}