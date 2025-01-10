// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceAdapter {
    function getPrice(bytes memory data) external view returns (uint256);
    function getPriceAt(uint256 timestamp, bytes memory data) external view returns (uint256);
    function decimals() external pure returns (uint8);
    function baseCurrency() external view returns (address);
}
