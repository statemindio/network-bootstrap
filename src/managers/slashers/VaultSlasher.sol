// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {BaseSlasher} from "./BaseSlasher.sol";
import {SlashSubnetworkWeightProviderStorage} from "../storages/SlashWeightProviderStorage.sol";
import {IWeightProvider} from "../../interfaces/weights/IWeightProvider.sol";
import {WPDataComposer} from "../../libs/WPDataComposer.sol";
import {MathConvert} from "../../libs/MathConvert.sol";

abstract contract VaultSlasher is BaseSlasher, SlashSubnetworkWeightProviderStorage {
    using Subnetwork for address;

    error InvalidSubnetworkWeightsLength();
    error NoSubnetworksToSlash();

    struct SlashParams {
        uint48 timestamp;
        bytes key;
        uint256 amount;
        address vault;
        bytes[] slashHints;
        bytes wpDataParams;
    }

    /*
     * @notice Slashes a validator in the provided subnetwork
     * @param timestamp The timestamp for which the slashing occurs.
     * @param key The key of the operator to slash.
     * @param amount The amount to slash.
     * @param vault The address of the vault.
     * @param slashHints Hints for the slashing process.
     * @param wpDataParams Params data for weight provider
     * @return A struct SlashResponse containing information about the slash response.
     */
    function slash(SlashParams calldata params) public checkAccess {
        address operator = getOperatorAndCheckCanSlash(params.key, params.timestamp);

        if (!_vaultWasActiveAt(params.timestamp, operator, params.vault)) {
            revert InactiveVaultSlash();
        }

        bytes32[] memory _subnetworks;
        {
            uint160[] memory subnetworks_ = _activeSubnetworksAt(params.timestamp);
            _subnetworks = MathConvert.convertSubnetworksArrayToBytes32Array(_NETWORK(), subnetworks_);
        }
        if (_subnetworks.length == 0) {
            revert NoSubnetworksToSlash();
        }

        uint256[] memory weights;
        uint256 totalWeight;
        {
            address[] memory vaults = new address[](1);
            vaults[0] = params.vault;
            bytes memory wpData = WPDataComposer.composeWPData(
                _slashSubnetworkWeightProvider(), params.timestamp, operator, vaults, _subnetworks, params.wpDataParams
            );
            (weights, totalWeight) =
                IWeightProvider(_slashSubnetworkWeightProvider()).getWeightsAndTotal(_subnetworks, wpData);
        }

        if (weights.length != _subnetworks.length) {
            revert InvalidSubnetworkWeightsLength();
        }

        uint256 usedAmount;
        uint256 lastIndex = _subnetworks.length - 1;
        for (uint256 i; i < _subnetworks.length; ++i) {
            uint256 subnetworkAmount = Math.mulDiv(params.amount, weights[i], totalWeight);
            if (i == lastIndex) {
                subnetworkAmount = params.amount - usedAmount;
            }
            usedAmount += subnetworkAmount;

            _slashVault(
                params.timestamp, params.vault, _subnetworks[i], operator, subnetworkAmount, params.slashHints[i]
            );
        }
    }
}
