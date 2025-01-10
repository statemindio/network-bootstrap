// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {BaseSlasher} from "./BaseSlasher.sol";
import {
    SlashVaultWeightProviderStorage,
    SlashSubnetworkWeightProviderStorage
} from "../storages/SlashWeightProviderStorage.sol";
import {PriceProviderStorage} from "../storages/PriceProviderStorage.sol";
import {IWeightProvider} from "../../interfaces/weights/IWeightProvider.sol";
import {WPDataComposer} from "../../libs/WPDataComposer.sol";
import {MathConvert} from "../../libs/MathConvert.sol";

abstract contract CommonSlasher is
    BaseSlasher,
    SlashVaultWeightProviderStorage,
    SlashSubnetworkWeightProviderStorage,
    PriceProviderStorage
{
    using Subnetwork for address;

    error InvalidVaultWeightsLength();
    error InvalidSubnetworkWeightsLength();
    error VaultsHaveDifferentCollateral();
    error NoVaultsToSlash();
    error NoSubnetworksToSlash();

    struct SlashParams {
        uint48 timestamp;
        bytes key;
        uint256 amount;
        bytes[][] slashHints;
        bytes vaultWPDataParams;
        bytes[] subnetworksWPDataParams;
        bytes[] priceProviderData;
    }

    /*
     * @notice Slashes a validator in the provided subnetwork
     * @param timestamp The timestamp for which the slashing occurs.
     * @param key The key of the operator to slash.
     * @param amount The amount to slash.
     * @param slashHints Hints for the slashing process.
     * @param distributionData Data for distribution (stake hints for proportional distribution or wpData for weighted distribution)
     * @return A struct SlashResponse containing information about the slash response.
     */
    function slash(SlashParams calldata params) public checkAccess {
        address operator = getOperatorAndCheckCanSlash(params.key, params.timestamp);

        address[] memory vaults = _activeVaultsAt(params.timestamp, operator);
        bytes32[] memory _subnetworks;
        {
            uint160[] memory subnetworks_ = _activeSubnetworksAt(params.timestamp);
            _subnetworks = MathConvert.convertSubnetworksArrayToBytes32Array(_NETWORK(), subnetworks_);
        }
        if (vaults.length == 0) {
            revert NoVaultsToSlash();
        }
        if (_subnetworks.length == 0) {
            revert NoSubnetworksToSlash();
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
        uint256[] memory vaultWeights;
        uint256 vaultTotalWeight;
        {
            bytes memory vaultWPData = WPDataComposer.composeWPData(
                _slashVaultWeightProvider(), params.timestamp, operator, vaults, _subnetworks, params.vaultWPDataParams
            );
            (vaultWeights, vaultTotalWeight) = IWeightProvider(_slashVaultWeightProvider()).getWeightsAndTotal(
                MathConvert.convertAddressArrayToBytes32Array(vaults), vaultWPData
            );
        }
        if (vaultWeights.length != vaults.length) {
            revert InvalidVaultWeightsLength();
        }

        uint256[] memory vaultSlashAmounts = new uint256[](vaults.length);
        uint256 lastIndex = vaults.length - 1;
        {
            uint256 vaultUsedAmount;
            for (uint256 i; i < vaults.length; ++i) {
                vaultSlashAmounts[i] = Math.mulDiv(params.amount, vaultWeights[i], vaultTotalWeight);
                if (i == lastIndex) {
                    vaultSlashAmounts[i] = params.amount - vaultUsedAmount;
                }
                vaultUsedAmount += vaultSlashAmounts[i];
            }
        }

        if (multiToken) {
            vaultSlashAmounts = MathConvert.convertToVaultsCollateral(
                vaults, vaultSlashAmounts, _priceProvider(), params.priceProviderData, params.timestamp
            );
        }

        lastIndex = _subnetworks.length - 1;
        for (uint256 i; i < vaults.length; ++i) {
            bytes memory wpData;
            {
                address[] memory vaultArray_ = new address[](1);
                vaultArray_[0] = vaults[i];
                wpData = WPDataComposer.composeWPData(
                    _slashSubnetworkWeightProvider(),
                    params.timestamp,
                    operator,
                    vaultArray_,
                    _subnetworks,
                    params.subnetworksWPDataParams[i]
                );
            }
            (uint256[] memory subnetworkWeights, uint256 subnetworkTotalWeight) =
                IWeightProvider(_slashSubnetworkWeightProvider()).getWeightsAndTotal(_subnetworks, wpData);

            if (subnetworkWeights.length != _subnetworks.length) {
                revert InvalidSubnetworkWeightsLength();
            }

            uint256 subnetworkUsedAmount;
            for (uint256 j; j < _subnetworks.length; ++j) {
                uint256 subnetworkAmount =
                    Math.mulDiv(vaultSlashAmounts[i], subnetworkWeights[j], subnetworkTotalWeight);
                if (j == lastIndex) {
                    subnetworkAmount = vaultSlashAmounts[i] - subnetworkUsedAmount;
                }
                subnetworkUsedAmount += subnetworkAmount;
                _slashVault(
                    params.timestamp, vaults[i], _subnetworks[i], operator, subnetworkAmount, params.slashHints[i][j]
                );
            }
        }
    }
}
