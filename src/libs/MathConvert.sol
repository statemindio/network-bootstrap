// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {IPriceProvider} from "../interfaces/prices/IPriceProvider.sol";

library MathConvert {
    error InvalidPriceProviderDataLength();
    error InvalidAmountsLength();
    error InvalidVaultCollateral();

    function convertToVaultsCollateral(
        address[] memory vaults,
        uint256[] memory amounts,
        address priceProvider,
        bytes[] memory priceProviderData,
        uint48 timestamp
    ) internal view returns (uint256[] memory convertedAmounts) {
        if (priceProviderData.length != vaults.length) {
            revert InvalidPriceProviderDataLength();
        }
        if (amounts.length != vaults.length) {
            revert InvalidAmountsLength();
        }

        convertedAmounts = new uint256[](vaults.length);

        for (uint256 i; i < vaults.length; i++) {
            address vaultToken = IVault(vaults[i]).collateral();
            if (vaultToken == address(0)) {
                revert InvalidVaultCollateral();
            }

            uint256 price;
            if (timestamp == block.timestamp || timestamp == type(uint48).max) {
                price = IPriceProvider(priceProvider).getPrice(vaultToken, priceProviderData[i]);
            } else {
                price = IPriceProvider(priceProvider).getPriceAt(vaultToken, timestamp, priceProviderData[i]);
            }

            convertedAmounts[i] =
                Math.mulDiv(amounts[i], 10 ** IPriceProvider(priceProvider).decimals(vaultToken), price);
        }
    }

    function convertAddressArrayToBytes32Array(address[] memory addresses) internal pure returns (bytes32[] memory) {
        bytes32[] memory result = new bytes32[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            result[i] = bytes32(uint256(uint160(addresses[i])));
        }
        return result;
    }

    function convertSubnetworksArrayToBytes32Array(
        address network,
        uint160[] memory _subnetworks
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory result = new bytes32[](_subnetworks.length);
        for (uint256 i = 0; i < _subnetworks.length; i++) {
            result[i] = Subnetwork.subnetwork(network, uint96(_subnetworks[i]));
        }
        return result;
    }
}
