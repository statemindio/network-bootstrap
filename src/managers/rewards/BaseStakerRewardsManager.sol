// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IRegistry} from "@symbioticfi/core/src/interfaces/common/IRegistry.sol";
import {VaultManager} from "@symbioticfi/middleware-sdk/managers/VaultManager.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

abstract contract BaseStakerRewardsManager is VaultManager {
    using EnumerableMap for EnumerableMap.AddressToAddressMap;

    error ZeroVault();
    error InvalidStakerRewardsDistributorsLength();
    error UnknownStakerRewardDistributor();
    error NotActiveVault();

    /// @custom:storage-location erc7201:statemind.storage.BaseDefaultOperatorRewardsManager
    struct BaseDefaultStakerRewardsManagerStorage {
        mapping(address vault => address stakerRewardsDistributor) _vaultsStakerRewardsDistributors;
        address _stakerRewardsRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("statemind.storage.BaseStakerRewardsManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseStakerRewardsManagerStorageLocation =
        0x127d37d169e9e611a4bf2839d4838622a386d8303a907122638258c5b3f1ec00;

    function __BaseDefaultStakerRewardsManager_init(
        address[] memory vaults,
        address[] memory stakerRewardsDistributors,
        address stakerRewardsRegistry
    ) internal onlyInitializing {
        if (vaults.length != stakerRewardsDistributors.length) {
            revert InvalidStakerRewardsDistributorsLength();
        }
        _getBaseDefaultStakerRewardsManagerStorage()._stakerRewardsRegistry = stakerRewardsRegistry;
        for (uint256 i; i < stakerRewardsDistributors.length; i++) {
            _setStakerRewardsDistributor(vaults[i], stakerRewardsDistributors[i]);
        }
    }

    function _setStakerRewardsDistributor(address vault, address distributor) internal {
        _checkVault(vault);
        _checkDistributor(distributor);
        _getBaseDefaultStakerRewardsManagerStorage()._vaultsStakerRewardsDistributors[vault] = distributor;
    }

    function _resetStakerRewardsDistributor(address vault) internal {
        _checkVault(vault);
        delete _getBaseDefaultStakerRewardsManagerStorage()._vaultsStakerRewardsDistributors[vault];
    }

    function _stakerRewardsDistributors(address vault) internal view returns (address) {
        BaseDefaultStakerRewardsManagerStorage storage $ = _getBaseDefaultStakerRewardsManagerStorage();
        return $._vaultsStakerRewardsDistributors[vault];
    }

    function _stakerRewardsRegistry() internal view returns (address) {
        BaseDefaultStakerRewardsManagerStorage storage $ = _getBaseDefaultStakerRewardsManagerStorage();
        return $._stakerRewardsRegistry;
    }

    function _getBaseDefaultStakerRewardsManagerStorage()
        internal
        pure
        returns (BaseDefaultStakerRewardsManagerStorage storage $)
    {
        assembly {
            $.slot := BaseStakerRewardsManagerStorageLocation
        }
    }

    function _checkVault(address vault) internal pure {
        if (vault == address(0)) {
            revert ZeroVault();
        }
    }

    function _checkDistributor(address distributor) internal view {
        if (!IRegistry(_stakerRewardsRegistry()).isEntity(distributor)) {
            revert UnknownStakerRewardDistributor();
        }
    }

    function _checkActiveVault(address vault, uint48 timestamp) internal view {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        (bool success, address operator) = $._vaultOperator.tryGet(vault);

        if (
            (success && !_vaultWasActiveAt(timestamp, operator, vault))
                || (!success && !_sharedVaultWasActiveAt(timestamp, vault))
        ) {
            revert NotActiveVault();
        }
    }

    function _decodeDistributorTimestamp(bytes memory data) internal pure returns (uint48 timestamp) {
        (timestamp, /*uint256 maxAdminFee*/, /*bytes memory activeSharesHint*/, /*bytes memory activeStakeHint*/ ) =
            abi.decode(data, (uint48, uint256, bytes, bytes));
    }
}

abstract contract BaseStakerRewardsManagerReader is BaseStakerRewardsManager {
    function stakerRewardsDistributors(address vault) public view returns (address) {
        return _stakerRewardsDistributors(vault);
    }

    function stakerRewardsRegistry() public view returns (address) {
        return _stakerRewardsRegistry();
    }
}
