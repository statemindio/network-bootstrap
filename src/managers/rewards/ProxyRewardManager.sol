// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseDefaultOperatorRewardsManager} from "./BaseDefaultOperatorRewardsManager.sol";
import {BaseStakerRewardsManager} from "./BaseStakerRewardsManager.sol";
import {IDefaultOperatorRewards} from
    "@symbioticfi/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";
import {IStakerRewards} from "@symbioticfi/rewards/src/interfaces/stakerRewards/IStakerRewards.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultManager} from "@symbioticfi/middleware-sdk/managers/VaultManager.sol";

abstract contract ProxyRewardManager is BaseDefaultOperatorRewardsManager, BaseStakerRewardsManager {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error ZeroToken();
    error InvalidSender();

    struct StakerRewardsData {
        address vault;
        uint256 amount;
        address token;
        bytes stakerRewardsDistributorData;
    }

    function _distributeOperatorRewards(address token, uint256 amount, bytes32 root) internal {
        if (token == address(0)) {
            revert ZeroToken();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (msg.sender == address(this)) {
            revert InvalidSender();
        }

        IERC20 token_ = IERC20(token);
        token_.safeTransferFrom(msg.sender, address(this), amount);
        address operatorRewardsDistributor = _operatorRewardsDistributor();
        token_.safeIncreaseAllowance(operatorRewardsDistributor, amount);

        IDefaultOperatorRewards(operatorRewardsDistributor).distributeRewards(_NETWORK(), token, amount, root);
    }

    function _distributeStakerRewards(StakerRewardsData memory data) internal {
        if (data.amount == 0) {
            revert ZeroAmount();
        }
        if (data.token == address(0)) {
            revert ZeroToken();
        }
        if (data.vault == address(0)) {
            revert ZeroVault();
        }
        if (msg.sender == address(this)) {
            revert InvalidSender();
        }
        uint48 timestamp = _decodeDistributorTimestamp(data.stakerRewardsDistributorData);
        _checkActiveVault(data.vault, timestamp);

        address stakerRewardsDistributor = _stakerRewardsDistributors(data.vault);
        IERC20 token_ = IERC20(data.token);
        token_.safeTransferFrom(msg.sender, address(this), data.amount);
        token_.safeIncreaseAllowance(stakerRewardsDistributor, data.amount);
        IStakerRewards(stakerRewardsDistributor).distributeRewards(
            _NETWORK(), data.token, data.amount, data.stakerRewardsDistributorData
        );
    }
}
