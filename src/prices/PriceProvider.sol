// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IPriceAdapter} from "../interfaces/prices/IPriceAdapter.sol";
import {IPriceProvider} from "../interfaces/prices/IPriceProvider.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PriceProvider is Ownable, IPriceProvider {
    mapping(address token => address adapter) public adaptersRegistry;
    address public immutable baseCurrency;

    error MismatchedLength();
    error ZeroToken();
    error IncorrectAdapterBaseCurrency();

    event SetAdapter(address token, address adapter);

    constructor(
        address[] memory tokens,
        address[] memory adapters,
        address _baseCurrency,
        address owner
    ) Ownable(owner) {
        baseCurrency = _baseCurrency;
        _setAdapter(tokens, adapters);
    }

    function setAdapter(address[] memory tokens, address[] memory adapters) external onlyOwner {
        _setAdapter(tokens, adapters);
    }

    function _setAdapter(address[] memory tokens, address[] memory adapters) internal {
        if (tokens.length != adapters.length) {
            revert MismatchedLength();
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                revert ZeroToken();
            }

            if (IPriceAdapter(adapters[i]).baseCurrency() != baseCurrency) {
                revert IncorrectAdapterBaseCurrency();
            }

            adaptersRegistry[tokens[i]] = adapters[i];
            emit SetAdapter(tokens[i], adapters[i]);
        }
    }

    function getPrice(address token, bytes memory data) external view override returns (uint256 price) {
        address adapter = adaptersRegistry[token];
        price = IPriceAdapter(adapter).getPrice(data);
    }

    function getPriceAt(
        address token,
        uint256 timestamp,
        bytes memory data
    ) external view override returns (uint256 price) {
        address adapter = adaptersRegistry[token];
        price = IPriceAdapter(adapter).getPriceAt(timestamp, data);
    }

    function decimals(address token) external view override returns (uint8) {
        address adapter = adaptersRegistry[token];
        return IPriceAdapter(adapter).decimals();
    }
}
