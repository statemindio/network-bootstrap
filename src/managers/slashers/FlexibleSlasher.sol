// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseSlasher} from "./BaseSlasher.sol";

abstract contract FlexibleSlasher is BaseSlasher {
    /*
     * @notice Slashes a validator in the provided vault and subnetwork
     * @param timestamp The timestamp for which the slashing occurs.
     * @param key The key of the operator to slash.
     * @param amount The amount to slash.
     * @param vault The address of the vault.
     * @param subnetwork The subnetwork identifier.
     * @param hints Hints for the slashing process.
     * @return A struct SlashResponse containing information about the slash response.
     */
    function slash(
        uint48 timestamp,
        bytes memory key,
        uint256 amount,
        address vault,
        bytes32 subnetwork,
        bytes calldata hints
    ) public checkAccess {
        address operator = getOperatorAndCheckCanSlash(key, timestamp);
        _slashVault(timestamp, vault, subnetwork, operator, amount, hints);
    }
}
