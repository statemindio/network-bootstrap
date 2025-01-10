// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "src/prices/adapters/TwoPathChainlinkAdapter.sol";

contract TwoPathChainlinkAdapterTest is Test {
    TwoPathChainlinkAdapter twoPathAdapter;
    AggregatorV2V3Interface aggregator1;
    AggregatorV2V3Interface aggregator2;

    address usdBaseCurrency = makeAddr("USD");

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        aggregator1 = AggregatorV2V3Interface(0x5b563107C8666d2142C216114228443B94152362);
        aggregator2 = AggregatorV2V3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        twoPathAdapter = new TwoPathChainlinkAdapter(
            0x5b563107C8666d2142C216114228443B94152362,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            24 hours,
            24 hours,
            usdBaseCurrency
        );
    }

    function test_ChainlinkAdapterLatestPrice() public view {
        uint256 priceFromAdapter = twoPathAdapter.getPrice("");
        (, int256 answer1,,,) = aggregator1.latestRoundData();
        (, int256 answer2,,,) = aggregator2.latestRoundData();

        uint256 combinePrice = uint256(answer1) * uint256(answer2) / 10 ** aggregator1.decimals();
        uint256 multiplier = 10
            ** (
                twoPathAdapter.decimals() > aggregator2.decimals()
                    ? twoPathAdapter.decimals() - aggregator2.decimals()
                    : aggregator2.decimals() - twoPathAdapter.decimals()
            );
        uint256 normalizedPrice =
            (twoPathAdapter.decimals() > aggregator2.decimals()) ? combinePrice * multiplier : combinePrice / multiplier;

        assertEq(priceFromAdapter, normalizedPrice);
    }

    function test_ChainlinkAdapterHistoricalPrice() public view {
        uint256 timestamp = 1_731_672_683;
        uint80 roundIdPriceFeed1 = 36_893_488_147_419_103_442;
        uint80 roundIdPriceFeed2 = 129_127_208_515_966_863_632;

        bytes memory data = abi.encode(roundIdPriceFeed1, roundIdPriceFeed2);
        uint256 priceFromAdapter = twoPathAdapter.getPriceAt(timestamp, data);

        (, int256 answer1,,,) = aggregator1.getRoundData(roundIdPriceFeed1);
        (, int256 answer2,,,) = aggregator2.getRoundData(roundIdPriceFeed2);

        uint256 combinePrice = uint256(answer1) * uint256(answer2) / 10 ** aggregator1.decimals();
        uint256 multiplier = 10
            ** (
                twoPathAdapter.decimals() > aggregator2.decimals()
                    ? twoPathAdapter.decimals() - aggregator2.decimals()
                    : aggregator2.decimals() - twoPathAdapter.decimals()
            );
        uint256 normalizedPrice =
            (twoPathAdapter.decimals() > aggregator2.decimals()) ? combinePrice * multiplier : combinePrice / multiplier;

        assertEq(priceFromAdapter, normalizedPrice);
    }

    function test_ChainlinkAdapterInvalidDataHistoricalPrice() public {
        uint256 timestamp = 1_731_672_683;
        uint80 roundIdPriceFeed1 = 36_893_488_147_419_103_440;
        uint80 roundIdPriceFeed2 = 129_127_208_515_966_863_632;

        bytes memory data = abi.encode(roundIdPriceFeed1, roundIdPriceFeed2);

        vm.expectRevert(BaseChainlinkPriceAdapter.InvalidHistoricalData.selector);
        twoPathAdapter.getPriceAt(timestamp, data);
    }

    function test_ChainlinkAdapterInvalidPhaseFuturePhase() public {
        uint256 timestamp = 1_731_672_683;
        uint80 roundIdPriceFeed1 = 184_448_993_993_021_806_608_384;
        uint80 roundIdPriceFeed2 = 129_127_208_515_966_863_632;

        bytes memory data = abi.encode(roundIdPriceFeed1, roundIdPriceFeed2);

        vm.expectRevert(BaseChainlinkPriceAdapter.InvalidPhaseId.selector);
        twoPathAdapter.getPriceAt(timestamp, data);
    }
}
