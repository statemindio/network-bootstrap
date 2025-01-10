// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";
import {FlexibleSlasher} from "../../managers/slashers/FlexibleSlasher.sol";

abstract contract FlexibleSlasherRoles is FlexibleSlasher, OzAccessControl {
    function __FlexibleSlasherRoles_init(address slasher) internal onlyInitializing {
        bytes4 selector = FlexibleSlasher.slash.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, slasher);
    }
}
