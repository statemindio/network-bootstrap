// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWeightProvider} from "./IWeightProvider.sol";

interface IConfigWeightProvider is IWeightProvider {
    struct ConfigWPData {
        uint48 timestamp;
        bytes[] weightsAtHints;
    }

    function getWeight(bytes32 entity) external view returns (uint256);

    function getWeightAt(bytes32 entity, uint48 timestamp, bytes memory hints) external view returns (uint256);

    function setWalletConfigs(bytes32[] memory entities, uint128[] memory newWeights) external;
}
