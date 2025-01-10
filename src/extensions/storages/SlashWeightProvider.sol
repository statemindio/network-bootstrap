// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseMiddleware} from "@symbioticfi/middleware-sdk/middleware/BaseMiddleware.sol";
import {AccessManager} from "@symbioticfi/middleware-sdk/managers/extendable/AccessManager.sol";
import {
    SlashVaultWeightProviderStorage,
    SlashSubnetworkWeightProviderStorage
} from "../../managers/storages/SlashWeightProviderStorage.sol";

abstract contract SlashVaultWeightProvider is BaseMiddleware, SlashVaultWeightProviderStorage {
    function setSlashVaultWeightProvider(address provider) external checkAccess {
        _setSlashVaultWeightProvider(provider);
    }
}

abstract contract SlashSubnetworkWeightProvider is BaseMiddleware, SlashSubnetworkWeightProviderStorage {
    function setSlashSubnetworkWeightProvider(address provider) external checkAccess {
        _setSlashSubnetworkWeightProvider(provider);
    }
}
