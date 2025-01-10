// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IWeightProvider} from "../../interfaces/weights/IWeightProvider.sol";
import {WeightProviderStorage} from "./WeightProviderStorage.sol";

abstract contract RewardWeightProviderStorage is WeightProviderStorage {
    error UnsupportedRewardWeightProviderType();

    // keccak256(abi.encode(uint256(keccak256("statemind.storage.WeightProviderStorage.rewardWeightProvider")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RewardWeightProviderStorageLocation =
        0x4423cc4749f187f556c2cf57bfa668c17041e10377239b7f03142dc42480f800;

    function __RewardWeightProviderStorage_init(address weightProvider) internal onlyInitializing {
        _setRewardWeightProvider(weightProvider);
    }

    function _rewardWeightProvider() internal view returns (address) {
        return _weightProvider(RewardWeightProviderStorageLocation);
    }

    function _setRewardWeightProvider(address provider) internal {
        uint64 wpType = IWeightProvider(provider).TYPE();
        if (!(wpType == 1 || wpType == 2 || wpType == 3)) {
            revert UnsupportedRewardWeightProviderType();
        }
        _setWeightProvider(RewardWeightProviderStorageLocation, provider);
    }
}

abstract contract RewardWeightProviderStorageReader is RewardWeightProviderStorage {
    function rewardWeightProvider() public view returns (address) {
        return _rewardWeightProvider();
    }
}
