// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ProxyRewardManager} from "../../managers/rewards/ProxyRewardManager.sol";
import {AccessManager} from "@symbioticfi/middleware-sdk/managers/extendable/AccessManager.sol";
import {BaseMiddleware} from "@symbioticfi/middleware-sdk/middleware/BaseMiddleware.sol";

abstract contract ProxyReward is BaseMiddleware, ProxyRewardManager {
    error EmptyData();

    function distributeStakerRewards(StakerRewardsData memory data) external checkAccess {
        _distributeStakerRewards(data);
    }

    function distributeOperatorRewards(address token, uint256 amount, bytes32 root) external checkAccess {
        _distributeOperatorRewards(token, amount, root);
    }

    function distributeStakerRewardsBatch(StakerRewardsData[] memory data) external checkAccess {
        if (data.length == 0) {
            revert EmptyData();
        }

        for (uint256 i; i < data.length; i++) {
            StakerRewardsData memory param = data[i];
            _distributeStakerRewards(param);
        }
    }
}
