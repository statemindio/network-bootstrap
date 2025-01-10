// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SlashVaultWeightProvider, SlashSubnetworkWeightProvider} from "./SlashWeightProvider.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";

abstract contract SlashVaultWeightProviderRoles is SlashVaultWeightProvider, OzAccessControl {
    function __SlashVaultWeightProviderHolderRoles_init(address setSlashVaultWeightProvider)
        internal
        onlyInitializing
    {
        bytes4 setSlashVaultWeightProviderSelector = SlashVaultWeightProvider.setSlashVaultWeightProvider.selector;
        _setSelectorRole(setSlashVaultWeightProviderSelector, setSlashVaultWeightProviderSelector);
        _grantRole(setSlashVaultWeightProviderSelector, setSlashVaultWeightProvider);
    }
}

abstract contract SlashSubnetworkWeightProviderRoles is SlashSubnetworkWeightProvider, OzAccessControl {
    function __SlashSubnetworkWeightProviderHolderRoles_init(address setSlashSubnetworkWeightProvider)
        internal
        onlyInitializing
    {
        bytes4 setSlashSubnetworkWeightProviderSelector =
            SlashSubnetworkWeightProvider.setSlashSubnetworkWeightProvider.selector;
        _setSelectorRole(setSlashSubnetworkWeightProviderSelector, setSlashSubnetworkWeightProviderSelector);
        _grantRole(setSlashSubnetworkWeightProviderSelector, setSlashSubnetworkWeightProvider);
    }
}
