// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./helpers/VaultBase.t.sol";
import "forge-std/Test.sol";

import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {SubnetworkDelegatorStakeWeightProvider} from "../src/weights/SubnetworkDelegatorStakeWeightProvider.sol";

contract SubnetworkDelegatorStakeWeightProviderTest is Test, VaultBaseTest {
    using Subnetwork for bytes32;
    using Subnetwork for address;

    address vault;
    address slasher;
    address delegator;

    address network = makeAddr("network");
    address operator = makeAddr("operator");

    address user = makeAddr("user");
    uint96 subnetworkIdentifier0 = 0;
    uint96 subnetworkIdentifier1 = 1;
    uint96 subnetworkIdentifier2 = 2;

    SubnetworkDelegatorStakeWeightProvider weightProvider;

    function setUp() public override {
        super.setUp();

        // create vault with slasher
        (vault, delegator, slasher) = createVaultWithSlasher(address(collateral));

        // deposit to vault
        collateral.mint(user, 10_000e18);
        vm.startPrank(user);
        collateral.approve(vault, 100e18);
        IVault(vault).deposit(user, 100e18);
        vm.stopPrank();

        weightProvider = new SubnetworkDelegatorStakeWeightProvider();

        // register network
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        vm.stopPrank();

        // register operator
        vm.startPrank(operator);
        operatorRegistry.registerOperator();
        operatorNetworkOptInService.optIn(network);
        operatorVaultOptInService.optIn(vault);
        vm.stopPrank();

        // set network limit
        vm.startPrank(network);
        INetworkRestakeDelegator(delegator).setMaxNetworkLimit(0, 100e18);
        INetworkRestakeDelegator(delegator).setMaxNetworkLimit(1, 100e18);
        INetworkRestakeDelegator(delegator).setMaxNetworkLimit(2, 100e18);
        vm.stopPrank();

        vm.startPrank(alice);
        INetworkRestakeDelegator(delegator).setNetworkLimit(network.subnetwork(subnetworkIdentifier0), 100e18);
        INetworkRestakeDelegator(delegator).setNetworkLimit(network.subnetwork(subnetworkIdentifier1), 50e18);
        INetworkRestakeDelegator(delegator).setNetworkLimit(network.subnetwork(subnetworkIdentifier2), 50e18);

        // set operator network shares
        INetworkRestakeDelegator(delegator).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier0), operator, 100e18
        );
        INetworkRestakeDelegator(delegator).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier1), operator, 100e18
        );
        INetworkRestakeDelegator(delegator).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier2), operator, 100e18
        );
        vm.stopPrank();
    }

    function test_getWeightsAndTotal() public view {
        bytes32[] memory entities = new bytes32[](3);
        entities[0] = network.subnetwork(subnetworkIdentifier0);
        entities[1] = network.subnetwork(subnetworkIdentifier1);
        entities[2] = network.subnetwork(subnetworkIdentifier2);

        uint256[] memory validWeights = new uint256[](3);
        validWeights[0] = 100e18;
        validWeights[1] = 50e18;
        validWeights[2] = 50e18;
        uint256 validTotalWeight = 200e18;

        SubnetworkDelegatorStakeWeightProvider.SubnetworkDelegatorStakeWPData memory data;

        data.operator = operator;
        data.vault = vault;
        data.timestamp = type(uint48).max;
        data.stakeHints = new bytes[](3);

        (uint256[] memory weights, uint256 totalWeight) = weightProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights[0], validWeights[0]);
        assertEq(weights[1], validWeights[1]);
        assertEq(weights[2], validWeights[2]);
        assertEq(totalWeight, validTotalWeight);
    }
}
