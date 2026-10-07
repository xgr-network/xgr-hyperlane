// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockLocalGovernanceRegistry {
    uint32 public immutable destinationDomain;
    address public immutable verifier;
    uint64 public setId = 7;
    bool public result = true;

    constructor(uint32 domain_) {
        destinationDomain = domain_;
        verifier = address(this);
    }

    function setResult(bool value) external {
        result = value;
    }

    function verifyQuorum(
        uint64 requestedSetId,
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external view returns (bool) {
        return result && requestedSetId == setId;
    }
}
