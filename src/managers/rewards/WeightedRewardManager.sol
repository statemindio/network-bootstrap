// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseDefaultOperatorRewardsManager} from "./BaseDefaultOperatorRewardsManager.sol";
import {BaseStakerRewardsManager} from "./BaseStakerRewardsManager.sol";
import {ConfigWeightProvider} from "../../weights/ConfigWeightProvider.sol";
import {AmountActiveStakeWeightProvider} from "../../weights/AmountActiveStakeWeightProvider.sol";
import {ValueActiveStakeWeightProvider} from "../../weights/ValueActiveStakeWeightProvider.sol";
import {IDefaultOperatorRewards} from
    "@symbioticfi/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";
import {IDefaultStakerRewards} from "@symbioticfi/rewards/src/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IStakerRewards} from "@symbioticfi/rewards/src/interfaces/stakerRewards/IStakerRewards.sol";
import {IWeightProvider} from "../../interfaces/weights/IWeightProvider.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {RewardWeightProviderStorage} from "../storages/RewardWeightProviderStorage.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultManager} from "@symbioticfi/middleware-sdk/managers/VaultManager.sol";

abstract contract WeightedRewardManager is
    BaseDefaultOperatorRewardsManager,
    BaseStakerRewardsManager,
    RewardWeightProviderStorage
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    error ZeroAmount();
    error ZeroToken();
    error InvalidRoot();
    error InvalidWeights();
    error UnsynchronizedTimestamps();

    struct WeightedRewardManagerData {
        bytes weightProviderData;
        bytes[] stakerRewardsDistributorData;
    }

    function _distributeRewards(
        address token,
        uint256 totalAmount,
        uint256 operatorAmount,
        bytes32 root,
        bytes calldata data
    ) internal {
        if (totalAmount == 0) {
            revert ZeroAmount();
        }
        if (token == address(0)) {
            revert ZeroToken();
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);
        // rewards only for vaults.
        if (operatorAmount == 0) {
            if (root != bytes32(0)) {
                revert InvalidRoot();
            }

            _distributeStakerRewards(totalAmount, token, data);
            return;
        }

        // rewards only for operators.
        if (totalAmount == operatorAmount) {
            if (root == bytes32(0)) {
                revert InvalidRoot();
            }

            _distributeOperatorRewards(token, operatorAmount, root);
            return;
        }

        // rewards for vaults and operators
        _distributeOperatorRewards(token, operatorAmount, root);
        _distributeStakerRewards(totalAmount - operatorAmount, token, data);
    }

    function _distributeOperatorRewards(address token, uint256 amount, bytes32 root) internal {
        address operatorRewardsDistributor = _operatorRewardsDistributor();
        IERC20(token).safeIncreaseAllowance(operatorRewardsDistributor, amount);

        IDefaultOperatorRewards(operatorRewardsDistributor).distributeRewards(_NETWORK(), token, amount, root);
    }

    function _distributeStakerRewards(uint256 amount, address token, bytes memory data) internal {
        WeightedRewardManagerData memory weightedRewardManagerData = abi.decode(data, (WeightedRewardManagerData));

        address[] memory vaults = _activeVaults();
        uint256[] memory weights;
        uint256 totalWeight;
        address rewardProvider = _rewardWeightProvider();
        {
            bytes32[] memory entities = new bytes32[](vaults.length);
            for (uint256 i; i < vaults.length; i++) {
                entities[i] = bytes32(uint256(uint160(vaults[i])));
            }
            (weights, totalWeight) = IWeightProvider(rewardProvider).getWeightsAndTotal(
                entities, weightedRewardManagerData.weightProviderData
            );
        }

        if (
            weights.length == 0 || totalWeight == 0 || vaults.length != weights.length
                || weights.length != weightedRewardManagerData.stakerRewardsDistributorData.length
        ) {
            revert InvalidWeights();
        }

        uint48 providerTimestamp =
            _decodeProviderTimestamp(rewardProvider, weightedRewardManagerData.weightProviderData);
        uint256 usedAmount;
        uint256 lastIndex = weights.length - 1;
        for (uint256 i; i < weights.length; i++) {
            address stakerRewardsDistributor = _stakerRewardsDistributors(vaults[i]);
            uint48 distributorTimestamp =
                _decodeDistributorTimestamp(weightedRewardManagerData.stakerRewardsDistributorData[i]);
            if (providerTimestamp != distributorTimestamp) {
                revert UnsynchronizedTimestamps();
            }
            _checkActiveVault(vaults[i], distributorTimestamp);

            uint256 vaultAmount = amount.mulDiv(weights[i], totalWeight);
            if (i == lastIndex) {
                vaultAmount = amount - usedAmount;
            }
            if (vaultAmount == 0) continue;
            usedAmount += vaultAmount;

            IERC20(token).safeIncreaseAllowance(stakerRewardsDistributor, vaultAmount);

            IStakerRewards(stakerRewardsDistributor).distributeRewards(
                _NETWORK(), token, vaultAmount, weightedRewardManagerData.stakerRewardsDistributorData[i]
            );
        }
    }

    function _decodeProviderTimestamp(address provider, bytes memory rawData) internal view returns (uint48) {
        uint64 providerType = IWeightProvider(provider).TYPE();
        if (providerType == 1) {
            ConfigWeightProvider.ConfigWPData memory data = abi.decode(rawData, (ConfigWeightProvider.ConfigWPData));
            return data.timestamp;
        }
        if (providerType == 2) {
            AmountActiveStakeWeightProvider.AmountWPData memory data =
                abi.decode(rawData, (AmountActiveStakeWeightProvider.AmountWPData));
            return data.timestamp;
        }
        if (providerType == 3) {
            ValueActiveStakeWeightProvider.ValueWPData memory data =
                abi.decode(rawData, (ValueActiveStakeWeightProvider.ValueWPData));
            return data.timestamp;
        }
        revert UnknownWeightProviderType();
    }
}
