// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "./helpers/VaultBase.t.sol";
import "forge-std/Test.sol";
import {FlexibleSlasher} from "../src/managers/slashers/FlexibleSlasher.sol";
import {BaseSlasher} from "../src/managers/slashers/BaseSlasher.sol";

import {Subnetworks} from "@symbioticfi/middleware-sdk/extensions/Subnetworks.sol";
import {Operators} from "@symbioticfi/middleware-sdk/extensions/operators/Operators.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {KeyManager256} from "@symbioticfi/middleware-sdk/extensions/managers/keys/KeyManager256.sol";
import {SharedVaults} from "@symbioticfi/middleware-sdk/extensions/SharedVaults.sol";
import {SubnetworkSlasher} from "../src/managers/slashers/SubnetworkSlasher.sol";
import {VaultDelegatorStakeWeightProvider} from "../src/weights/VaultDelegatorStakeWeightProvider.sol";
import {EpochCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/EpochCapture.sol";
import {WPDataComposer} from "../src/libs/WPDataComposer.sol";
import {Token} from "./mocks/Token.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";
import {PriceProvider} from "../src/prices/PriceProvider.sol";
import {ChainlinkPriceAdapter} from "../src/prices/adapters/ChainlinkPriceAdapter.sol";
import {SubnetworkSlasherRoles} from "../src/extensions/slashers/SubnetworkSlasherRoles.sol";

contract SubnetworkSlasherTest is Test, VaultBaseTest {
    using Subnetwork for bytes32;
    using Subnetwork for address;

    address vault1;
    address slasher1;
    address delegator1;

    address vault2;
    address slasher2;
    address delegator2;
    address weightProvider;

    TestSubnetworkSlasherMiddleware middleware;

    uint48 internal slashingWindow = 1800;
    uint48 internal epochDuration = 3600;
    address defaultAdmin = makeAddr("defaultAdmin");
    address network = makeAddr("network");
    address operator = makeAddr("operator");
    bytes operatorKey = hex"0000000000000000000000000000000000000000000000000000000000000005";
    address slasherRole = makeAddr("slasherRole");
    address reader;

    address user = makeAddr("user");
    uint96 subnetworkIdentifier = 0;

    address collateral1 = 0x8dAEBADE922dF735c38C80C7eBD708Af50815fAa; // tbtc
    address collateral2 = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; // aave

    PriceProvider priceProvider;

    uint256 mainnetFork;

    function setUp() public override {
        super.setUp();

        uint256 blockNumber = 21_493_612;
        mainnetFork = blockNumber == 0
            ? vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"))
            : vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"), blockNumber);
        vm.selectFork(mainnetFork);

        deal(collateral1, user, 10_000e18);
        deal(collateral2, user, 10_000e18);

        // create vault with slasher
        (vault1, delegator1, slasher1) = createVaultWithSlasher(collateral1);
        (vault2, delegator2, slasher2) = createVaultWithSlasher(collateral2);

        // deposit to vaults
        vm.startPrank(user);
        IERC20(collateral1).approve(vault1, 10_430_022_409_079_482);
        IVault(vault1).deposit(user, 10_430_022_409_079_482);

        IERC20(collateral2).approve(vault2, 2_919_808_782_378_047_488);
        IVault(vault2).deposit(user, 2_919_808_782_378_047_488);
        vm.stopPrank();

        reader = address(new SdkMiddlewareReader());

        // create price adapters
        ChainlinkPriceAdapter priceAdapter1 =
            new ChainlinkPriceAdapter(0x8350b7De6a6a2C1368E7D4Bd968190e13E354297, 24 hours, makeAddr("USD")); // tBTC/USD
        ChainlinkPriceAdapter priceAdapter2 =
            new ChainlinkPriceAdapter(0x547a514d5e3769680Ce22B2361c10Ea13619e8a9, 24 hours, makeAddr("USD")); // AAVE/USD

        // create price provider
        address[] memory tokens = new address[](2);
        tokens[0] = collateral1;
        tokens[1] = collateral2;

        address[] memory adapters = new address[](2);
        adapters[0] = address(priceAdapter1);
        adapters[1] = address(priceAdapter2);

        priceProvider = new PriceProvider(tokens, adapters, makeAddr("USD"), address(this));

        weightProvider = address(new VaultDelegatorStakeWeightProvider(address(priceProvider)));

        // create middleware
        TestSubnetworkSlasherMiddleware.InitializeParams memory initializeParams = TestSubnetworkSlasherMiddleware
            .InitializeParams(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            epochDuration,
            weightProvider,
            address(priceProvider),
            address(this)
        );
        middleware = new TestSubnetworkSlasherMiddleware();
        middleware.initialize(initializeParams);

        // register network
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        networkMiddlewareService.setMiddleware(address(middleware));
        vm.stopPrank();

        // register shared vault
        middleware.registerSharedVault(vault1);
        middleware.registerSharedVault(vault2);

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
        INetworkRestakeDelegator(delegator1).setMaxNetworkLimit(0, 100e18); // 100 tbtc limit
        INetworkRestakeDelegator(delegator2).setMaxNetworkLimit(0, 100e18); // 100 aave limit
        vm.stopPrank();

        vm.startPrank(alice);
        INetworkRestakeDelegator(delegator1).setNetworkLimit(network.subnetwork(subnetworkIdentifier), 100e18);
        // set operator network shares
        INetworkRestakeDelegator(delegator1).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier), operator, 100e18
        );
        INetworkRestakeDelegator(delegator2).setNetworkLimit(network.subnetwork(subnetworkIdentifier), 100e18);
        // set operator network shares
        INetworkRestakeDelegator(delegator2).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier), operator, 100e18
        );
        vm.stopPrank();
    }

    function test_SubnetworkSlasher() public {
        vm.warp(block.timestamp + 1 * epochDuration + 1);

        uint256 vault1ActiveStakeBefore = IVault(vault1).activeStake();
        uint256 vault2ActiveStakeBefore = IVault(vault2).activeStake();

        uint256 slashAmount = 100e18;

        bytes[][] memory stakeHints = new bytes[][](2);
        stakeHints[0] = new bytes[](1);
        stakeHints[1] = new bytes[](1);

        bytes[] memory priceProviderData = new bytes[](2);
        priceProviderData[0] = abi.encode(36_893_488_147_419_103_570);
        priceProviderData[1] = abi.encode(92_233_720_368_547_762_101);
        WPDataComposer.VaultDelegatorStakeWPDataParams memory wpDataParams = WPDataComposer
            .VaultDelegatorStakeWPDataParams({stakeHints: stakeHints, priceProviderData: priceProviderData});
        bytes memory wpData = abi.encode(wpDataParams);
        bytes[] memory slashHints = new bytes[](2);

        SubnetworkSlasher.SlashParams memory slashParams = SubnetworkSlasher.SlashParams(
            uint48(block.timestamp) - 1,
            operatorKey,
            slashAmount,
            network.subnetwork(subnetworkIdentifier),
            slashHints,
            wpData,
            priceProviderData
        );

        middleware.slash(slashParams);

        uint256 collateralPrice1 = priceProvider.getPrice(collateral1, priceProviderData[0]);
        uint256 collateralPrice2 = priceProvider.getPrice(collateral2, priceProviderData[1]);

        uint256 vault1ActiveStakeAfter = IVault(vault1).activeStake();
        uint256 vault2ActiveStakeAfter = IVault(vault2).activeStake();

        uint256 vault1SlashAmount = vault1ActiveStakeBefore - vault1ActiveStakeAfter;
        uint256 vault1ConvertedSlashAmount =
            vault1SlashAmount * collateralPrice1 / 10 ** priceProvider.decimals(collateral1);

        uint256 vault2SlashAmount = vault2ActiveStakeBefore - vault2ActiveStakeAfter;
        uint256 vault2ConvertedSlashAmount =
            vault2SlashAmount * collateralPrice2 / 10 ** priceProvider.decimals(collateral2);

        // assertEq(vault1ConvertedSlashAmount + vault2ConvertedSlashAmount, slashAmount);
        assertApproxEqAbs(vault1ConvertedSlashAmount + vault2ConvertedSlashAmount, slashAmount, 1e4);
    }
}

contract TestSubnetworkSlasherMiddleware is
    SubnetworkSlasherRoles,
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
        address priceProvider;
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

        __SlashVaultWeightProviderStorage_init(initializeParams.weightProvider);
        __SubnetworkSlasherRoles_init(initializeParams.slasher);
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
