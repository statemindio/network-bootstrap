// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";
import {FlexibleSlasher} from "../../managers/slashers/FlexibleSlasher.sol";
import {SubnetworkSlasher} from "../../managers/slashers/SubnetworkSlasher.sol";

abstract contract SubnetworkSlasherRoles is SubnetworkSlasher, OzAccessControl {
    function __SubnetworkSlasherRoles_init(address slasher) internal onlyInitializing {
        bytes4 selector = SubnetworkSlasher.slash.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, slasher);
    }
}
