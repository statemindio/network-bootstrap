// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IRegistry} from "@symbioticfi/core/src/interfaces/common/IRegistry.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract BaseDefaultOperatorRewardsManager is Initializable {
    error ZeroDistributor();
    error UnknownOperatorRewardDistributor();

    /// @custom:storage-location erc7201:statemind.storage.BaseDefaultOperatorRewardsManager
    struct BaseDefaultOperatorRewardsManagerStorage {
        address _operatorRewardsDistributor;
        address _operatorRewardsRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("statemind.storage.BaseDefaultOperatorRewardsManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseDefaultOperatorRewardsManagerStorageLocation =
        0xfe3f5a560fbba955a576f48c98d340ebfe2614aeaff6e2e59297b0e649328e00;

    function __BaseDefaultRewardsManager_init(
        address operatorRewardsDistributor,
        address operatorRewardsRegistry
    ) internal onlyInitializing {
        _getBaseDefaultOperatorRewardsManagerStorage()._operatorRewardsRegistry = operatorRewardsRegistry;
        _setOperatorRewardsDistributor(operatorRewardsDistributor);
    }

    function _setOperatorRewardsDistributor(address distributor) internal {
        if (distributor == address(0)) {
            revert ZeroDistributor();
        }
        if (!IRegistry(_operatorRewardsRegistry()).isEntity(distributor)) {
            revert UnknownOperatorRewardDistributor();
        }

        _getBaseDefaultOperatorRewardsManagerStorage()._operatorRewardsDistributor = distributor;
    }

    function _operatorRewardsDistributor() internal view returns (address) {
        BaseDefaultOperatorRewardsManagerStorage storage $ = _getBaseDefaultOperatorRewardsManagerStorage();
        return $._operatorRewardsDistributor;
    }

    function _operatorRewardsRegistry() internal view returns (address) {
        BaseDefaultOperatorRewardsManagerStorage storage $ = _getBaseDefaultOperatorRewardsManagerStorage();
        return $._operatorRewardsRegistry;
    }

    function _getBaseDefaultOperatorRewardsManagerStorage()
    internal
    pure
    returns (BaseDefaultOperatorRewardsManagerStorage storage $)
    {
        assembly {
            $.slot := BaseDefaultOperatorRewardsManagerStorageLocation
        }
    }
}

abstract contract BaseDefaultOperatorRewardsManagerReader is BaseDefaultOperatorRewardsManager {

    function operatorRewardsDistributor() public view returns (address) {
        return _operatorRewardsDistributor();
    }

    function operatorRewardsRegistry() public view returns (address) {
        return _operatorRewardsRegistry();
    }
}