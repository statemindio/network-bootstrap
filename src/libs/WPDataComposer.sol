// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWeightProvider} from "../interfaces/weights/IWeightProvider.sol";
import {IConfigWeightProvider} from "../interfaces/weights/IConfigWeightProvider.sol";
import {IAmountActiveStakeWeightProvider} from "../interfaces/weights/IAmountActiveStakeWeightProvider.sol";
import {IValueActiveStakeWeightProvider} from "../interfaces/weights/IValueActiveStakeWeightProvider.sol";
import {IVaultDelegatorStakeWeightProvider} from "../interfaces/weights/IVaultDelegatorStakeWeightProvider.sol";
import {ISubnetworkDelegatorStakeWeightProvider} from "../interfaces/weights/ISubnetworkDelegatorStakeWeightProvider.sol";


library WPDataComposer {
    error RequireSingleVault();
    error InvalidWeightProviderType();

    // WP TYPE 1
    struct ConfigWPDataParams {
        bytes[] weightsAtHints;
    }

    // WP TYPE 2
    struct AmountWPDataParams {
        bytes[] activeStakeAtHints;
    }

    // WP TYPE 3
    struct ValueWPDataParams {
        bytes[] activeStakeAtHints;
        bytes[] priceProviderData;
    }

    // WP TYPE 4
    struct VaultDelegatorStakeWPDataParams {
        bytes[][] stakeHints;
        bytes[] priceProviderData;
    }

    // WP TYPE 5
    struct SubnetworkDelegatorStakeWPDataParams {
        bytes[] stakeHints;
    }

    function composeWPData(
        address weightProvider,
        uint48 timestamp,
        address operator,
        address[] memory vaults,
        bytes32[] memory subnetworks,
        bytes memory wpDataParams
    ) internal view returns (bytes memory wpData) {
        uint64 wpType = IWeightProvider(weightProvider).TYPE();
        if (wpType == 1) {
            ConfigWPDataParams memory wpDataParamsStruct = abi.decode(wpDataParams, (ConfigWPDataParams));
            IConfigWeightProvider.ConfigWPData memory wpDataStruct;
            wpDataStruct.timestamp = timestamp;
            wpDataStruct.weightsAtHints = wpDataParamsStruct.weightsAtHints;
            wpData = abi.encode(wpDataStruct);
        } else if (wpType == 2) {
            AmountWPDataParams memory wpDataParamsStruct = abi.decode(wpDataParams, (AmountWPDataParams));
            IAmountActiveStakeWeightProvider.AmountWPData memory wpDataStruct;
            wpDataStruct.timestamp = timestamp;
            wpDataStruct.activeStakeAtHints = wpDataParamsStruct.activeStakeAtHints;
            wpData = abi.encode(wpDataStruct);
        } else if (wpType == 3) {
            ValueWPDataParams memory wpDataParamsStruct = abi.decode(wpDataParams, (ValueWPDataParams));
            IValueActiveStakeWeightProvider.ValueWPData memory wpDataStruct;
            wpDataStruct.timestamp = timestamp;
            wpDataStruct.activeStakeAtHints = wpDataParamsStruct.activeStakeAtHints;
            wpDataStruct.priceProviderData = wpDataParamsStruct.priceProviderData;
            wpData = abi.encode(wpDataStruct);
        } else if (wpType == 4) {
            VaultDelegatorStakeWPDataParams memory wpDataParamsStruct = abi.decode(wpDataParams, (VaultDelegatorStakeWPDataParams));
            IVaultDelegatorStakeWeightProvider.VaultDelegatorStakeWPData memory wpDataStruct;
            wpDataStruct.operator = operator;
            wpDataStruct.timestamp = timestamp;
            wpDataStruct.subnetworks = subnetworks;
            wpDataStruct.stakeHints = wpDataParamsStruct.stakeHints;
            wpDataStruct.priceProviderData = wpDataParamsStruct.priceProviderData;
            wpData = abi.encode(wpDataStruct);
        } else if (wpType == 5) {
            SubnetworkDelegatorStakeWPDataParams memory wpDataParamsStruct = abi.decode(wpDataParams, (SubnetworkDelegatorStakeWPDataParams));
            ISubnetworkDelegatorStakeWeightProvider.SubnetworkDelegatorStakeWPData memory wpDataStruct;
            wpDataStruct.operator = operator;
            wpDataStruct.timestamp = timestamp;
            if (vaults.length != 1) {
                revert RequireSingleVault();
            }
            wpDataStruct.vault = vaults[0];
            wpDataStruct.stakeHints = wpDataParamsStruct.stakeHints;
            wpData = abi.encode(wpDataStruct);
        } else {
            revert InvalidWeightProviderType();
        }
    }
}
