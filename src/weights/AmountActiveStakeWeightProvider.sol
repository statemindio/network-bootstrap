// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {IWeightProvider, IWeightProviderLib} from "../interfaces/weights/IWeightProvider.sol";

contract AmountActiveStakeWeightProvider is IWeightProvider {
    error InvalidVaultCollateral();
    error InvalidTimestamp();
    error EmptyEntities();
    error DifferentVaultCollateral();
    error InvalidActiveStakeHints();

    uint64 public constant TYPE = 2;

    struct AmountWPData {
        uint48 timestamp;
        bytes[] activeStakeAtHints;
    }

    // The contract supports correct functioning only when entities are Vault addresses.
    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory rawData
    ) public view override returns (uint256[] memory weights, uint256 totalWeight) {
        AmountWPData memory data = abi.decode(rawData, (AmountWPData));
        if (data.timestamp == 0) {
            revert InvalidTimestamp();
        }
        if (entities.length == 0) {
            revert EmptyEntities();
        }
        if (data.activeStakeAtHints.length != entities.length) {
            revert InvalidActiveStakeHints();
        }
        weights = new uint256[](entities.length);

        address previousVaultToken;
        for (uint256 i; i < entities.length; i++) {
            address vault = IWeightProviderLib.toAddr(entities[i]);
            address collateral = IVault(vault).collateral();
            if (collateral == address(0)) {
                revert InvalidVaultCollateral();
            }
            if (previousVaultToken != address(0)) {
                if (previousVaultToken != collateral) {
                    revert DifferentVaultCollateral();
                }
            } else {
                previousVaultToken = collateral;
            }

            uint256 stakeAmount;
            if (data.timestamp == block.timestamp || data.timestamp == type(uint48).max) {
                stakeAmount = IVault(vault).activeStake();
            } else {
                stakeAmount = IVault(vault).activeStakeAt(data.timestamp, data.activeStakeAtHints[i]);
            }
            totalWeight += stakeAmount;
            weights[i] = stakeAmount;
        }
    }
}
