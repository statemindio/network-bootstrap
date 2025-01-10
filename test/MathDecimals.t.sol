// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/libs/MathDecimals.sol";

contract MathDecimalsTest is Test {
    using MathDecimals for uint256;

    uint256 price = 1000;

    function testNormalizePrice_SameDecimals() public view {
        uint8 decimals = 18;
        uint8 neededDecimals = 18;
        uint256 priceWithDecimals = 1000 * 10 ** decimals;

        uint256 result = priceWithDecimals.normalizeTo(decimals, neededDecimals);
        uint256 expected = price * 10 ** neededDecimals;
        assertEq(result, expected);
    }

    function testNormalizePrice_HigherDecimals() public view {
        uint8 decimals = 18;
        uint8 neededDecimals = 20;
        uint256 priceWithDecimals = price * 10 ** decimals;

        uint256 result = priceWithDecimals.normalizeTo(decimals, neededDecimals);
        uint256 expected = price * 10 ** neededDecimals;
        assertEq(result, expected);
    }

    function testNormalizePrice_LowerDecimals() public view {
        uint8 decimals = 18;
        uint8 neededDecimals = 16;
        uint256 priceWithDecimals = price * 10 ** decimals;

        uint256 result = priceWithDecimals.normalizeTo(decimals, neededDecimals);
        uint256 expected = price * 10 ** neededDecimals;
        assertEq(result, expected);
    }
}
