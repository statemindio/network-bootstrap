// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import "src/prices/PriceProvider.sol";
import "src/prices/adapters/RedstonePriceAdapter.sol";
import "src/prices/adapters/ChainlinkPriceAdapter.sol";
import "src/prices/adapters/TwoPathChainlinkAdapter.sol";
import "../src/interfaces/prices/IPriceAdapter.sol";
import "../src/interfaces/external/AggregatorV3Interface.sol";

contract PriceProviderTest is Test {
    address usde = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address lbtc = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address meth = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    ChainlinkPriceAdapter usdeAdapter;
    RedstonePriceAdapter lbtcAdapter;
    TwoPathChainlinkAdapter methAdapter;
    PriceProvider priceProvider;
    AggregatorV3Interface aggregator;

    address usdBaseCurrency = makeAddr("USD");

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        usdeAdapter = new ChainlinkPriceAdapter(0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961, 24 hours, usdBaseCurrency);
        lbtcAdapter = new RedstonePriceAdapter(bytes32("LBTC"), usdBaseCurrency, 3 minutes, 8);
        methAdapter = new TwoPathChainlinkAdapter(
            0x5b563107C8666d2142C216114228443B94152362,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            24 hours,
            24 hours,
            usdBaseCurrency
        );
        aggregator = AggregatorV3Interface(0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961);

        address[] memory assets = new address[](2);
        assets[0] = usde;
        assets[1] = lbtc;

        address[] memory adapters = new address[](2);
        adapters[0] = address(usdeAdapter);
        adapters[1] = address(lbtcAdapter);

        priceProvider = new PriceProvider(assets, adapters, usdBaseCurrency, address(this));
    }

    function getRedstonePayload(string memory priceFeed, uint256 timestamp) public returns (bytes memory) {
        string[] memory args = new string[](4);
        args[0] = "node";
        args[1] = "./test/scripts/getRedstonePayload.js";
        args[2] = priceFeed;
        args[3] = vm.toString(timestamp);

        return vm.ffi(args);
    }

    function getRedstonePrice(string memory priceFeed, uint256 timestamp) public returns (bytes memory) {
        string[] memory args = new string[](4);
        args[0] = "node";
        args[1] = "./test/scripts/getRedstonePrice.js";
        args[2] = priceFeed;
        args[3] = vm.toString(timestamp);

        return vm.ffi(args);
    }

    // Sometimes false-failed
    function test_GetLatestPriceUsingRedstoneAdapter() public {
        bytes memory redstonePayload = getRedstonePayload("LBTC", 0);
        bytes memory priceFromAPIData = getRedstonePrice("LBTC", 0);

        uint256 priceFromProvider = priceProvider.getPrice(lbtc, redstonePayload);
        uint256 priceFromApi = abi.decode(priceFromAPIData, (uint256));

        assertEq(priceFromProvider, priceFromApi);
    }

    function test_GetHistoricalPriceUsingRedstoneAdapter() public {
        uint256 timestamp = 1_731_499_200;
        bytes memory redstoneHistoricalPayload = getRedstonePayload("LBTC", timestamp);
        bytes memory redstoneHistoricalPrice = getRedstonePrice("LBTC", timestamp);

        uint256 historicalPriceFromProvider = priceProvider.getPriceAt(lbtc, timestamp, redstoneHistoricalPayload);
        uint256 historicalPriceFromAPI = abi.decode(redstoneHistoricalPrice, (uint256));

        assertEq(historicalPriceFromProvider, historicalPriceFromAPI);
    }

    function test_GetLatestPriceUsingChainlinkAdapter() public view {
        uint256 priceFromProvider = priceProvider.getPrice(usde, "");
        (, int256 answer,,,) = aggregator.latestRoundData();

        assertEq(priceFromProvider, uint256(answer));
    }

    function test_GetHistoricalPriceUsingChainlinkAdapter() public view {
        uint80 roundId = 36_893_488_147_419_103_362;
        bytes memory data = abi.encode(roundId);

        uint256 priceFromAdapter = priceProvider.getPriceAt(usde, 1_731_919_837, data);
        (, int256 answer,,,) = aggregator.getRoundData(roundId);

        assertEq(priceFromAdapter, uint256(answer));
    }

    function test_SetAdapter() public {
        address[] memory tokens = new address[](1);
        tokens[0] = meth;
        address[] memory adapters = new address[](1);
        adapters[0] = address(methAdapter);

        priceProvider.setAdapter(tokens, adapters);
        assertEq(priceProvider.adaptersRegistry(meth), address(methAdapter));
    }

    function test_SetAdapterMismatchedLength() public {
        address[] memory tokens = new address[](1);
        address[] memory adapters = new address[](0);

        vm.expectRevert(PriceProvider.MismatchedLength.selector);
        priceProvider.setAdapter(tokens, adapters);
    }

    function test_SetAdapterZeroToken() public {
        address[] memory tokens = new address[](1);
        address[] memory adapters = new address[](1);
        tokens[0] = address(0);
        adapters[0] = address(methAdapter);

        vm.expectRevert(PriceProvider.ZeroToken.selector);
        priceProvider.setAdapter(tokens, adapters);

        address baseCurrency = priceProvider.baseCurrency();
        console.log(baseCurrency);
    }

    function test_SetAdapterIncorrectAdapterBaseCurrency() public {
        ChainlinkPriceAdapter ethMethAdapter =
            new ChainlinkPriceAdapter(0x5b563107C8666d2142C216114228443B94152362, 24 hours, address(2));
        address[] memory tokens = new address[](1);
        address[] memory adapters = new address[](1);
        tokens[0] = meth;
        adapters[0] = address(ethMethAdapter);
        vm.expectRevert(PriceProvider.IncorrectAdapterBaseCurrency.selector);
        priceProvider.setAdapter(tokens, adapters);
    }
}
