// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract PriceProviderStorage is Initializable {
    error ZeroPriceProvider();

    // keccak256(abi.encode(uint256(keccak256("statemind.storage.PriceProviderStorage.priceProvider")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PriceProviderStorageLocation =
        0x430af45bedc6ff347882bbaf2d4d1f98fe9072daa88bd1a63de93d175449c400;

    function __PriceProviderStorage_init(address priceProvider) internal onlyInitializing {
        _setPriceProvider(priceProvider);
    }

    function _setPriceProvider(address priceProvider) internal {
        if (priceProvider == address(0)) {
            revert ZeroPriceProvider();
        }
        bytes32 location = PriceProviderStorageLocation;
        assembly {
            sstore(location, priceProvider)
        }
    }

    function _priceProvider() internal view returns (address priceProvider) {
        bytes32 location = PriceProviderStorageLocation;
        assembly {
            priceProvider := sload(location)
        }
    }
}

abstract contract PriceProviderStorageReader is PriceProviderStorage {
    function priceProvider() public view returns (address) {
        return _priceProvider();
    }
}
