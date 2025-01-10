pragma solidity ^0.8.0;

library MathDecimals {
    function normalizeTo(uint256 value, uint8 decimals, uint8 neededDecimals) internal pure returns (uint256) {
        uint256 multiplier = 10 ** (decimals > neededDecimals ? decimals - neededDecimals : neededDecimals - decimals);
        return (neededDecimals > decimals) ? value * multiplier : value / multiplier;
    }
}
