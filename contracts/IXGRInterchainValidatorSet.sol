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
}
