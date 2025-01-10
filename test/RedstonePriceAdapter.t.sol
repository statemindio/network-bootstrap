// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "src/prices/adapters/RedstonePriceAdapter.sol";

contract RedstonePriceAdapterTest is Test {
    RedstonePriceAdapter adapter;
    address usdBaseCurrency = makeAddr("USD");

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        adapter = new RedstonePriceAdapter(bytes32("LBTC"), usdBaseCurrency, 3 minutes, 8);
    }

    function getRedstonePayload(
        // dataFeedId
        string memory priceFeed,
        uint256 timestamp
    ) public returns (bytes memory) {
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

    function test_RedstoneAdapterCorrectLatestPrice() public {
        bytes memory redstonePayload = getRedstonePayload("LBTC", 0);
        bytes memory priceFromAPIData = getRedstonePrice("LBTC", 0);

        uint256 priceFromAdapter = adapter.getPrice(redstonePayload);
        uint256 priceFromApi = abi.decode(priceFromAPIData, (uint256));

        assertEq(priceFromAdapter, priceFromApi);
    }

    function test_RedstoneAdapterCorrectHistoricalPrice() public {
        uint256 timestamp = 1_731_499_200;
        bytes memory redstoneHistoricalPayload = getRedstonePayload("LBTC", timestamp);
        bytes memory redstoneHistoricalPrice = getRedstonePrice("LBTC", timestamp);

        uint256 historicalPriceFromAdapter = adapter.getPriceAt(timestamp, redstoneHistoricalPayload);
        uint256 historicalPriceFromAPI = abi.decode(redstoneHistoricalPrice, (uint256));

        assertEq(historicalPriceFromAdapter, historicalPriceFromAPI);
    }

    function test_RedstoneAdapterIncorrectHistoricalPrice() public {
        bytes memory redstoneHistoricalPayload = getRedstonePayload("LBTC", 1_731_499_200);
        uint256 timestamp = 1_731_499_381;
        vm.expectRevert(RedstonePriceAdapter.IncorrectHistoricalData.selector);
        adapter.getPriceAt(timestamp, redstoneHistoricalPayload);
    }
}
