// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {IBaseDelegator} from "@symbioticfi/core/src/interfaces/delegator/IBaseDelegator.sol";
import {IPriceProvider} from "../interfaces/prices/IPriceProvider.sol";
import {IWeightProvider, IWeightProviderLib} from "../interfaces/weights/IWeightProvider.sol";

contract VaultDelegatorStakeWeightProvider is IWeightProvider {
    error InvalidVaultCollateral();
    error InvalidTimestamp();
    error EmptyEntities();
    error DifferentVaultCollateral();
    error InvalidData();

    struct VaultDelegatorStakeWPData {
        address operator;
        uint48 timestamp;
        bytes32[] subnetworks;
        bytes[][] stakeHints;
        bytes[] priceProviderData;
    }

    uint64 public constant TYPE = 4;
    address public immutable PRICE_PROVIDER;

    constructor(address priceProvider_) {
        PRICE_PROVIDER = priceProvider_;
    }

    // The contract supports correct functioning only when entities are Vault addresses.
    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory rawData
    ) public view override returns (uint256[] memory weights, uint256 totalWeight) {
        VaultDelegatorStakeWPData memory data = abi.decode(rawData, (VaultDelegatorStakeWPData));
        weights = new uint256[](entities.length);
        if (data.timestamp == 0) {
            revert InvalidTimestamp();
        }
        if (entities.length == 0) {
            revert EmptyEntities();
        }
        if (data.subnetworks.length == 0) {
            revert EmptyEntities();
        }
        if (data.stakeHints.length != entities.length) {
            revert InvalidData();
        }
        bool multiToken = data.priceProviderData.length != 0;
        address collateralToken = IVault(IWeightProviderLib.toAddr(entities[0])).collateral();
        for (uint256 i; i < entities.length; ++i) {
            address vault = IWeightProviderLib.toAddr(entities[i]);
            address vaultToken = IVault(vault).collateral();
            if (!multiToken && vaultToken != collateralToken) {
                revert DifferentVaultCollateral();
            }
            uint256 stakeAmount;
            for (uint256 j; j < data.subnetworks.length; ++j) {
                uint256 stake = IBaseDelegator(IVault(vault).delegator()).stakeAt(
                    data.subnetworks[j], data.operator, data.timestamp, data.stakeHints[i][j]
                );
                stakeAmount += stake;
            }
            if (multiToken) {
                uint256 price;
                if (data.timestamp == block.timestamp || data.timestamp == type(uint48).max) {
                    price = IPriceProvider(PRICE_PROVIDER).getPrice(vaultToken, data.priceProviderData[i]);
                } else {
                    price = IPriceProvider(PRICE_PROVIDER).getPriceAt(vaultToken, data.timestamp, data.priceProviderData[i]);
                }
                stakeAmount = Math.mulDiv(stakeAmount, price, 10 ** IPriceProvider(PRICE_PROVIDER).decimals(vaultToken));
            }
            totalWeight += stakeAmount;
            weights[i] = stakeAmount;
        }
    }
}
