// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Checkpoints} from "@symbioticfi/core/src/contracts/libraries/Checkpoints.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IWeightProvider} from "../interfaces/weights/IWeightProvider.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VaultManager} from "@symbioticfi/middleware-sdk/managers/VaultManager.sol";

contract ConfigWeightProvider is IWeightProvider, Ownable {
    using Checkpoints for Checkpoints.Trace208;

    mapping(bytes32 entity => Checkpoints.Trace208 weight) internal weights;

    uint256 public totalWeight;

    uint64 public constant TYPE = 1;

    uint256 public constant ONE = 10 ** 18;

    error InvalidEntities();
    error InvalidTotalWeight();
    error InvalidData();

    struct ConfigWPData {
        uint48 timestamp;
        bytes[] weightsAtHints;
    }

    constructor(address owner) Ownable(owner) {}

    function getWeight(bytes32 entity) public view returns (uint256) {
        return weights[entity].latest();
    }

    function getWeightAt(bytes32 entity, uint48 timestamp, bytes memory hints) public view returns (uint256) {
        return weights[entity].upperLookupRecent(timestamp, hints);
    }

    function setWalletConfigs(bytes32[] memory entities, uint128[] memory newWeights) external onlyOwner {
        if (entities.length == 0 || entities.length != newWeights.length) {
            revert InvalidEntities();
        }

        for (uint256 i; i < entities.length; i++) {
            uint128 newWeight = newWeights[i];
            uint208 oldWeight = weights[entities[i]].latest();

            totalWeight -= oldWeight;
            totalWeight += newWeight;

            weights[entities[i]].push(Time.timestamp(), newWeight);
        }

        if (totalWeight > 0 && totalWeight != ONE) {
            revert InvalidTotalWeight();
        }
    }

    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory rawData
    ) public view override returns (uint256[] memory weights_, uint256 totalWeight_) {
        ConfigWPData memory data = abi.decode(rawData, (ConfigWPData));
        if (entities.length == 0) {
            revert InvalidEntities();
        }
        if (entities.length != data.weightsAtHints.length) {
            revert InvalidData();
        }
        weights_ = new uint256[](entities.length);

        for (uint256 i; i < entities.length; i++) {
            uint256 weight;
            if (data.timestamp == block.timestamp || data.timestamp == type(uint48).max) {
                weight = getWeight(entities[i]);
            } else {
                weight = getWeightAt(entities[i], data.timestamp, data.weightsAtHints[i]);
            }
            totalWeight_ += weight;
            weights_[i] = weight;
        }
    }
}
