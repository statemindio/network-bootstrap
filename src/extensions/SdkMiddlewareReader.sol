// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseMiddlewareReader} from "@symbioticfi/middleware-sdk/middleware/BaseMiddlewareReader.sol";
import {RewardWeightProviderStorageReader} from "../managers/storages/RewardWeightProviderStorage.sol";
import {
    SlashVaultWeightProviderStorageReader,
    SlashSubnetworkWeightProviderStorageReader
} from "../managers/storages/SlashWeightProviderStorage.sol";
import {BaseDefaultOperatorRewardsManagerReader} from "../managers/rewards/BaseDefaultOperatorRewardsManager.sol";
import {BaseStakerRewardsManagerReader} from "../managers/rewards/BaseStakerRewardsManager.sol";

contract SdkMiddlewareReader is
    BaseMiddlewareReader,
    RewardWeightProviderStorageReader,
    SlashVaultWeightProviderStorageReader,
    SlashSubnetworkWeightProviderStorageReader,
    BaseDefaultOperatorRewardsManagerReader,
    BaseStakerRewardsManagerReader
{}
