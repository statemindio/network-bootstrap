// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OzAccessControl} from "@symbioticfi/middleware-sdk/extensions/managers/access/OzAccessControl.sol";
import {VaultSlasher} from "../../managers/slashers/VaultSlasher.sol";

abstract contract VaultSlasherRoles is VaultSlasher, OzAccessControl {
    function __VaultSlasherRoles_init(address slasher) internal onlyInitializing {
        bytes4 selector = VaultSlasher.slash.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, slasher);
    }
}
