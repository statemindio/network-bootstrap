// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "./helpers/VaultBase.t.sol";
import "forge-std/Test.sol";
import {FlexibleSlasherRoles} from "../src/extensions/slashers/FlexibleSlasherRoles.sol";
import {FlexibleSlasher} from "../src/managers/slashers/FlexibleSlasher.sol";
import {BaseSlasher} from "../src/managers/slashers/BaseSlasher.sol";

import {Subnetworks} from "@symbioticfi/middleware-sdk/extensions/Subnetworks.sol";
import {Operators} from "@symbioticfi/middleware-sdk/extensions/operators/Operators.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {KeyManager256} from "@symbioticfi/middleware-sdk/extensions/managers/keys/KeyManager256.sol";
import {SharedVaults} from "@symbioticfi/middleware-sdk/extensions/SharedVaults.sol";
import {EpochCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/EpochCapture.sol";
import {IOzAccessControl} from "@symbioticfi/middleware-sdk/interfaces/extensions/managers/access/IOzAccessControl.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";

contract FlexibleSlasherTest is VaultBaseTest {
    using Subnetwork for bytes32;
    using Subnetwork for address;

    address vault1;
    address slasher1;
    address delegator1;

    address vault2;
    address slasher2;
    address delegator2;

    TestFlexibleSlasherMiddleware middleware;

    uint48 internal slashingWindow = 1800;
    uint48 internal epochDuration = 3600;
    address defaultAdmin = makeAddr("defaultAdmin");
    address network = makeAddr("network");
    address operator = makeAddr("operator");
    bytes operatorKey = hex"0000000000000000000000000000000000000000000000000000000000000005";
    address slasherRole = makeAddr("slasherRole");
    address reader;

    address user = makeAddr("user");
    uint96 subnetworkIdentifier = 1;

    function setUp() public override {
        super.setUp();

        // create vault with slasher
        (vault1, delegator1, slasher1) = createVaultWithSlasher(address(collateral));
        (vault2, delegator2, slasher2) = createVaultWithSlasher(address(collateral));

        // deposit to vaults
        collateral.mint(user, 10_000e18);
        vm.startPrank(user);
        collateral.approve(vault1, 100e18);
        IVault(vault1).deposit(user, 100e18);
        collateral.approve(vault2, 200e18);
        IVault(vault2).deposit(user, 200e18);
        vm.stopPrank();

        reader = address(new SdkMiddlewareReader());

        // create middleware
        TestFlexibleSlasherMiddleware.InitializeParams memory initializeParams = TestFlexibleSlasherMiddleware
            .InitializeParams(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            epochDuration,
            address(this)
        );

        middleware = new TestFlexibleSlasherMiddleware();
        middleware.initialize(initializeParams);

        // register network
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        networkMiddlewareService.setMiddleware(address(middleware));
        vm.stopPrank();

        // register subnetwork
        middleware.registerSubnetwork(subnetworkIdentifier);

        // register shared vault
        middleware.registerSharedVault(address(vault1));
        middleware.registerSharedVault(address(vault2));

        // register operator
        vm.startPrank(operator);
        operatorRegistry.registerOperator();
        operatorNetworkOptInService.optIn(network);
        operatorVaultOptInService.optIn(address(vault1));
        operatorVaultOptInService.optIn(address(vault2));
        vm.stopPrank();
        middleware.registerOperator(operator, operatorKey, address(0));

        // set network limit
        vm.startPrank(network);
        INetworkRestakeDelegator(delegator1).setMaxNetworkLimit(1, 100e18);
        INetworkRestakeDelegator(delegator2).setMaxNetworkLimit(1, 200e18);
        vm.stopPrank();

        vm.startPrank(alice);
        INetworkRestakeDelegator(delegator1).setNetworkLimit(network.subnetwork(subnetworkIdentifier), 100e18);
        // set operator network shares
        INetworkRestakeDelegator(delegator1).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier), operator, 100e18
        );
        INetworkRestakeDelegator(delegator2).setNetworkLimit(network.subnetwork(subnetworkIdentifier), 200e18);
        // set operator network shares
        INetworkRestakeDelegator(delegator2).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier), operator, 200e18
        );
        vm.stopPrank();
    }

    function test_FlexibleSlasherSuccess() public {
        vm.warp(block.timestamp + 2 * epochDuration + 1);

        // slash first vault
        uint256 activeStakeBefore = IVault(vault1).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        middleware.slash(
            uint48(block.timestamp) - 1, operatorKey, slashAmount, vault1, network.subnetwork(subnetworkIdentifier), ""
        );

        uint256 activeStakeAfter = IVault(vault1).activeStake();
        assertEq(activeStakeAfter, activeStakeBefore - slashAmount);

        // slash second vault
        activeStakeBefore = IVault(vault2).activeStake();
        slashAmount = activeStakeBefore / 3;

        middleware.slash(
            uint48(block.timestamp) - 1, operatorKey, slashAmount, vault2, network.subnetwork(subnetworkIdentifier), ""
        );
        activeStakeAfter = IVault(vault2).activeStake();
        assertEq(activeStakeAfter, activeStakeBefore - slashAmount);
    }

    function test_FlexibleSlasher_NotExistKeySlashError() public {
        vm.warp(block.timestamp + epochDuration + 1);
        uint256 activeStakeBefore = IVault(vault1).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        vm.expectRevert(BaseSlasher.NotExistKeySlash.selector);
        middleware.slash(
            uint48(block.timestamp) - 1,
            hex"0000000000000000000000000000000000000000000000000000000000000004",
            slashAmount,
            vault1,
            network.subnetwork(subnetworkIdentifier),
            ""
        );
    }

    function test_FlexibleSlasher_InactiveKeySlashError() public {
        uint256 activeStakeBefore = IVault(vault1).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        vm.expectRevert(BaseSlasher.InactiveKeySlash.selector);
        middleware.slash(
            uint48(block.timestamp) - 1, operatorKey, slashAmount, vault1, network.subnetwork(subnetworkIdentifier), ""
        );
    }

    function test_FlexibleSlasher_InactiveOperatorSlashError() public {
        vm.warp(block.timestamp + epochDuration + 1);
        uint256 activeStakeBefore = IVault(vault1).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        middleware.pauseOperator(operator);
        vm.warp(block.timestamp + 10);
        vm.expectRevert(BaseSlasher.InactiveOperatorSlash.selector);
        middleware.slash(
            uint48(block.timestamp) - 1, operatorKey, slashAmount, vault1, network.subnetwork(subnetworkIdentifier), ""
        );
    }

    function test_FlexibleSlasher_CheckAccessError() public {
        vm.warp(block.timestamp + 2 * epochDuration + 1);

        // slash first vault
        uint256 activeStakeBefore = IVault(vault1).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        bytes4 selector = FlexibleSlasher.slash.selector;

        vm.expectRevert(
            abi.encodeWithSelector(IOzAccessControl.AccessControlUnauthorizedAccount.selector, user, selector)
        );
        vm.prank(user);
        middleware.slash(
            uint48(block.timestamp) - 1, operatorKey, slashAmount, vault1, network.subnetwork(subnetworkIdentifier), ""
        );
    }
}

