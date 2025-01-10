// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract MockVault {
    address public collateral;
    uint256 public activeStake;
    mapping(uint48 => uint256) internal _activeStakeAt;

    function setCollateral(address collateral_) external {
        collateral = collateral_;
    }

    function setActiveStake(uint256 activeStake_) external {
        activeStake = activeStake_;
    }

    function setActiveStakeAt(uint256 activeStakeAt_, uint48 timestamp) external {
        _activeStakeAt[timestamp] = activeStakeAt_;
    }

    function activeStakeAt(uint48 timestamp, bytes memory /*hint*/) external view returns (uint256) {
        return _activeStakeAt[timestamp];
    }
}
