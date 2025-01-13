// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWeightProvider {
    function TYPE() external view returns (uint64);

    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory rawData
    ) external view returns (uint256[] memory weights, uint256 totalWeight);
}

library IWeightProviderLib {
    function toAddr(bytes32 self) internal pure returns (address) {
        return address(uint160(uint256(self)));
    }
}
