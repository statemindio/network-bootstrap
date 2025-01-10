// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "src/prices/adapters/ChainlinkPriceAdapter.sol";
import "../src/interfaces/external/AggregatorV3Interface.sol";

contract ChainlinkPriceAdapterTest is Test {
    ChainlinkPriceAdapter usdeUsdAdapter;
    AggregatorV2V3Interface usdeAggregator;
    AggregatorV2V3Interface ethAggregator;
    ChainlinkPriceAdapter ethUsdAdapter;

    address usdBaseCurrencyAddress = makeAddr("USD");

    uint256 mainnetFork;

    function _setUp(uint256 blockNumber) internal {
        mainnetFork = blockNumber == 0
            ? vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"))
            : vm.createFork(vm.envString("ETH_MAINNET_RPC_URL"), blockNumber);
        vm.selectFork(mainnetFork);

        usdeUsdAdapter =
            new ChainlinkPriceAdapter(0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961, 24 hours, usdBaseCurrencyAddress); // USDe/USD
        ethUsdAdapter =
            new ChainlinkPriceAdapter(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 24 hours, usdBaseCurrencyAddress);
        usdeAggregator = AggregatorV2V3Interface(0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961); // USDe/USD
        ethAggregator = AggregatorV2V3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // ETH/USD
    }

    function test_ChainlinkAdapterLatestPrice() public {
        _setUp(0);
        uint256 priceFromAdapter = usdeUsdAdapter.getPrice("");
        (, int256 answer,,,) = usdeAggregator.latestRoundData();

        assertEq(priceFromAdapter, uint256(answer));
    }

    function test_ChainlinkAdapterHistoricalPrice() public {
        _setUp(0);
        uint80 roundId = 36_893_488_147_419_103_362;
        bytes memory data = abi.encode(roundId);

        uint256 priceFromAdapter = usdeUsdAdapter.getPriceAt(1_731_919_837, data);
        (, int256 answer,,,) = usdeAggregator.getRoundData(roundId);

        assertEq(priceFromAdapter, uint256(answer));
    }

    function test_ChainlinkAdapterInvalidDataHistoricalPrice() public {
        _setUp(0);
        uint80 roundId = 36_893_488_147_419_103_362;
        bytes memory data = abi.encode(roundId);

        vm.expectRevert(BaseChainlinkPriceAdapter.InvalidHistoricalData.selector);
        usdeUsdAdapter.getPriceAt(1_731_919_637, data);
    }

    function test_ChainlinkAdapterInvalidPhaseFuturePhase() public {
        _setUp(0);
        uint80 roundId = 147_573_952_589_676_412_928; // phaseId = 8, aggregatorRoundId = 0
        bytes memory data = abi.encode(roundId);

        vm.expectRevert(BaseChainlinkPriceAdapter.InvalidPhaseId.selector);
        ethUsdAdapter.getPriceAt(1, data);
    }

    function test_ChainlinkAdapterLatestRoundInNewestPhase() public {
        _setUp(21_444_132);
        uint80 roundId = uint80(usdeAggregator.latestRound()); // 36893488147419103394
        bytes memory data = abi.encode(roundId);

        uint256 priceFromAdapter = usdeUsdAdapter.getPriceAt(usdeAggregator.latestTimestamp(), data);

        // latestAnswer for block 21444132
        assertEq(priceFromAdapter, 99_746_544);
    }

    function test_ChainlinkAdapterPreviousRoundInNewestPhaseNow() public {
        _setUp(21_444_132);
        uint80 roundId = uint80((usdeAggregator.latestRound() - 1));
        bytes memory data = abi.encode(roundId);
        // updatedAt == 1734598847 for 36893488147419103393 roundId
        uint256 priceFromAdapter = usdeUsdAdapter.getPriceAt(1_734_598_847, data);

        assertEq(priceFromAdapter, 100_046_450);
    }

    function test_ChainlinkAdapterPreviousRoundInNewestPhaseTimestampFromFuture() public {
        _setUp(21_444_132);
        uint80 roundId = uint80((usdeAggregator.latestRound() - 1));
        bytes memory data = abi.encode(roundId);
        // updatedAt == 1734598847 for 36893488147419103393 roundId
        uint256 priceFromAdapter = usdeUsdAdapter.getPriceAt(1_734_598_847 + 1, data);

        assertEq(priceFromAdapter, 100_046_450);
    }

    function test_ChainlinkAdapterPreviousRoundInNewestPhaseTimestampFromPast() public {
        _setUp(21_444_132);
        uint80 roundId = uint80((usdeAggregator.latestRound() - 1));
        bytes memory data = abi.encode(roundId);
        vm.expectRevert(BaseChainlinkPriceAdapter.InvalidHistoricalData.selector);
        // updatedAt == 1734598847 for 36893488147419103393 roundId
        usdeUsdAdapter.getPriceAt(1_734_598_847 - 1, data);
    }

    function test_ChainlinkAdapterLatestRoundInPreviousPhase() public {
        _setUp(21_444_132);
        //         0xE62B71cf983019BFf55bC83B48601ce8419650CC(phase 6 contract) latestRound = 23751
        uint80 roundId = uint80(uint256(6) << 64 | 23_751);
        bytes memory data = abi.encode(roundId);
        vm.expectRevert(BaseChainlinkPriceAdapter.InvalidHistoricalData.selector);
        ethUsdAdapter.getPriceAt(1_727_704_523, data);
    }

    function test_ChainlinkAdapterPreviousRoundInPreviousPhase() public {
        _setUp(21_444_132);
        uint80 roundId = uint80(uint256(6) << 64 | 23_751) - 1;
        bytes memory data = abi.encode(roundId);
        // previousRound updatedAt = 1727700935
        uint256 priceFromAdapter = ethUsdAdapter.getPriceAt(1_727_700_935, data);
        assertEq(priceFromAdapter, 263_455_732_377);

        // latestRound updatedAt = 1727704523
        priceFromAdapter = ethUsdAdapter.getPriceAt(1_727_704_523 - 1, data);
        assertEq(priceFromAdapter, 263_455_732_377);
    }
}
