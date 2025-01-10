// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {
    AggregatorV2V3Interface,
    AggregatorInterface,
    EACAggregatorProxy
} from "../../interfaces/external/AggregatorV3Interface.sol";
import {IPriceAdapter} from "../../interfaces/prices/IPriceAdapter.sol";
import {MathDecimals} from "../../libs/MathDecimals.sol";
import {BaseChainlinkPriceAdapter} from "./BaseChainlinkAdapter.sol";
import {BaseOracle} from "./BaseOracle.sol";

contract ChainlinkPriceAdapter is BaseChainlinkPriceAdapter {
    using MathDecimals for uint256;

    error ZeroPriceFeed();

    address public immutable priceFeed;
    uint256 public immutable heartBeat;

    constructor(address _priceFeed, uint256 _heartBeat, address _baseCurrency) BaseOracle(_baseCurrency) {
        if (_priceFeed == address(0)) {
            revert ZeroPriceFeed();
        }
        priceFeed = _priceFeed;
        heartBeat = _heartBeat;
    }

    function getPrice(bytes memory) external view override returns (uint256) {
        (uint price, uint8 feedDecimals) = _getLatestPrice(AggregatorV2V3Interface(priceFeed), heartBeat);
        return _normalizePrice(price, feedDecimals);
    }

    function getPriceAt(uint256 timestamp, bytes memory data) external view override returns (uint256) {
        uint80 roundId = abi.decode(data, (uint80));

        (uint price, uint8 feedDecimals) = _verifyTimestampAndGetPrice(AggregatorV2V3Interface(priceFeed), timestamp, roundId);
        return _normalizePrice(price, feedDecimals);
    }
}
