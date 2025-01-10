// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";
import {CommonSlasher} from "../../managers/slashers/CommonSlasher.sol";

abstract contract CommonSlasherRoles is CommonSlasher, OzAccessControl {
    function __CommonSlasherRoles_init(address slasher) internal onlyInitializing {
        bytes4 selector = CommonSlasher.slash.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, slasher);
    }
}
