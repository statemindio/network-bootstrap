// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {WeightedRewards} from "./WeightedRewards.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";

abstract contract WeightedRewardsRoles is WeightedRewards, OzAccessControl {
    function __WeightedRewardsRoles_init(address distributeRewards) internal onlyInitializing {
        bytes4 distributeRewardsSelector = WeightedRewards.distributeRewards.selector;
        _setSelectorRole(distributeRewardsSelector, distributeRewardsSelector);
        _grantRole(distributeRewardsSelector, distributeRewards);
    }
}
