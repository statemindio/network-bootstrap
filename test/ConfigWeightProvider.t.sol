// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "src/weights/ConfigWeightProvider.sol";

contract ConfigWeightProviderTest is Test {
    ConfigWeightProvider weightProvider;
    address owner;

    function setUp() public {
        owner = makeAddr("owner");
        weightProvider = new ConfigWeightProvider(owner);
    }

    function createEntities(uint256 count) internal pure returns (bytes32[] memory) {
        bytes32[] memory entities = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            entities[i] = bytes32(keccak256(abi.encodePacked("entity", i)));
        }
        return entities;
    }

    function createWeights() internal pure returns (uint128[] memory) {
        uint128[] memory weights = new uint128[](3);
        weights[0] = 2e17;
        weights[1] = 3e17;
        weights[2] = 5e17;
        return weights;
    }

    function test_getWeights() public {
        bytes32[] memory entities = createEntities(3);
        uint128[] memory weights = createWeights();

        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);

        assertEq(weightProvider.getWeight(entities[0]), weights[0]);
        assertEq(weightProvider.getWeight(entities[1]), weights[1]);
        assertEq(weightProvider.getWeight(entities[2]), weights[2]);
    }

    function test_getWeightsAt() public {
        bytes32[] memory entities = createEntities(3);
        uint128[] memory weights = createWeights();

        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);

        uint48 timestamp = uint48(block.timestamp);
        vm.warp(timestamp + 60);

        // set new weights
        uint128[] memory newWeights = new uint128[](3);
        newWeights[0] = 4e17;
        newWeights[1] = 2e17;
        newWeights[2] = 4e17;

        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, newWeights);

        // check old weights
        for (uint256 i = 0; i < entities.length; i++) {
            assertEq(weightProvider.getWeightAt(entities[i], timestamp, ""), weights[i]);
        }

        // check new weights
        for (uint256 i = 0; i < entities.length; i++) {
            assertEq(weightProvider.getWeight(entities[i]), newWeights[i]);
        }
    }

    function test_setInvalidTotalWeightMoreThanOne() public {
        bytes32[] memory entities = createEntities(3);

        uint128[] memory weights = createWeights();
        weights[0] += 1e17;

        vm.expectRevert(ConfigWeightProvider.InvalidTotalWeight.selector);
        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);
    }

    function test_setInvalidTotalWeightsLessThanOne() public {
        bytes32[] memory entities = createEntities(3);

        uint128[] memory weights = createWeights();
        weights[0] -= 1e17;

        vm.expectRevert(ConfigWeightProvider.InvalidTotalWeight.selector);
        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);
    }

    function test_InvalidEntitiesInSetWalletConfigs() public {
        bytes32[] memory entities = createEntities(2);

        uint128[] memory weights = createWeights();

        vm.expectRevert(ConfigWeightProvider.InvalidEntities.selector);
        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);
    }

    function test_getWeightsAndTotalInvalidEntities() public {
        bytes32[] memory entities = new bytes32[](0);

        ConfigWeightProvider.ConfigWPData memory configWPData = ConfigWeightProvider.ConfigWPData(0, new bytes[](0));
        bytes memory data = abi.encode(configWPData);

        vm.expectRevert(ConfigWeightProvider.InvalidEntities.selector);
        weightProvider.getWeightsAndTotal(entities, data);
    }

    function test_getWeightsAndTotalInvalidData() public {
        bytes32[] memory entities = createEntities(2);

        ConfigWeightProvider.ConfigWPData memory configWPData = ConfigWeightProvider.ConfigWPData(0, new bytes[](0));
        bytes memory data = abi.encode(configWPData);

        vm.expectRevert(ConfigWeightProvider.InvalidData.selector);
        weightProvider.getWeightsAndTotal(entities, data);
    }

    function test_getWeightsAndTotalLatest() public {
        bytes32[] memory entities = createEntities(3);

        uint128[] memory weights = createWeights();

        uint256 totalWeights = 0;

        for (uint256 i = 0; i < weights.length; i++) {
            totalWeights += weights[i];
        }

        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);

        bytes[] memory weightsAtHints = new bytes[](3);
        for (uint256 i; i < weightsAtHints.length; i++) {
            weightsAtHints[i] = "";
        }

        ConfigWeightProvider.ConfigWPData memory configWPData =
            ConfigWeightProvider.ConfigWPData(type(uint48).max, weightsAtHints);
        bytes memory data = abi.encode(configWPData);
        (uint256[] memory weights_, uint256 totalWeights_) = weightProvider.getWeightsAndTotal(entities, data);

        assertEq(totalWeights, totalWeights_);
        assertEq(weights[0], weights_[0]);
        assertEq(weights[1], weights_[1]);
        assertEq(weights[2], weights_[2]);
    }

    function test_getWeightsAndTotalAt() public {
        bytes32[] memory entities = createEntities(3);

        uint128[] memory weights = createWeights();

        uint256 totalWeights = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeights += weights[i];
        }

        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, weights);

        uint48 timestamp = uint48(block.timestamp);

        vm.warp(timestamp + 60);

        // set new weights
        uint128[] memory newWeights = createWeights();
        newWeights[0] -= 2e17;
        newWeights[1] += 1e17;
        newWeights[2] += 1e17;

        vm.prank(owner);
        weightProvider.setWalletConfigs(entities, newWeights);

        bytes[] memory weightsAtHints = new bytes[](3);
        for (uint256 i; i < weightsAtHints.length; i++) {
            weightsAtHints[i] = "";
        }

        ConfigWeightProvider.ConfigWPData memory configWPData =
            ConfigWeightProvider.ConfigWPData(timestamp, weightsAtHints);

        bytes memory data = abi.encode(configWPData);
        (uint256[] memory weights_, uint256 totalWeights_) = weightProvider.getWeightsAndTotal(entities, data);

        assertEq(totalWeights, totalWeights_);
        for (uint256 i = 0; i < weights.length; i++) {
            assertEq(weights[i], weights_[i], "Weight mismatch");
        }
    }
}
