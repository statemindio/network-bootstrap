// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWeightProvider} from "./IWeightProvider.sol";

interface IVaultDelegatorStakeWeightProvider is IWeightProvider {
    struct VaultDelegatorStakeWPData {
        address operator;
        uint48 timestamp;
        bytes32[] subnetworks;
        bytes[][] stakeHints;
        bytes[] priceProviderData;
    }
}