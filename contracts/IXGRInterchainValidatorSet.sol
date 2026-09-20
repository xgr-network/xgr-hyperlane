// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXGRInterchainValidatorSet {
    function getValidatorStatus(address validator)
        external
        view
        returns (bool active, uint64 setId);

    function getValidatorSet()
        external
        view
        returns (address[] memory validators, bytes[] memory blsPublicKeys, uint64 setId);

    function getValidatorSetEIP2537()
        external
        view
        returns (address[] memory validators, bytes[] memory blsPublicKeysEIP2537, uint64 setId);

    function validatorSetCommitment(uint64 setId) external view returns (bytes32);
}
