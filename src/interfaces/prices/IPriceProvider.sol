// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceProvider {
    function getPrice(address token, bytes memory data) external view returns (uint256);
    function getPriceAt(address token, uint256 timestamp, bytes memory data) external view returns (uint256);
    function decimals(address token) external view returns (uint8);
    function baseCurrency() external view returns (address);
}
