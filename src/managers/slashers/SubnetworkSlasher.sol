// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {BaseSlasher} from "./BaseSlasher.sol";
import {SlashVaultWeightProviderStorage} from "../storages/SlashWeightProviderStorage.sol";
import {PriceProviderStorage} from "../storages/PriceProviderStorage.sol";
import {IWeightProvider} from "../../interfaces/weights/IWeightProvider.sol";
import {WPDataComposer} from "../../libs/WPDataComposer.sol";
import {MathConvert} from "../../libs/MathConvert.sol";

abstract contract SubnetworkSlasher is BaseSlasher, SlashVaultWeightProviderStorage, PriceProviderStorage {
    using Subnetwork for bytes32;

    error InvalidVaultWeightsLength();
    error VaultsHaveDifferentCollateral();
    error NoVaultsToSlash();
    error InactiveSubnetworkSlash();

    struct SlashParams {
        uint48 timestamp;
        bytes key;
        uint256 amount;
        bytes32 subnetwork;
        bytes[] slashHints;
        bytes wpDataParams;
        bytes[] priceProviderData;
    }

    /*
     * @notice Slashes a validator in the provided vault
     * @param timestamp The timestamp for which the slashing occurs.
     * @param key The key of the operator to slash.
     * @param amount The amount to slash.
     * @param subnetwork The subnetwork identifier.
     * @param slashHints Hints for the slashing process.
     * @param wpDataParams Params data for weight provider
     * @param priceProviderData data for price provider
     * @return A struct SlashResponse containing information about the slash response.
     */
    function slash(
        SlashParams memory params
    ) public checkAccess {
        address operator = getOperatorAndCheckCanSlash(params.key, params.timestamp);

        if (!_subnetworkWasActiveAt(params.timestamp, params.subnetwork.identifier())) {
            revert InactiveSubnetworkSlash();
        }

        address[] memory vaults = _activeVaultsAt(params.timestamp, operator);
        if (vaults.length == 0) {
            revert NoVaultsToSlash();
        }

        bool multiToken = false;
        {
            address collateralToken_ = IVault(vaults[0]).collateral();
            for (uint256 i = 1; i < vaults.length; ++i) {
                if (IVault(vaults[i]).collateral() != collateralToken_) {
                    multiToken = true;
                    break;
                }
            }
        }

        uint256[] memory weights;
        uint256 totalWeight;
        {
            bytes32[] memory subnetworks_ = new bytes32[](1);
            subnetworks_[0] = params.subnetwork;
            bytes memory wpData = WPDataComposer.composeWPData(_slashVaultWeightProvider(), params.timestamp, operator, vaults, subnetworks_, params.wpDataParams);
            (weights, totalWeight) = IWeightProvider(_slashVaultWeightProvider()).getWeightsAndTotal(MathConvert.convertAddressArrayToBytes32Array(vaults), wpData);
        }

        if (weights.length != vaults.length) {
            revert InvalidVaultWeightsLength();
        }

        uint256[] memory slashAmounts = new uint256[](vaults.length);
        {
            uint256 usedAmount;
            uint256 lastIndex = vaults.length - 1;
            for (uint256 i; i < vaults.length; ++i) {
                slashAmounts[i] = Math.mulDiv(params.amount, weights[i], totalWeight);
                if (i == lastIndex) {
                    slashAmounts[i] = params.amount - usedAmount;
                }
                usedAmount += slashAmounts[i];
            }
        }

        if (multiToken) {
            slashAmounts = MathConvert.convertToVaultsCollateral(vaults, slashAmounts, _priceProvider(), params.priceProviderData, params.timestamp);
        }

        for (uint256 i; i < vaults.length; ++i) {
            _slashVault(params.timestamp, vaults[i], params.subnetwork, operator, slashAmounts[i], params.slashHints[i]);
        }
    }
}
