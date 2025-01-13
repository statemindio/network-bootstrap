// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWeightProvider} from "./IWeightProvider.sol";

interface IAmountActiveStakeWeightProvider is IWeightProvider {
    struct AmountWPData {
        uint48 timestamp;
        bytes[] activeStakeAtHints;
    }
}
