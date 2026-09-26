// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IXGRInterchainValidatorSetV2 {
    function originChainId() external view returns (uint64);
    function destinationDomain() external view returns (uint32);
    function verifier() external view returns (address);
    function verifierKeyFormat() external view returns (uint8);

    function getValidatorStatus(address validator)
        external
        view
        returns (bool active, uint64 setId);

    function getValidatorSet()
        external
        view
        returns (address[] memory validators, bytes[] memory blsPublicKeys, uint64 setId);

    function getValidatorSetForVerification()
        external
        view
        returns (address[] memory validators, bytes[] memory verificationKeys, uint64 setId);

    function quorumThreshold() external view returns (uint256);
    function validatorSetCommitment(uint64 setId) external view returns (bytes32);
}
