// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EqualStakePower} from "@symbioticfi/middleware-sdk/extensions/managers/stake-powers/EqualStakePower.sol";
import {FlexibleSlasher} from "./managers/slashers/FlexibleSlasher.sol";
import {ProxyRewardRoles} from "./extensions/rewards/ProxyRewardRoles.sol";
import {ProxyReward} from "./extensions/rewards/ProxyReward.sol";
import {WeightedRewardsRoles} from "./extensions/rewards/WeightedRewardsRoles.sol";
import {WeightedRewards} from "./extensions/rewards/WeightedRewards.sol";
import {SubnetworkSlasher} from "./managers/slashers/SubnetworkSlasher.sol";
import {VaultSlasher} from "./managers/slashers/VaultSlasher.sol";
import {CommonSlasher} from "./managers/slashers/CommonSlasher.sol";
import {FlexibleSlasherRoles} from "./extensions/slashers/FlexibleSlasherRoles.sol";
import {SubnetworkSlasherRoles} from "./extensions/slashers/SubnetworkSlasherRoles.sol";
import {VaultSlasherRoles} from "./extensions/slashers/VaultSlasherRoles.sol";
import {CommonSlasherRoles} from "./extensions/slashers/CommonSlasherRoles.sol";
import {Operators} from "@symbioticfi/middleware-sdk/extensions/operators/Operators.sol";
import {SelfRegisterOperators} from "@symbioticfi/middleware-sdk/extensions/operators/SelfRegisterOperators.sol";
import {ECDSASig} from "@symbioticfi/middleware-sdk/extensions/managers/sigs/ECDSASig.sol";
import {KeyManager256} from "@symbioticfi/middleware-sdk/extensions/managers/keys/KeyManager256.sol";
import {ForcePauseSelfRegisterOperators} from
    "@symbioticfi/middleware-sdk/extensions/operators/ForcePauseSelfRegisterOperators.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";
import {EpochCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/EpochCapture.sol";

// From Statemind Middleware SDK
// Supported combinations:
// Rewards:
// 1) ProxyReward
// 2) WeightedRewards
// Slashing:
// 1) FlexibleSlasher
// 2) SubnetworkSlasher
// 3) VaultSlasher
// 4) CommonSlasher

// From Symbiotic Middleware SDK
// AccessManager:
// 1) OzAccessControl - the most flexible and implicitly covers other types.
// TODO For other implementations, specify in the README.
// CaptureTimestampManager:
// 1) EpochCapture
// 2) TimestampCapture
// KeyManager:
// 1) KeyManager256 - 256-bit keys are standard for most networks.
// TODO For other implementations, specify in the README.
// SignatureManagers:
// 1) ECDSASig - ECDSA is the most popular key format.
// TODO For other implementations, specify in the README.
// StakePowerManager:
// 1) EqualStakePower - single implementation
// Operators:
// 1) Operators
// 2) SelfRegisterOperators
// 3) ForcePauseSelfRegisterOperators

contract ManualRewardsSlashOperatorsEpochCaptureRolesMiddleware is
    ProxyRewardRoles,
    FlexibleSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // FlexibleSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // ProxyRewardRoles
        address distributeStakerReward;
        address distributeOperatorRewards;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __FlexibleSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __ProxyRewardRoles_init(params.distributeStakerReward, params.distributeOperatorRewards);
    }
}

contract ManualRewardsSlashSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    ProxyRewardRoles,
    FlexibleSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // FlexibleSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // ProxyRewardRoles
        address distributeStakerReward;
        address distributeOperatorRewards;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __FlexibleSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __ProxyRewardRoles_init(params.distributeStakerReward, params.distributeOperatorRewards);
        __SelfRegisterOperators_init(params.name);
    }
}

contract ManualRewardsSlashForcePauseSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    ProxyRewardRoles,
    FlexibleSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // FlexibleSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // ProxyRewardRoles
        address distributeStakerReward;
        address distributeOperatorRewards;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __FlexibleSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __ProxyRewardRoles_init(params.distributeStakerReward, params.distributeOperatorRewards);
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardSubnetworkSlasherOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    SubnetworkSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SubnetworkSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
    }
}

contract WeightedRewardSubnetworkSlasherSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    SubnetworkSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SubnetworkSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardSubnetworkSlasherForcePauseSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    SubnetworkSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SubnetworkSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardVaultSlasherOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    VaultSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // VaultSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __VaultSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
    }
}

contract WeightedRewardVaultSlasherSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    VaultSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // VaultSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __VaultSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardVaultSlasherForcePauseSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    VaultSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // VaultSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __VaultSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardCommonSlasherOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    CommonSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __CommonSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
    }
}

