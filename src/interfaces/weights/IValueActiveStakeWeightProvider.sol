// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWeightProvider} from "./IWeightProvider.sol";

interface IValueActiveStakeWeightProvider is IWeightProvider {
    struct ValueWPData {
        uint48 timestamp;
        bytes[] activeStakeAtHints;
        bytes[] priceProviderData;
    }
}
