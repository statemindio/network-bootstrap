// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ProxyReward} from "./ProxyReward.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";

abstract contract ProxyRewardRoles is ProxyReward, OzAccessControl {
    function __ProxyRewardRoles_init(
        address distributeStakerRewards,
        address distributeOperatorRewards
    ) internal onlyInitializing {
        bytes4 distributeStakerRewardsSelector = ProxyReward.distributeStakerRewards.selector;
        bytes4 distributeStakerRewardsBatchSelector = ProxyReward.distributeStakerRewardsBatch.selector;
        bytes4 distributeOperatorRewardsSelector = ProxyReward.distributeOperatorRewards.selector;
        _setSelectorRole(distributeStakerRewardsSelector, distributeStakerRewardsSelector);
        _grantRole(distributeStakerRewardsSelector, distributeStakerRewards);
        _setSelectorRole(distributeStakerRewardsBatchSelector, distributeStakerRewardsBatchSelector);
        _grantRole(distributeStakerRewardsBatchSelector, distributeStakerRewards);
        _setSelectorRole(distributeOperatorRewardsSelector, distributeOperatorRewardsSelector);
        _grantRole(distributeOperatorRewardsSelector, distributeOperatorRewards);
    }
}