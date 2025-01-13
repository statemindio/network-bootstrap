// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {PriceProvider} from "../src/prices/PriceProvider.sol";
import {ChainlinkPriceAdapter} from "../src/prices/adapters/ChainlinkPriceAdapter.sol";
import {RedstonePriceAdapter} from "../src/prices/adapters/RedstonePriceAdapter.sol";
import {TwoPathChainlinkAdapter} from "../src/prices/adapters/TwoPathChainlinkAdapter.sol";
import {ValueActiveStakeWeightProvider} from "../src/weights/ValueActiveStakeWeightProvider.sol";
import {VaultBaseTest} from "./helpers/VaultBase.t.sol";
import {MockVault} from "./mocks/MockVault.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV2V3Interface} from "src/interfaces/external/AggregatorV3Interface.sol";
import {console2} from "forge-std/console2.sol";

contract ValueActiveStakeWeightProviderTest is VaultBaseTest {
    address link = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address wBtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address aave = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    ChainlinkPriceAdapter linkUsdAdapter;
    TwoPathChainlinkAdapter wBtcBtcUsdAdapter;
    ChainlinkPriceAdapter aaveUsdAdapter;

    PriceProvider priceProvider;

    IVault public vault_1;
    IVault public vault_2;

    ValueActiveStakeWeightProvider public vwProvider;

    uint256 mainnetFork;

    address usdBaseCurrency = makeAddr("USD");

    function setUp() public override {
        super.setUp();
        mainnetFork = vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        linkUsdAdapter = new ChainlinkPriceAdapter(0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c, 3600, usdBaseCurrency);
        aaveUsdAdapter = new ChainlinkPriceAdapter(0x547a514d5e3769680Ce22B2361c10Ea13619e8a9, 3600, usdBaseCurrency);
        wBtcBtcUsdAdapter = new TwoPathChainlinkAdapter(
            0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23,
            0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            86_400,
            3600,
            usdBaseCurrency
        );

        address[] memory assets = new address[](3);
        assets[0] = link;
        assets[1] = wBtc;
        assets[2] = aave;

        address[] memory adapters = new address[](3);
        adapters[0] = address(linkUsdAdapter);
        adapters[1] = address(wBtcBtcUsdAdapter);
        adapters[2] = address(aaveUsdAdapter);

        priceProvider = new PriceProvider(assets, adapters, usdBaseCurrency, address(this));

        vwProvider = new ValueActiveStakeWeightProvider(address(priceProvider), 18);
    }

    function testGetWeightsAndTotal1_singleEntity_emptyStake() public {
        vault_1 = IVault(createVaultWithCollateral(link));

        assertEq(vault_1.activeStake(), 0);

        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: uint48(block.timestamp),
            activeStakeAtHints: new bytes[](1),
            priceProviderData: new bytes[](1)
        });
        data.priceProviderData[0] = abi.encode(uint80(129_127_208_515_966_863_549));

        bytes32[] memory entities = new bytes32[](1);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));

        (uint256[] memory weights, uint256 totalWeight) = vwProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 1);
        assertEq(weights[0], 0);
        assertEq(totalWeight, 0);
    }

    function testGetWeightsAndTotal1_multiplyEntities_emptyStake() public {
        vault_1 = IVault(createVaultWithCollateral(link));
        vault_2 = IVault(createVaultWithCollateral(wBtc));
        assertEq(vault_1.activeStake(), 0);
        assertEq(vault_2.activeStake(), 0);

        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: type(uint48).max, // 2st condition for get last active stake
            activeStakeAtHints: new bytes[](2),
            priceProviderData: new bytes[](2)
        });
        data.priceProviderData[0] = abi.encode(uint80(129_127_208_515_966_862_000));
        data.priceProviderData[1] = abi.encode(uint80(129_127_208_515_966_863_549), uint80(129_127_208_515_966_863_695));
        // hints empty

        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));
        entities[1] = bytes32(uint256(uint160(address(vault_2))));

        (uint256[] memory weights, uint256 totalWeight) = vwProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 2);
        assertEq(weights[0], 0);
        assertEq(weights[1], 0);
        assertEq(totalWeight, 0);
    }

    function testGetWeightsAndTotal1_multiplyEntities_nonEmptyStake_121(uint256 depAm1, uint256 depAm2) public {
        vault_1 = IVault(createVaultWithCollateral(link));
        vault_2 = IVault(createVaultWithCollateral(aave));
        assertEq(vault_1.activeStake(), 0);
        assertEq(vault_2.activeStake(), 0);

        depAm1 = bound(depAm1, 1, 1e18);
        depAm2 = bound(depAm2, 1, 1e18);

        AggregatorV2V3Interface aggregator = AggregatorV2V3Interface(linkUsdAdapter.priceFeed());
        (, int256 answer1,, uint256 updatedAt1,) = aggregator.getRoundData(129_127_208_515_966_863_573);
        aggregator = AggregatorV2V3Interface(aaveUsdAdapter.priceFeed());
        (, int256 answer2,, /*uint256 updatedAt2*/,) = aggregator.getRoundData(92_233_720_368_547_760_521);

        vm.warp(updatedAt1 - 1);
        deal(link, address(this), depAm1);
        IERC20(link).approve(address(vault_1), depAm1);
        vault_1.deposit(address(this), depAm1);
        deal(aave, address(this), depAm2);
        IERC20(aave).approve(address(vault_2), depAm2);
        vault_2.deposit(address(this), depAm2);
        vm.warp(updatedAt1 + 1);

        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: uint48(updatedAt1),
            activeStakeAtHints: new bytes[](2),
            priceProviderData: new bytes[](2)
        });
        data.priceProviderData[0] = abi.encode(uint80(129_127_208_515_966_863_573));
        data.priceProviderData[1] = abi.encode(uint80(92_233_720_368_547_760_521));
        // hints empty

        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));
        entities[1] = bytes32(uint256(uint160(address(vault_2))));

        (uint256[] memory weights, uint256 totalWeight) = vwProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 2);
        uint256 value1 = depAm1 * uint256(answer1);
        assertEq(weights[0], value1);
        uint256 value2 = depAm2 * uint256(answer2);
        assertEq(weights[1], value2);
        assertEq(totalWeight, value1 + value2);
    }

    function testGetWeightsAndTotal1_multiplyEntities_nonEmptyStake_beforeDep1(uint256 depAm1, uint256 depAm2) public {
        vault_1 = IVault(createVaultWithCollateral(link));
        vault_2 = IVault(createVaultWithCollateral(aave));
        assertEq(vault_1.activeStake(), 0);
        assertEq(vault_2.activeStake(), 0);

        depAm1 = bound(depAm1, 1, 1e18);
        depAm2 = bound(depAm2, 1, 1e18);

        AggregatorV2V3Interface aggregator = AggregatorV2V3Interface(linkUsdAdapter.priceFeed());
        (, int256 answer1,, uint256 updatedAt1,) = aggregator.getRoundData(129_127_208_515_966_863_573);

        vm.warp(updatedAt1);
        deal(link, address(this), depAm1);
        IERC20(link).approve(address(vault_1), depAm1);
        vault_1.deposit(address(this), depAm1);
        vm.warp(updatedAt1 + 1); // depositTime + 1
        deal(aave, address(this), depAm2);
        IERC20(aave).approve(address(vault_2), depAm2);
        vault_2.deposit(address(this), depAm2);

        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: uint48(updatedAt1), // надо разобраться
            activeStakeAtHints: new bytes[](2),
            priceProviderData: new bytes[](2)
        });
        data.priceProviderData[0] = abi.encode(uint80(129_127_208_515_966_863_573));
        data.priceProviderData[1] = abi.encode(uint80(92_233_720_368_547_760_521));
        // hints empty

        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));
        entities[1] = bytes32(uint256(uint160(address(vault_2))));

        (uint256[] memory weights, uint256 totalWeight) = vwProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 2);
        uint256 value1 = depAm1 * uint256(answer1);
        assertEq(weights[0], value1);
        assertEq(weights[1], 0);
        assertEq(totalWeight, value1);
    }

    function testGetWeightsAndTotal1_InvalidTimestamp() external {
        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: 0,
            activeStakeAtHints: new bytes[](1),
            priceProviderData: new bytes[](1)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](1);
        entities[0] = bytes32(uint256(uint160(address(this))));

        vm.expectRevert(ValueActiveStakeWeightProvider.InvalidTimestamp.selector);
        vwProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function testGetWeightsAndTotal1_EmptyEntities() external {
        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: 1,
            activeStakeAtHints: new bytes[](1),
            priceProviderData: new bytes[](1)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](0);

        vm.expectRevert(ValueActiveStakeWeightProvider.EmptyEntities.selector);
        vwProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function testGetWeightsAndTotal1_InvalidData() external {
        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: 1,
            activeStakeAtHints: new bytes[](1),
            priceProviderData: new bytes[](1)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](2);

        vm.expectRevert(ValueActiveStakeWeightProvider.InvalidData.selector);
        vwProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function testGetWeightsAndTotal1_zeroCollateral() public {
        _testGetWeightsAndTotal_zeroCollateral(0);
        _testGetWeightsAndTotal_zeroCollateral(1);
        _testGetWeightsAndTotal_zeroCollateral(2);
        _testGetWeightsAndTotal_zeroCollateral(3);
        _testGetWeightsAndTotal_zeroCollateral(4);
        _testGetWeightsAndTotal_zeroCollateral(5);
    }

    function _testGetWeightsAndTotal_zeroCollateral(uint256 vaultNumber) internal {
        address v1 = _createMockVaultWithCollateral(vaultNumber == 0 ? address(0) : address(link));
        address v2 = _createMockVaultWithCollateral(vaultNumber == 1 ? address(0) : address(link));
        address v3 = _createMockVaultWithCollateral(vaultNumber == 2 ? address(0) : address(link));
        address v4 = _createMockVaultWithCollateral(vaultNumber == 3 ? address(0) : address(link));
        address v5 = _createMockVaultWithCollateral(vaultNumber == 4 ? address(0) : address(link));
        address v6 = _createMockVaultWithCollateral(vaultNumber == 5 ? address(0) : address(link));

        ValueActiveStakeWeightProvider.ValueWPData memory data = ValueActiveStakeWeightProvider.ValueWPData({
            timestamp: uint48(block.timestamp),
            activeStakeAtHints: new bytes[](6),
            priceProviderData: new bytes[](6)
        });
        data.priceProviderData[0] = abi.encode(uint80(129_127_208_515_966_863_549));
        data.priceProviderData[1] = abi.encode(uint80(129_127_208_515_966_863_549));
        data.priceProviderData[2] = abi.encode(uint80(129_127_208_515_966_863_549));
        data.priceProviderData[3] = abi.encode(uint80(129_127_208_515_966_863_549));
        data.priceProviderData[4] = abi.encode(uint80(129_127_208_515_966_863_549));
        data.priceProviderData[5] = abi.encode(uint80(129_127_208_515_966_863_549));
        // hints empty

        bytes32[] memory entities = new bytes32[](6);
        entities[0] = bytes32(uint256(uint160(v1)));
        entities[1] = bytes32(uint256(uint160(v2)));
        entities[2] = bytes32(uint256(uint160(v3)));
        entities[3] = bytes32(uint256(uint160(v4)));
        entities[4] = bytes32(uint256(uint160(v5)));
        entities[5] = bytes32(uint256(uint160(v6)));

        vm.expectRevert(ValueActiveStakeWeightProvider.InvalidVaultCollateral.selector);
        vwProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function _createMockVaultWithCollateral(address collateral) internal returns (address) {
        MockVault vault = new MockVault();
        vault.setCollateral(collateral);
        return address(vault);
    }
}