contract TestFlexibleSlasherMiddleware is
    FlexibleSlasherRoles,
    Subnetworks,
    Operators,
    SharedVaults,
    KeyManager256,
    TimestampCapture
{
    struct InitializeParams {
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptIn;
        address reader;
        uint48 epochDuration;
        address slasher;
    }

    function initialize(InitializeParams memory initializeParams) public initializer {
        __BaseMiddleware_init(
            initializeParams.network,
            initializeParams.slashingWindow,
            initializeParams.vaultRegistry,
            initializeParams.operatorRegistry,
            initializeParams.operatorNetOptIn,
            initializeParams.reader
        );

        __FlexibleSlasherRoles_init(initializeParams.slasher);

        bytes4 registerSubnetworkSelector = Subnetworks.registerSubnetwork.selector;
        _setSelectorRole(registerSubnetworkSelector, registerSubnetworkSelector);
        _grantRole(registerSubnetworkSelector, initializeParams.slasher);

        bytes4 registerSharedVaultSelector = SharedVaults.registerSharedVault.selector;
        _setSelectorRole(registerSharedVaultSelector, registerSharedVaultSelector);
        _grantRole(registerSharedVaultSelector, initializeParams.slasher);

        bytes4 registerOperatorSelector = Operators.registerOperator.selector;
        _setSelectorRole(registerOperatorSelector, registerOperatorSelector);
        _grantRole(registerOperatorSelector, initializeParams.slasher);

        bytes4 pauseOperatorSelector = Operators.pauseOperator.selector;
        _setSelectorRole(pauseOperatorSelector, pauseOperatorSelector);
        _grantRole(pauseOperatorSelector, initializeParams.slasher);
    }

    function stakeToPower(address vault, uint256 stake) public view override returns (uint256 power) {}
}
