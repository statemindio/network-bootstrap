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
import {ChainlinkPriceAdapter} from "../src/prices/adapters/ChainlinkPriceAdapter.sol";
import {PriceProvider} from "../src/prices/PriceProvider.sol";
import {ValueActiveStakeWeightProvider} from "../src/weights/ValueActiveStakeWeightProvider.sol";

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

    PriceProvider priceProvider;

    address collateral_uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // uni
    address collateral_dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // dai

    uint256 mainnetFork;

    function setUp() public override {
        super.setUp();

        uint256 blockNumber = 21_569_588;
        mainnetFork = blockNumber == 0
            ? vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"))
            : vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"), blockNumber);
        vm.selectFork(mainnetFork);

        deal(collateral_uni, user, 10_000e18);
        deal(collateral_dai, user, 10_000e18);

        (vault1, delegator1, slasher1) = createVaultWithSlasher(collateral_uni);
        (vault2, delegator2, slasher2) = createVaultWithSlasher(collateral_dai);

        // deposit to vault1 and vault2
        vm.startPrank(user);
        IERC20(collateral_uni).approve(vault1, 26_521_893_463_350_816_768);
        IVault(vault1).deposit(user, 26_521_893_463_350_816_768);
        IERC20(collateral_dai).approve(vault2, 100_008_520_725_965_864_960);
        IVault(vault2).deposit(user, 100_008_520_725_965_864_960);
        vm.stopPrank();

        reader = address(new SdkMiddlewareReader());

        // create price adapters
        ChainlinkPriceAdapter priceAdapterUni =
            new ChainlinkPriceAdapter(0x553303d460EE0afB37EdFf9bE42922D8FF63220e, 24 hours, makeAddr("USD")); // USDT/USD
        ChainlinkPriceAdapter priceAdapterDai =
            new ChainlinkPriceAdapter(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9, 24 hours, makeAddr("USD")); // DAI/USD

        // create price priceProvider
        address[] memory tokens = new address[](2);
        tokens[0] = collateral_uni;
        tokens[1] = collateral_dai;

        address[] memory adapters = new address[](2);
        adapters[0] = address(priceAdapterUni);
        adapters[1] = address(priceAdapterDai);

        priceProvider = new PriceProvider(tokens, adapters, makeAddr("USD"), address(this));

        // create weightProviders
        vaultWeightProvider = address(new ValueActiveStakeWeightProvider(address(priceProvider), 18));
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
            address(this),
            address(priceProvider)
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

        bytes[] memory priceProviderData = new bytes[](2);
        priceProviderData[0] = abi.encode(129_127_208_515_966_865_783);
        priceProviderData[1] = abi.encode(129_127_208_515_966_863_933);

        WPDataComposer.ValueWPDataParams memory vaultWpDataParams =
            WPDataComposer.ValueWPDataParams({activeStakeAtHints: new bytes[](2), priceProviderData: priceProviderData});

        bytes[] memory subnetworksWpDataParams = new bytes[](2);

        WPDataComposer.SubnetworkDelegatorStakeWPDataParams memory subnetworkWpDataParams =
            WPDataComposer.SubnetworkDelegatorStakeWPDataParams({stakeHints: new bytes[](2)});
        subnetworksWpDataParams[0] = abi.encode(subnetworkWpDataParams);
        subnetworksWpDataParams[1] = abi.encode(subnetworkWpDataParams);

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

        uint256 collateralPrice1 = priceProvider.getPrice(collateral_uni, priceProviderData[0]);
        uint256 collateralPrice2 = priceProvider.getPrice(collateral_dai, priceProviderData[1]);

        uint256 vault1SlashAmount = activeStakeVault1Before - activeStakeVault1After;
        uint256 vault1ConvertedSlashAmount =
            vault1SlashAmount * collateralPrice1 / 10 ** priceProvider.decimals(collateral_uni);

        uint256 vault2SlashAmount = activeStakeVault2Before - activeStakeVault2After;
        uint256 vault2ConvertedSlashAmount =
            vault2SlashAmount * collateralPrice2 / 10 ** priceProvider.decimals(collateral_dai);

        // assertEq(vault1ConvertedSlashAmount + vault2ConvertedSlashAmount, slashAmount);
        assertApproxEqAbs(vault1ConvertedSlashAmount + vault2ConvertedSlashAmount, slashAmount, 20); // roundings...
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
        address priceProvider;
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
        __PriceProviderStorage_init(initializeParams.priceProvider);

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
