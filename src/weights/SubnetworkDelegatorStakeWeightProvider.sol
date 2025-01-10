// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {IBaseDelegator} from "@symbioticfi/core/src/interfaces/delegator/IBaseDelegator.sol";
import {IPriceProvider} from "../interfaces/prices/IPriceProvider.sol";
import {IWeightProvider, IWeightProviderLib} from "../interfaces/weights/IWeightProvider.sol";

contract SubnetworkDelegatorStakeWeightProvider is IWeightProvider {
    error InvalidVaultCollateral();
    error InvalidTimestamp();
    error EmptyEntities();
    error DifferentVaultCollateral();
    error InvalidData();

    struct SubnetworkDelegatorStakeWPData {
        address operator;
        uint48 timestamp;
        address vault;
        bytes[] stakeHints;
    }

    uint64 public constant TYPE = 5;

    // The contract supports correct functioning only when entities are subnetwork identifiers.
    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory rawData
    ) public view override returns (uint256[] memory weights, uint256 totalWeight) {
        SubnetworkDelegatorStakeWPData memory data = abi.decode(rawData, (SubnetworkDelegatorStakeWPData));
        weights = new uint256[](entities.length);
        if (data.timestamp == 0) {
            revert InvalidTimestamp();
        }
        if (entities.length == 0) {
            revert EmptyEntities();
        }
        if (data.stakeHints.length != entities.length) {
            revert InvalidData();
        }
        for (uint256 i; i < entities.length; ++i) {
            uint256 stake = IBaseDelegator(IVault(data.vault).delegator()).stakeAt(
                entities[i], data.operator, data.timestamp, data.stakeHints[i]
            );
            weights[i] = stake;
            totalWeight += stake;
        }
    }
}
