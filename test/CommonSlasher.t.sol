// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "./helpers/VaultBase.t.sol";
import "forge-std/Test.sol";
import {CommonSlasherRoles} from "../src/extensions/slashers/CommonSlasherRoles.sol";
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
import {AmountActiveStakeWeightProvider} from "../src/weights/AmountActiveStakeWeightProvider.sol";
import {CommonSlasher} from "../src/managers/slashers/CommonSlasher.sol";
import {INetworkRestakeDelegator} from "@symbioticfi/core/src/interfaces/delegator/INetworkRestakeDelegator.sol";

contract CommonSlasherTest is VaultBaseTest {
    using Subnetwork for bytes32;
    using Subnetwork for address;

    address vault1;
    address slasher1;
    address delegator1;

    address vault2;
    address slasher2;
    address delegator2;

    TestCommonSlasherMiddleware middleware;

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

    address vaultWeightProvider;
    address subnetworkWeightProvider;

    function setUp() public override {
        super.setUp();

        (vault1, delegator1, slasher1) = createVaultWithSlasher(address(collateral));
        (vault2, delegator2, slasher2) = createVaultWithSlasher(address(collateral));

        // deposit to vault1 and vault2
        collateral.mint(user, 10_000e18);
        vm.startPrank(user);
        collateral.approve(vault1, 100e18);
        IVault(vault1).deposit(user, 100e18);
        collateral.approve(vault2, 400e18);
        IVault(vault2).deposit(user, 400e18);
        vm.stopPrank();

        reader = address(new SdkMiddlewareReader());

        vaultWeightProvider = address(new AmountActiveStakeWeightProvider());
        subnetworkWeightProvider = address(new SubnetworkDelegatorStakeWeightProvider());

        TestCommonSlasherMiddleware.InitializeParams memory initializeParams = TestCommonSlasherMiddleware
            .InitializeParams(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            epochDuration,
            vaultWeightProvider,
            subnetworkWeightProvider,
            address(this)
        );

        middleware = new TestCommonSlasherMiddleware();
        middleware.initialize(initializeParams);

        // register network
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        networkMiddlewareService.setMiddleware(address(middleware));
        vm.stopPrank();

        // register subnetworks
        middleware.registerSubnetwork(subnetworkIdentifier1);

        // register shared vaults
        middleware.registerSharedVault(vault1);
        middleware.registerSharedVault(vault2);

        // register operator
        vm.startPrank(operator);
        operatorRegistry.registerOperator();
        operatorNetworkOptInService.optIn(network);
        operatorVaultOptInService.optIn(vault1);
        operatorVaultOptInService.optIn(vault2);
        vm.stopPrank();
        middleware.registerOperator(operator, operatorKey, address(0));

        // set subnetwork limit
        vm.startPrank(network);
        INetworkRestakeDelegator(delegator1).setMaxNetworkLimit(subnetworkIdentifier0, 100e18);
        INetworkRestakeDelegator(delegator1).setMaxNetworkLimit(subnetworkIdentifier1, 100e18);
        INetworkRestakeDelegator(delegator2).setMaxNetworkLimit(subnetworkIdentifier0, 400e18);
        INetworkRestakeDelegator(delegator2).setMaxNetworkLimit(subnetworkIdentifier1, 400e18);
        vm.stopPrank();

        vm.startPrank(alice);
        INetworkRestakeDelegator(delegator1).setNetworkLimit(network.subnetwork(subnetworkIdentifier0), 100e18);
        INetworkRestakeDelegator(delegator1).setNetworkLimit(network.subnetwork(subnetworkIdentifier1), 100e18);
        INetworkRestakeDelegator(delegator2).setNetworkLimit(network.subnetwork(subnetworkIdentifier0), 400e18);
        INetworkRestakeDelegator(delegator2).setNetworkLimit(network.subnetwork(subnetworkIdentifier1), 400e18);

        // set operator network shares
        INetworkRestakeDelegator(delegator1).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier0), operator, 1e18
        );
        INetworkRestakeDelegator(delegator1).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier1), operator, 1e18
        );
        INetworkRestakeDelegator(delegator2).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier0), operator, 1e18
        );
        INetworkRestakeDelegator(delegator2).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier1), operator, 1e18
        );
        vm.stopPrank();
    }

    function test_CommonSlasher() public {
        vm.warp(block.timestamp + 2 * epochDuration + 1);

        uint256 activeStakeVault1Before = IVault(vault1).activeStake();
        uint256 activeStakeVault2Before = IVault(vault2).activeStake();

        uint256 slashAmount = 100e18;

        bytes[][] memory slashHints = new bytes[][](2);
        slashHints[0] = new bytes[](2);
        slashHints[1] = new bytes[](2);

        WPDataComposer.AmountWPDataParams memory vaultWpDataParams =
            WPDataComposer.AmountWPDataParams({activeStakeAtHints: new bytes[](2)});

        bytes[] memory subnetworksWpDataParams = new bytes[](2);

        WPDataComposer.SubnetworkDelegatorStakeWPDataParams memory subnetworkWpDataParams =
            WPDataComposer.SubnetworkDelegatorStakeWPDataParams({stakeHints: new bytes[](2)});
        subnetworksWpDataParams[0] = abi.encode(subnetworkWpDataParams);
        subnetworksWpDataParams[1] = abi.encode(subnetworkWpDataParams);

        bytes[] memory priceProviderData = new bytes[](2);

        CommonSlasher.SlashParams memory slashParams = CommonSlasher.SlashParams({
            timestamp: uint48(block.timestamp) - 1,
            key: operatorKey,
            amount: slashAmount,
            slashHints: slashHints,
            vaultWPDataParams: abi.encode(vaultWpDataParams),
            subnetworksWPDataParams: subnetworksWpDataParams,
            priceProviderData: priceProviderData
        });

        middleware.slash(slashParams);

        vm.warp(block.timestamp + 2 * epochDuration + 1);
        uint256 activeStakeVault1After = IVault(vault1).activeStake();
        uint256 activeStakeVault2After = IVault(vault2).activeStake();

        assertEq(activeStakeVault1After, activeStakeVault1Before - 20e18);
        assertEq(activeStakeVault2After, activeStakeVault2Before - 80e18);
    }
}

contract TestCommonSlasherMiddleware is
    CommonSlasherRoles,
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
        address vaultWeightProvider;
        address subnetworkWeightProvider;
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

        __SlashSubnetworkWeightProviderStorage_init(initializeParams.subnetworkWeightProvider);
        __SlashVaultWeightProviderStorage_init(initializeParams.vaultWeightProvider);
        __CommonSlasherRoles_init(initializeParams.slasher);

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
