// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MathDecimals} from "../../libs/MathDecimals.sol";
import {IPriceAdapter} from "../../interfaces/prices/IPriceAdapter.sol";

abstract contract BaseOracle is IPriceAdapter {
    using MathDecimals for uint256;

    error ZeroPrice();

    address public immutable baseCurrency;

    constructor(address _baseCurrency) {
        baseCurrency = _baseCurrency;
    }

    function decimals() public pure returns (uint8) {
        return 8;
    }

    function _normalizePrice(uint256 price, uint8 priceFeedDecimals) internal pure returns(uint256 normalizedPrice){
        normalizedPrice = price.normalizeTo(priceFeedDecimals, decimals());
        if (normalizedPrice == 0) {
            revert ZeroPrice();
        }
    }
}