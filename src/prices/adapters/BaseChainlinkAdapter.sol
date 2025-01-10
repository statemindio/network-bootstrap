// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseOracle} from "./BaseOracle.sol";
import {
    AggregatorV2V3Interface,
    AggregatorInterface,
    EACAggregatorProxy
} from "../../interfaces/external/AggregatorV3Interface.sol";

abstract contract BaseChainlinkPriceAdapter is BaseOracle {

    error InvalidPhaseId();
    error InvalidHistoricalChainlinkPrice();
    error InvalidHistoricalData();
    error InvalidLatestChainlinkPrice();
    error ChainlinkStalePrice();

    function _verifyTimestampAndGetPrice(
        AggregatorV2V3Interface feed,
        uint256 timestamp,
        uint80 roundId
    ) internal view returns (uint price, uint8 feedDecimals) {
        uint16 aggregatorPhaseID = EACAggregatorProxy(address(feed)).phaseId();
        uint16 phaseId = uint16(roundId >> 64);

        if (phaseId > aggregatorPhaseID) {
            revert InvalidPhaseId();
        }

        (, int256 answer,, uint256 updatedAt,) = feed.getRoundData(roundId);

        if (answer <= 0) {
            revert InvalidHistoricalChainlinkPrice();
        }

        if (updatedAt > timestamp) {
            revert InvalidHistoricalData();
        }

        uint256 latestRound = feed.latestRound();
        if (latestRound == roundId) return (uint(answer), feed.decimals());

        uint256 nextUpdatedAt;
        (,,, nextUpdatedAt,) = feed.getRoundData(roundId + 1);

        if (timestamp >= nextUpdatedAt) {
            revert InvalidHistoricalData();
        }

        return (uint(answer), feed.decimals());
    }

    function _getLatestPrice(AggregatorV2V3Interface feed, uint256 heartBeat) internal view returns (uint256, uint8) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        if (answer <= 0) {
            revert InvalidLatestChainlinkPrice();
        }

        if (updatedAt + heartBeat < block.timestamp) {
            revert ChainlinkStalePrice();
        }

        return (uint(answer), feed.decimals());
    }
}