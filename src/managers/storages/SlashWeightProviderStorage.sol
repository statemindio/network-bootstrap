// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IWeightProvider} from "../../interfaces/weights/IWeightProvider.sol";
import {WeightProviderStorage} from "./WeightProviderStorage.sol";

abstract contract SlashVaultWeightProviderStorage is WeightProviderStorage {
    error UnsupportedSlashVaultWeightProviderType();

    // keccak256(abi.encode(uint256(keccak256("statemind.storage.WeightProviderStorage.slashVaultWeightProvider")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SlashVaultWeightProviderStorageLocation =
    0x954ed427d9b5fcbebabfc5857ee54a475963728e647a40e391cf44f8c0195000;

    function __SlashVaultWeightProviderStorage_init(address weightProvider) internal onlyInitializing {
        _setSlashVaultWeightProvider(weightProvider);
    }

    function _setSlashVaultWeightProvider(address provider) internal {
        uint64 wpType = IWeightProvider(provider).TYPE();
        if (!(wpType == 1 || wpType == 2 || wpType == 3 || wpType == 4)) {
            revert UnsupportedSlashVaultWeightProviderType();
        }
        _setWeightProvider(SlashVaultWeightProviderStorageLocation, provider);
    }

    function _slashVaultWeightProvider() internal view returns (address) {
        return _weightProvider(SlashVaultWeightProviderStorageLocation);
    }

}


abstract contract SlashSubnetworkWeightProviderStorage is WeightProviderStorage {
    error UnsupportedSlashSubnetworkWeightProviderType();

    // keccak256(abi.encode(uint256(keccak256("statemind.storage.WeightProviderStorage.slashSubnetworkWeightProvider")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SlashSubnetworkWeightProviderStorageLocation =
    0x4c5709bcf84480b17813e921baa1846cbc34c5b4173a248540130253a8115800;

    function __SlashSubnetworkWeightProviderStorage_init(address weightProvider) internal onlyInitializing {
        _setSlashSubnetworkWeightProvider(weightProvider);
    }

    function _setSlashSubnetworkWeightProvider(address provider) internal {
        uint64 wpType = IWeightProvider(provider).TYPE();
        if (!(wpType == 1 || wpType == 5)) {
            revert UnsupportedSlashSubnetworkWeightProviderType();
        }
        _setWeightProvider(SlashSubnetworkWeightProviderStorageLocation, provider);
    }

    function _slashSubnetworkWeightProvider() internal view returns (address) {
        return _weightProvider(SlashSubnetworkWeightProviderStorageLocation);
    }

}


abstract contract SlashVaultWeightProviderStorageReader is SlashVaultWeightProviderStorage {

    function slashVaultWeightProvider() public view returns (address) {
        return _slashVaultWeightProvider();
    }
}

abstract contract SlashSubnetworkWeightProviderStorageReader is SlashSubnetworkWeightProviderStorage {

    function slashSubnetworkWeightProvider() public view returns (address weightProvider) {
        return _slashSubnetworkWeightProvider();
    }
}