contract WeightedRewardCommonSlasherSelfRegisterOperatorsEpochCaptureRolesMiddleware is
    WeightedRewardsRoles,
    CommonSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __CommonSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardCommonSlasherForcePauseSelfRegisterOperatorsRolesEpochCaptureMiddleware is
    WeightedRewardsRoles,
    CommonSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    EpochCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // EpochCapture
        uint48 epochDuration;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // CommonSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __EpochCapture_init(params.epochDuration);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __CommonSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract ManualRewardsSlashOperatorsTimestampCaptureRolesMiddleware is
    ProxyRewardRoles,
    FlexibleSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // FlexibleSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // ProxyRewardRoles
        address distributeStakerReward;
        address distributeOperatorRewards;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __FlexibleSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __ProxyRewardRoles_init(params.distributeStakerReward, params.distributeOperatorRewards);
    }
}

contract ManualRewardsSlashSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    ProxyRewardRoles,
    FlexibleSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // FlexibleSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // ProxyRewardRoles
        address distributeStakerReward;
        address distributeOperatorRewards;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __FlexibleSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __ProxyRewardRoles_init(params.distributeStakerReward, params.distributeOperatorRewards);
        __SelfRegisterOperators_init(params.name);
    }
}

contract ManualRewardsSlashForcePauseSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    ProxyRewardRoles,
    FlexibleSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // FlexibleSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // ProxyRewardRoles
        address distributeStakerReward;
        address distributeOperatorRewards;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __FlexibleSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __ProxyRewardRoles_init(params.distributeStakerReward, params.distributeOperatorRewards);
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardSubnetworkSlasherOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    SubnetworkSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SubnetworkSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
    }
}

contract WeightedRewardSubnetworkSlasherSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    SubnetworkSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SubnetworkSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardSubnetworkSlasherForcePauseSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    SubnetworkSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SubnetworkSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SubnetworkSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardVaultSlasherOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    VaultSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // VaultSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __VaultSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
    }
}

contract WeightedRewardVaultSlasherSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    VaultSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // VaultSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __VaultSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardVaultSlasherForcePauseSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    VaultSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // VaultSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __VaultSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardCommonSlasherOperatorsRolesTimestampCaptureMiddleware is
    WeightedRewardsRoles,
    CommonSlasherRoles,
    Operators,
    KeyManager256,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // CommonSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __CommonSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
    }
}

contract WeightedRewardCommonSlasherSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    CommonSlasherRoles,
    SelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // CommonSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __CommonSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}

contract WeightedRewardCommonSlasherForcePauseSelfRegisterOperatorsTimestampCaptureRolesMiddleware is
    WeightedRewardsRoles,
    CommonSlasherRoles,
    ForcePauseSelfRegisterOperators,
    KeyManager256,
    ECDSASig,
    EqualStakePower,
    TimestampCapture
{
    struct InitParams {
        // BaseMiddleware
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptin;
        address reader;
        // BaseDefaultStakerRewardsManager
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardsRegistry;
        // BaseDefaultRewardsManager
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        // RewardWeightProviderStorage
        address rewardWeightProvider;
        // WeightedRewardsRoles
        address distributeRewards;
        // PriceProviderStorage
        address priceProvider;
        // SlashVaultWeightProviderStorage
        address slashVaultWeightProvider;
        // SlashSubnetworkWeightProviderStorage
        address slashSubnetworkWeightProvider;
        // CommonSlasherRoles
        address slasher;
        // OzAccessControl
        address defaultAdmin;
        // SelfRegisterOperators
        string name;
    }

    constructor(InitParams memory params) {
        initialize(params);
    }

    function initialize(InitParams memory params) internal initializer {
        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetOptin,
            params.reader
        );
        __BaseDefaultStakerRewardsManager_init(
            params.vaults, params.stakerRewardsDistributors, params.stakerRewardsRegistry
        );
        __BaseDefaultRewardsManager_init(params.operatorRewardsDistributor, params.operatorRewardsRegistry);
        __RewardWeightProviderStorage_init(params.rewardWeightProvider);
        __WeightedRewardsRoles_init(params.distributeRewards);
        __PriceProviderStorage_init(params.priceProvider);
        __SlashVaultWeightProviderStorage_init(params.slashVaultWeightProvider);
        __SlashSubnetworkWeightProviderStorage_init(params.slashSubnetworkWeightProvider);
        __CommonSlasherRoles_init(params.slasher);
        if (params.defaultAdmin != address(0)) {
            __OzAccessControl_init(params.defaultAdmin);
        }
        __SelfRegisterOperators_init(params.name);
    }
}
