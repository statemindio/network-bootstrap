// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IPriceAdapter} from "../../interfaces/prices/IPriceAdapter.sol";
import {PrimaryProdDataServiceConsumerBase} from
    "@redstone-finance/evm-connector/contracts/data-services/PrimaryProdDataServiceConsumerBase.sol";
import {MathDecimals} from "../../libs/MathDecimals.sol";
import {BaseOracle} from "./BaseOracle.sol";

contract RedstonePriceAdapter is BaseOracle, PrimaryProdDataServiceConsumerBase {
    using MathDecimals for uint256;

    error IncorrectHistoricalData();

    bytes32 immutable feedId;
    uint256 public immutable priceWindow;
    // Redstone price feeds have 8 decimals by default, however certain exceptions exist.
    uint8 public immutable feedDecimals;

    constructor(bytes32 _feedId, address _baseCurrency, uint256 _priceWindow, uint8 _feedDecimals) BaseOracle(_baseCurrency) {
        feedId = _feedId;
        priceWindow = _priceWindow;
        feedDecimals = _feedDecimals;
    }

    function getPrice(bytes memory /*data*/) external view override returns (uint256) {
        return _normalizePrice(getOracleNumericValueFromTxMsg(feedId), feedDecimals);
    }

    function getPriceAt(uint256 timestamp, bytes memory /*data*/) external view override returns (uint256) {
        bytes32[] memory feedIds = new bytes32[](1);
        feedIds[0] = feedId;

        (uint256[] memory prices, uint256 receivedTimestampMilliseconds) =
            getOracleNumericValuesAndTimestampFromTxMsg(feedIds);

        // verify returned timestamp
        uint256 receivedTimestampSeconds = receivedTimestampMilliseconds / 1000;

        // @question - why symmetrical priceWindow?(in getOracleNumericValueFromTxMsg +3/-1 minutes check) what is production value for priceWindow
        // implicitly different checks: getPrice +3/-1, getPriceAt +-priceWindow
        if (receivedTimestampSeconds > timestamp + priceWindow || receivedTimestampSeconds < timestamp - priceWindow) {
            revert IncorrectHistoricalData();
        }

        uint256 price = prices[0];
        return _normalizePrice(price, feedDecimals);
    }
}
