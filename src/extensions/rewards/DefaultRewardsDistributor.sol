// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AccessManager} from "@symbioticfi/middleware-sdk/managers/extendable/AccessManager.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";
import {BaseDefaultOperatorRewardsManager} from "../../managers/rewards/BaseDefaultOperatorRewardsManager.sol";
import {BaseStakerRewardsManager} from "../../managers/rewards/BaseStakerRewardsManager.sol";
import {BaseMiddleware} from "@symbioticfi/middleware-sdk/middleware/BaseMiddleware.sol";

abstract contract DefaultRewardsDistributor is
    BaseMiddleware,
    BaseDefaultOperatorRewardsManager,
    BaseStakerRewardsManager
{
    function setStakerRewardsDistributor(address vault, address distributor) external checkAccess {
        _setStakerRewardsDistributor(vault, distributor);
    }

    function setOperatorRewardsDistributor(address distributor) external checkAccess {
        _setOperatorRewardsDistributor(distributor);
    }

    function resetStakerRewardsDistributor(address vault) external checkAccess {
        _resetStakerRewardsDistributor(vault);
    }
}
