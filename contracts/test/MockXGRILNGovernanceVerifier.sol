// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IXGRILNGovernanceVerifier} from "../IXGRILNGovernanceVerifier.sol";

contract MockXGRILNGovernanceVerifier is IXGRILNGovernanceVerifier {
    bool public result = true;
    bytes public lastPayload;
    uint32 public lastDestinationDomain;
    uint64 public lastSetId;

    function setResult(bool value) external {
        result = value;
    }

    function verifyGovernanceQuorum(
        uint32 destinationDomain,
        uint64 setId,
        bytes calldata payload,
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external view returns (bool) {
        destinationDomain;
        setId;
        payload;
        return result;
    }
}
