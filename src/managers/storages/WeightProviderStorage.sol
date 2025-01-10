// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract WeightProviderStorage is Initializable {
    error ZeroWeightProvider();
    error UnknownWeightProviderType();

    function _setWeightProvider(bytes32 storageLocation, address weightProvider) internal {
        if (weightProvider == address(0)) {
            revert ZeroWeightProvider();
        }
        assembly {
            sstore(storageLocation, weightProvider)
        }
    }

    function _weightProvider(bytes32 storageLocation) internal view returns (address weightProvider) {
        assembly {
            weightProvider := sload(storageLocation)
        }
    }
}
