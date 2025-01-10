// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWeightProvider} from "./IWeightProvider.sol";

interface ISubnetworkDelegatorStakeWeightProvider is IWeightProvider {
    struct SubnetworkDelegatorStakeWPData {
        address operator;
        uint48 timestamp;
        address vault;
        bytes[] stakeHints;
    }
}