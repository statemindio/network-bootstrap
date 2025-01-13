// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {WeightProviderStorage} from "../../managers/storages/WeightProviderStorage.sol";
import {RewardWeightProviderStorage} from "../../managers/storages/RewardWeightProviderStorage.sol";
import {AccessManager} from "@symbioticfi/middleware-sdk/managers/extendable/AccessManager.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";
import {BaseMiddleware} from "@symbioticfi/middleware-sdk/middleware/BaseMiddleware.sol";

abstract contract RewardWeightProvider is BaseMiddleware, RewardWeightProviderStorage {
    function setRewardWeightProvider(address provider) external checkAccess {
        _setRewardWeightProvider(provider);
    }
}
