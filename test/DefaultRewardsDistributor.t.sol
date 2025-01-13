// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {NoKeyManager} from "@symbioticfi/middleware-sdk/extensions/managers/keys/NoKeyManager.sol";
import {BaseDefaultOperatorRewardsManager} from "../src/managers/rewards/BaseDefaultOperatorRewardsManager.sol";
import {BaseStakerRewardsManager} from "../src/managers/rewards/BaseStakerRewardsManager.sol";
import {DefaultRewardsDistributor} from "../src/extensions/rewards/DefaultRewardsDistributor.sol";
import {DefaultRewardsDistributorRoles} from "../src/extensions/rewards/DefaultRewardsDistributorRoles.sol";
import {DefaultOperatorRewards} from
    "@symbioticfi/rewards/src/contracts/defaultOperatorRewards/DefaultOperatorRewards.sol";
import {DefaultRewardsBaseTest} from "./helpers/DefaultRewardsBase.t.sol";
import {DefaultStakerRewards} from "@symbioticfi/rewards/src/contracts/defaultStakerRewards/DefaultStakerRewards.sol";
import {EqualStakePower} from "@symbioticfi/middleware-sdk/extensions/managers/stake-powers/EqualStakePower.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";
import {SdkMiddlewareReader} from "../src/extensions/SdkMiddlewareReader.sol";

contract DefaultRewardsDistributorInitializable is
    DefaultRewardsDistributorRoles,
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
        address setStakerRewardsDistributorsRole,
        address resetStakerRewardsDistributorsRole,
        address setOperatorRewardsDistributorRole,
        address[] memory vaults,
        address[] memory stakerRewardsDistributors,
        address stakerRewardsRegistry,
        address operatorRewardsDistributor,
        address operatorRewardsRegistry
    ) external initializer {
        __BaseMiddleware_init(network, slashingWindow, vaultRegistry, operatorRegistry, operatorNetOptin, reader);
        __DefaultRewardsDistributorRoles_init(
            setStakerRewardsDistributorsRole, resetStakerRewardsDistributorsRole, setOperatorRewardsDistributorRole
        );
        __BaseDefaultStakerRewardsManager_init(vaults, stakerRewardsDistributors, stakerRewardsRegistry);
        __BaseDefaultRewardsManager_init(operatorRewardsDistributor, operatorRewardsRegistry);
    }
}

contract DefaultRewardsDistributorTest is DefaultRewardsBaseTest {
    DefaultRewardsDistributorInitializable distributor;
    DefaultOperatorRewards defaultOperatorRewards;
    DefaultStakerRewards defaultStakerRewards;

    function setUp() public override {
        super.setUp();
        address reader = address(new SdkMiddlewareReader());
        distributor = new DefaultRewardsDistributorInitializable();
        defaultOperatorRewards = createDefaultOperatorRewards();
        defaultStakerRewards = createDefaultStakerRewards(0, address(vault));

        distributor.initialize(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            address(reader),
            alice,
            alice,
            bob,
            new address[](0),
            new address[](0),
            address(defaultStakerRewardsFactory),
            address(defaultOperatorRewards),
            address(defaultOperatorRewardsFactory)
        );
    }

    function test_setStakerRewardsDistributors_withoutRole() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(DefaultRewardsDistributor.setStakerRewardsDistributor.selector)
            )
        );
        distributor.setStakerRewardsDistributor(address(vault), address(defaultStakerRewards));
    }

    function test_resetStakerRewardsDistributors_withoutRole() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(DefaultRewardsDistributor.resetStakerRewardsDistributor.selector)
            )
        );
        distributor.resetStakerRewardsDistributor(address(vault));
    }

    function test_setStakerRewardsDistributors_initial_changing_removing() external {
        assertEq(SdkMiddlewareReader(address(distributor)).stakerRewardsDistributors(address(vault)), address(0));
        vm.prank(alice);
        distributor.setStakerRewardsDistributor(address(vault), address(defaultStakerRewards));
        assertEq(
            SdkMiddlewareReader(address(distributor)).stakerRewardsDistributors(address(vault)),
            address(defaultStakerRewards)
        );
        defaultStakerRewards = createDefaultStakerRewards(0, address(vault));
        vm.prank(alice);
        distributor.setStakerRewardsDistributor(address(vault), address(defaultStakerRewards));
        assertEq(
            SdkMiddlewareReader(address(distributor)).stakerRewardsDistributors(address(vault)),
            address(defaultStakerRewards)
        );
        vm.prank(alice);
        distributor.resetStakerRewardsDistributor(address(vault));
        assertEq(SdkMiddlewareReader(address(distributor)).stakerRewardsDistributors(address(vault)), address(0));
    }

    function test_setOperatorRewardsDistributor_withoutRole() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(DefaultRewardsDistributor.setOperatorRewardsDistributor.selector)
            )
        );
        distributor.setOperatorRewardsDistributor(address(defaultOperatorRewards));
    }

    function test_setOperatorRewardsDistributor_zeroDistributor() external {
        vm.expectRevert(BaseDefaultOperatorRewardsManager.ZeroDistributor.selector);
        vm.prank(bob);
        distributor.setOperatorRewardsDistributor(address(0));
    }

    function test_setOperatorRewardsDistributor_initial_changing_removing() external {
        assertEq(
            address(SdkMiddlewareReader(address(distributor)).operatorRewardsDistributor()),
            address(defaultOperatorRewards)
        );
        defaultOperatorRewards = createDefaultOperatorRewards();
        vm.prank(bob);
        distributor.setOperatorRewardsDistributor(address(defaultOperatorRewards));
        assertEq(
            address(SdkMiddlewareReader(address(distributor)).operatorRewardsDistributor()),
            address(defaultOperatorRewards)
        );
    }
}
