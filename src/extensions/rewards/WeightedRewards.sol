// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {WeightedRewardManager} from "../../managers/rewards/WeightedRewardManager.sol";
import {AccessManager} from "@symbioticfi/middleware-sdk/managers/extendable/AccessManager.sol";
import {BaseMiddleware} from "@symbioticfi/middleware-sdk/middleware/BaseMiddleware.sol";

abstract contract WeightedRewards is BaseMiddleware, WeightedRewardManager {
    function distributeRewards(
        address token,
        uint256 totalAmount,
        uint256 operatorAmount,
        bytes32 root,
        bytes calldata data
    ) external checkAccess {
        _distributeRewards(token, totalAmount, operatorAmount, root, data);
    }
}
