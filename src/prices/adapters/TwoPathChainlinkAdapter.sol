// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AggregatorV2V3Interface, EACAggregatorProxy} from "../../interfaces/external/AggregatorV3Interface.sol";
import {IPriceAdapter} from "../../interfaces/prices/IPriceAdapter.sol";
import {MathDecimals} from "../../libs/MathDecimals.sol";
import {BaseChainlinkPriceAdapter} from "./BaseChainlinkAdapter.sol";
import {BaseOracle} from "./BaseOracle.sol";

contract TwoPathChainlinkAdapter is BaseChainlinkPriceAdapter {
    using MathDecimals for uint256;

    error InvalidPriceFeedAddress();

    address public immutable priceFeed1;
    address public immutable priceFeed2;
    uint256 immutable heartBeat1;
    uint256 immutable heartBeat2;

    constructor(
        address _priceFeed1,
        address _priceFeed2,
        uint256 _heartBeat1,
        uint256 _heartBeat2,
        address _baseCurrency
    ) BaseOracle(_baseCurrency) {
        if (_priceFeed1 == address(0) || _priceFeed2 == address(0)) {
            revert InvalidPriceFeedAddress();
        }

        priceFeed1 = _priceFeed1;
        priceFeed2 = _priceFeed2;

        heartBeat1 = _heartBeat1;
        heartBeat2 = _heartBeat2;
    }

    function getPrice(bytes memory) external view override returns (uint256) {
        (uint token1Price, uint8 feed1Decimals) = _getLatestPrice(AggregatorV2V3Interface(priceFeed1), heartBeat1);
        (uint token2Price, uint8 feed2Decimals) = _getLatestPrice(AggregatorV2V3Interface(priceFeed2), heartBeat2);

        uint combinedPrice = token1Price * token2Price;
        return _normalizeCombinedPrice(combinedPrice, feed1Decimals, feed2Decimals);
    }

    function getPriceAt(uint256 timestamp, bytes memory data) external view override returns (uint256) {
        (uint80 priceFeed1RoundId, uint80 priceFeed2RoundId) = abi.decode(data, (uint80, uint80));

        (uint token1Price, uint8 feed1Decimals) = _verifyTimestampAndGetPrice(AggregatorV2V3Interface(priceFeed1), timestamp, priceFeed1RoundId);
        (uint token2Price, uint8 feed2Decimals) = _verifyTimestampAndGetPrice(AggregatorV2V3Interface(priceFeed2), timestamp, priceFeed2RoundId);

        uint price = token1Price * token2Price;
        return _normalizeCombinedPrice(price, feed1Decimals, feed2Decimals);
    }

    function _normalizeCombinedPrice(
        uint256 price,
        uint8 priceFeedDecimals1,
        uint8 priceFeedDecimals2
    ) internal pure returns (uint256) {
        uint256 normalizedPrice = uint256(price) / 10 ** priceFeedDecimals1;
        return _normalizePrice(normalizedPrice, priceFeedDecimals2);
    }
}
