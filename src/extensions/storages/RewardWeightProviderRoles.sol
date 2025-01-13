// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {RewardWeightProvider} from "./RewardWeightProvider.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";

abstract contract RewardWeightProviderRoles is RewardWeightProvider, OzAccessControl {
    function __RewardWeightProviderHolderRoles_init(address setRewardWeightProvider) internal onlyInitializing {
        bytes4 setRewardWeightProviderSelector = RewardWeightProvider.setRewardWeightProvider.selector;
        _setSelectorRole(setRewardWeightProviderSelector, setRewardWeightProviderSelector);
        _grantRole(setRewardWeightProviderSelector, setRewardWeightProvider);
    }
}
