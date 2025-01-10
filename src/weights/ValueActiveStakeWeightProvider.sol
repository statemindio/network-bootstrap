// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MathDecimals} from "../libs/MathDecimals.sol";
import {IPriceProvider} from "../interfaces/prices/IPriceProvider.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {IWeightProvider, IWeightProviderLib} from "../interfaces/weights/IWeightProvider.sol";

contract ValueActiveStakeWeightProvider is IWeightProvider {
    error InvalidPriceProvider();
    error InvalidVaultCollateral();
    error InvalidTimestamp();
    error EmptyEntities();
    error DifferentVaultCollateral();
    error InvalidData();

    struct ValueWPData {
        uint48 timestamp;
        bytes[] activeStakeAtHints;
        bytes[] priceProviderData;
    }

    uint8 public immutable STAKE_DECIMALS;
    address public immutable PRICE_PROVIDER;

    uint64 public constant TYPE = 3;


    constructor(address priceProvider_, uint8 stakeDecimals) {
        STAKE_DECIMALS = stakeDecimals;
        if (priceProvider_ == address(0)) {
            revert InvalidPriceProvider();
        }
        PRICE_PROVIDER = priceProvider_;
    }

    // The contract supports correct functioning only when entities are Vault addresses.
    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory rawData
    ) public view override returns (uint256[] memory weights, uint256 totalWeight) {
        ValueWPData memory data = abi.decode(rawData, (ValueWPData));
        weights = new uint256[](entities.length);
        if (data.timestamp == 0) {
            revert InvalidTimestamp();
        }
        if (entities.length == 0) {
            revert EmptyEntities();
        }
        if (data.activeStakeAtHints.length != entities.length) {
            revert InvalidData();
        }

        for (uint256 i; i < entities.length; i++) {
            address vault = IWeightProviderLib.toAddr(entities[i]);
            // vault tokens can be different
            address vaultToken = IVault(vault).collateral();
            if (vaultToken == address(0)) {
                revert InvalidVaultCollateral();
            }

            uint256 stakeAmount;
            uint256 price;
            if (data.timestamp == block.timestamp || data.timestamp == type(uint48).max) {
                stakeAmount = IVault(vault).activeStake();
                price = IPriceProvider(PRICE_PROVIDER).getPrice(vaultToken, data.priceProviderData[i]);
            } else {
                stakeAmount = IVault(vault).activeStakeAt(data.timestamp, data.activeStakeAtHints[i]);
                price =
                    IPriceProvider(PRICE_PROVIDER).getPriceAt(vaultToken, data.timestamp, data.priceProviderData[i]);
            }
            stakeAmount = MathDecimals.normalizeTo(stakeAmount, IERC20Metadata(vaultToken).decimals(), STAKE_DECIMALS);
            uint256 valueInBaseCurrency = stakeAmount * price;

            totalWeight += valueInBaseCurrency;
            weights[i] = valueInBaseCurrency;
        }
    }
}
