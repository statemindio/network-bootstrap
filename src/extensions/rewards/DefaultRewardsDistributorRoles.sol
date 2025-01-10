// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {DefaultRewardsDistributor} from "./DefaultRewardsDistributor.sol";
import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";

abstract contract DefaultRewardsDistributorRoles is DefaultRewardsDistributor, OzAccessControl {
    function __DefaultRewardsDistributorRoles_init(
        address setStakerRewardsDistributor,
        address resetStakerRewardsDistributor,
        address setOperatorRewardsDistributor
    ) internal onlyInitializing {
        bytes4 setStakerRewardsDistributorSelector = DefaultRewardsDistributor.setStakerRewardsDistributor.selector;
        _setSelectorRole(setStakerRewardsDistributorSelector, setStakerRewardsDistributorSelector);
        _grantRole(setStakerRewardsDistributorSelector, setStakerRewardsDistributor);
        bytes4 resetStakerRewardsDistributorSelector = DefaultRewardsDistributor.resetStakerRewardsDistributor.selector;
        _setSelectorRole(resetStakerRewardsDistributorSelector, resetStakerRewardsDistributorSelector);
        _grantRole(resetStakerRewardsDistributorSelector, resetStakerRewardsDistributor);
        bytes4 setOperatorRewardsDistributorSelector = DefaultRewardsDistributor.setOperatorRewardsDistributor.selector;
        _setSelectorRole(setOperatorRewardsDistributorSelector, setOperatorRewardsDistributorSelector);
        _grantRole(setOperatorRewardsDistributorSelector, setOperatorRewardsDistributor);
    }
}
