// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EpochCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/EpochCapture.sol";
import {PauseableEnumerableSet} from "@symbioticfi/middleware-sdk/libraries/PauseableEnumerableSet.sol";
import {OperatorManager} from "@symbioticfi/middleware-sdk/managers/OperatorManager.sol";
import {VaultManager} from "@symbioticfi/middleware-sdk/managers/VaultManager.sol";
import {BaseMiddleware} from "@symbioticfi/middleware-sdk/middleware/BaseMiddleware.sol";

abstract contract BaseSlasher is BaseMiddleware {
    using PauseableEnumerableSet for PauseableEnumerableSet.AddressSet;

    error InactiveKeySlash(); // Error thrown when trying to slash an inactive key
    error InactiveOperatorSlash(); // Error thrown when trying to slash an inactive operator
    error NotExistKeySlash(); // Error thrown when the key does not exist for slashing

    /*
     * @notice Returns the operator address associated with a given key and checks if a given key was active at a specified timestamp.
     * @param key The key for which to find the associated operator.
     * @param timestamp The timestamp to check for key activity.
     * @return The address of the operator linked to the specified key.
     */
    function getOperatorAndCheckCanSlash(
        bytes memory key,
        uint48 timestamp
    ) public view returns (address operator) {
        operator = operatorByKey(key); // Get the operator associated with the key

        if (operator == address(0)) {
            revert NotExistKeySlash(); // Revert if the operator does not exist
        }

        if (!keyWasActiveAt(timestamp, key)) {
            revert InactiveKeySlash(); // Revert if the key is inactive
        }

        if (!_operatorWasActiveAt(timestamp, operator)) {
            revert InactiveOperatorSlash(); // Revert if the operator wasn't active
        }
    }

    /*
     * @notice Executes a veto-based slash for a vault.
     * @param vault The address of the vault.
     * @param operator The address of the operator.
     * @param slashIndex The index of the slash to execute.
     * @param hints Additional data for the veto slasher.
     * @return The amount that was slashed.
     */
    function executeSlash(
        address vault,
        uint256 slashIndex,
        bytes calldata hints
    ) external checkAccess returns (uint256 slashedAmount) {
        return super._executeSlash(vault, slashIndex, hints);
    }
}
