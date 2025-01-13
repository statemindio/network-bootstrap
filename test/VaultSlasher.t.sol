// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "./helpers/VaultBase.t.sol";
import "forge-std/Test.sol";
import {VaultSlasherRoles} from "../src/extensions/slashers/VaultSlasherRoles.sol";
import {VaultSlasher} from "../src/managers/slashers/VaultSlasher.sol";
import {BaseSlasher} from "../src/managers/slashers/BaseSlasher.sol";

import {Subnetworks} from "@symbioticfi/middleware-sdk/extensions/Subnetworks.sol";
import {Operators} from "@symbioticfi/middleware-sdk/extensions/operators/Operators.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {KeyManager256} from "@symbioticfi/middleware-sdk/extensions/managers/keys/KeyManager256.sol";
import {SharedVaults} from "@symbioticfi/middleware-sdk/extensions/SharedVaults.sol";
import {SubnetworkDelegatorStakeWeightProvider} from "../src/weights/SubnetworkDelegatorStakeWeightProvider.sol";
import {EpochCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/EpochCapture.sol";
import {WPDataComposer} from "../src/libs/WPDataComposer.sol";
import {IOzAccessControl} from "@symbioticfi/middleware-sdk/interfaces/extensions/managers/access/IOzAccessControl.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";

contract VaultSlasherTest is Test, VaultBaseTest {
    using Subnetwork for bytes32;
    using Subnetwork for address;

    address vault;
    address slasher;
    address delegator;

    TestVaultSlasherMiddleware middleware;

    uint48 internal slashingWindow = 1800;
    uint48 internal epochDuration = 3600;
    address defaultAdmin = makeAddr("defaultAdmin");
    address network = makeAddr("network");
    address operator = makeAddr("operator");
    bytes operatorKey = hex"0000000000000000000000000000000000000000000000000000000000000005";
    address slasherRole = makeAddr("slasherRole");
    address reader;

    address user = makeAddr("user");
    uint96 subnetworkIdentifier0 = 0;
    uint96 subnetworkIdentifier1 = 1;
    uint96 subnetworkIdentifier2 = 2;

    address weightProvider;

    function setUp() public override {
        super.setUp();

        // create vault with slasher
        (vault, delegator, slasher) = createVaultWithSlasher(address(collateral));

        // deposit to vault
        collateral.mint(user, 10_000e18);
        vm.startPrank(user);
        collateral.approve(vault, 100e18);
        IVault(vault).deposit(user, 100e18);
        vm.stopPrank();

        reader = address(new SdkMiddlewareReader());

        weightProvider = address(new SubnetworkDelegatorStakeWeightProvider());

        // create middleware
        TestVaultSlasherMiddleware.InitializeParams memory initializeParams = TestVaultSlasherMiddleware
            .InitializeParams(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            epochDuration,
            weightProvider,
            address(this)
        );
        middleware = new TestVaultSlasherMiddleware();
        middleware.initialize(initializeParams);

        // register network
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        networkMiddlewareService.setMiddleware(address(middleware));
        vm.stopPrank();

        // register subnetworks
        middleware.registerSubnetwork(subnetworkIdentifier1);
        middleware.registerSubnetwork(subnetworkIdentifier2);

        // register shared vault
        middleware.registerSharedVault(vault);

        // register operator
        vm.startPrank(operator);
        operatorRegistry.registerOperator();
        operatorNetworkOptInService.optIn(network);
        operatorVaultOptInService.optIn(vault);
        vm.stopPrank();
        middleware.registerOperator(operator, operatorKey, address(0));

        // set network limit
        vm.startPrank(network);
        INetworkRestakeDelegator(delegator).setMaxNetworkLimit(0, 100e18);
        INetworkRestakeDelegator(delegator).setMaxNetworkLimit(1, 100e18);
        INetworkRestakeDelegator(delegator).setMaxNetworkLimit(2, 100e18);
        vm.stopPrank();

        vm.startPrank(alice);
        INetworkRestakeDelegator(delegator).setNetworkLimit(network.subnetwork(subnetworkIdentifier0), 100e18);
        INetworkRestakeDelegator(delegator).setNetworkLimit(network.subnetwork(subnetworkIdentifier1), 50e18);
        INetworkRestakeDelegator(delegator).setNetworkLimit(network.subnetwork(subnetworkIdentifier2), 50e18);

        // set operator network shares
        INetworkRestakeDelegator(delegator).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier0), operator, 100e18
        );
        INetworkRestakeDelegator(delegator).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier1), operator, 100e18
        );
        INetworkRestakeDelegator(delegator).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier2), operator, 100e18
        );
        vm.stopPrank();
    }

    function test_VaultSlasher_SuccessSlash() public {
        vm.warp(block.timestamp * 2 * epochDuration + 1);

        uint256 activeStakeBefore = IVault(vault).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        bytes[] memory slashHints = new bytes[](3);
        WPDataComposer.SubnetworkDelegatorStakeWPDataParams memory wpDataParams =
            WPDataComposer.SubnetworkDelegatorStakeWPDataParams({stakeHints: new bytes[](3)});
        bytes memory wpData = abi.encode(wpDataParams);

        VaultSlasher.SlashParams memory slashParams =
            VaultSlasher.SlashParams(uint48(block.timestamp) - 1, operatorKey, slashAmount, vault, slashHints, wpData);
        middleware.slash(slashParams);
        uint256 activeStakeAfter = IVault(vault).activeStake();
        assert(activeStakeAfter == activeStakeBefore - slashAmount);
    }

    function test_VaultSlasher_CheckAccessError() public {
        vm.warp(block.timestamp * 2 * epochDuration + 1);
        uint256 activeStakeBefore = IVault(vault).activeStake();
        uint256 slashAmount = activeStakeBefore / 2;

        bytes[] memory slashHints = new bytes[](3);
        WPDataComposer.SubnetworkDelegatorStakeWPDataParams memory wpDataParams =
            WPDataComposer.SubnetworkDelegatorStakeWPDataParams({stakeHints: new bytes[](3)});
        bytes memory wpData = abi.encode(wpDataParams);

        VaultSlasher.SlashParams memory slashParams =
            VaultSlasher.SlashParams(uint48(block.timestamp) - 1, operatorKey, slashAmount, vault, slashHints, wpData);

        bytes4 selector = VaultSlasher.slash.selector;
        vm.expectRevert(
            abi.encodeWithSelector(IOzAccessControl.AccessControlUnauthorizedAccount.selector, user, selector)
        );
        vm.prank(user);
        middleware.slash(slashParams);
    }
}

contract TestVaultSlasherMiddleware is
    VaultSlasherRoles,
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
        address weightProvider;
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

        __SlashSubnetworkWeightProviderStorage_init(initializeParams.weightProvider);
        __VaultSlasherRoles_init(initializeParams.slasher);

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
