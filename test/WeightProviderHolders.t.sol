// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "./helpers/DefaultRewardsBase.t.sol";
import {EqualStakePower} from "@symbioticfi/middleware-sdk/extensions/managers/stake-powers/EqualStakePower.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {NoKeyManager} from "@symbioticfi/middleware-sdk/extensions/managers/keys/NoKeyManager.sol";
import {RewardWeightProviderRoles} from "../src/extensions/storages/RewardWeightProviderRoles.sol";
import {RewardWeightProvider} from "../src/extensions/storages/RewardWeightProvider.sol";
import {
    SlashVaultWeightProviderRoles,
    SlashSubnetworkWeightProviderRoles
} from "../src/extensions/storages/SlashWeightProviderRoles.sol";
import {
    SlashVaultWeightProvider, SlashSubnetworkWeightProvider
} from "../src/extensions/storages/SlashWeightProvider.sol";
import {Test} from "forge-std/Test.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";

contract RewardWeightProviderHolderRolesTest is DefaultRewardsBaseTest {
    RewardWeightProviderRoles holder;

    function setUp() public override {
        super.setUp();
        address reader = address(new SdkMiddlewareReader());
        bob = address(new MockWeightProvider(1));
        RewardTestNetworkMiddleware testMiddleware = new RewardTestNetworkMiddleware();
        testMiddleware.initialize(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            alice
        );
        holder = testMiddleware;
    }

    function test_setWeightProviderIncorrectRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(RewardWeightProvider.setRewardWeightProvider.selector)
            )
        );
        holder.setRewardWeightProvider(bob);
    }

    function test_setWeightProviderCorrectRole() public {
        vm.prank(alice);
        holder.setRewardWeightProvider(bob);

        assertEq(address(SdkMiddlewareReader(address(holder)).rewardWeightProvider()), bob);
    }
}

contract RewardTestNetworkMiddleware is RewardWeightProviderRoles, NoKeyManager, EqualStakePower, TimestampCapture {
    function initialize(
        address network,
        uint48 slashingWindow,
        address vaultRegistry,
        address operatorRegistry,
        address operatorNetOptin,
        address reader,
        address setWeightProvider
    ) public initializer {
        __BaseMiddleware_init(network, slashingWindow, vaultRegistry, operatorRegistry, operatorNetOptin, reader);
        __RewardWeightProviderHolderRoles_init(setWeightProvider);
    }
}

contract SlashWeightProviderHolderRolesTest is DefaultRewardsBaseTest {
    SlashTestNetworkMiddleware holder;

    function setUp() public override {
        super.setUp();
        alice = makeAddr("alice");
        bob = address(new MockWeightProvider(1));
        address reader = address(new SdkMiddlewareReader());
        SlashTestNetworkMiddleware testMiddleware = new SlashTestNetworkMiddleware();
        testMiddleware.initialize(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            alice,
            alice
        );
        holder = testMiddleware;
    }

    function test_setVaultWeightProviderIncorrectRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(SlashVaultWeightProvider.setSlashVaultWeightProvider.selector)
            )
        );
        holder.setSlashVaultWeightProvider(bob);
    }

    function test_setVaultWeightProviderCorrectRole() public {
        vm.prank(alice);
        holder.setSlashVaultWeightProvider(bob);
        assertEq(address(SdkMiddlewareReader(address(holder)).slashVaultWeightProvider()), bob);
    }

    function test_setSubnetworkWeightProviderIncorrectRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(SlashSubnetworkWeightProvider.setSlashSubnetworkWeightProvider.selector)
            )
        );
        holder.setSlashSubnetworkWeightProvider(bob);
    }

    function test_setSubnetworkWeightProviderCorrectRole() public {
        vm.prank(alice);
        holder.setSlashSubnetworkWeightProvider(bob);
        assertEq(address(SdkMiddlewareReader(address(holder)).slashSubnetworkWeightProvider()), bob);
    }
}

contract SlashTestNetworkMiddleware is
    SlashVaultWeightProviderRoles,
    SlashSubnetworkWeightProviderRoles,
    NoKeyManager,
    EqualStakePower,
    TimestampCapture
{
    function initialize(
        address network,
        uint48 slashingWindow,
        address vaultRegistry,
        address operatorRegistry,
        address operatorNetOptin,
        address reader,
        address setSlashVaultWeightProvider,
        address setSlashSubnetworkWeightProvider
    ) public initializer {
        __BaseMiddleware_init(network, slashingWindow, vaultRegistry, operatorRegistry, operatorNetOptin, reader);
        __SlashVaultWeightProviderHolderRoles_init(setSlashVaultWeightProvider);
        __SlashSubnetworkWeightProviderHolderRoles_init(setSlashSubnetworkWeightProvider);
    }
}

contract MockWeightProvider {
    uint64 public immutable TYPE;

    constructor(uint64 type_) {
        TYPE = type_;
    }
}
