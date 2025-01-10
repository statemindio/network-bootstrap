// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./helpers/VaultBase.t.sol";
import "forge-std/Test.sol";

import {Subnetwork} from "@symbioticfi/core/src/contracts/libraries/Subnetwork.sol";
import {VaultDelegatorStakeWeightProvider} from "../src/weights/VaultDelegatorStakeWeightProvider.sol";


contract VaultDelegatorStakeWeightProviderTest is Test, VaultBaseTest {

    using Subnetwork for bytes32;
    using Subnetwork for address;

    address vault1;
    address vault2;
    address slasher1;
    address slasher2;
    address delegator1;
    address delegator2;

    address network = makeAddr("network");
    address operator = makeAddr("operator");

    address user = makeAddr("user");
    uint96 subnetworkIdentifier = 0;

    VaultDelegatorStakeWeightProvider weightProvider;

    function setUp() override public {
        super.setUp();

        // create vaults with slasher
        (vault1, delegator1, slasher1) = createVaultWithSlasher(address(collateral));
        (vault2, delegator2, slasher2) = createVaultWithSlasher(address(collateral));

        // deposit to vault
        collateral.mint(user, 10_000e18);
        vm.startPrank(user);
        collateral.approve(vault1, 100e18);
        IVault(vault1).deposit(user, 100e18);
        collateral.approve(vault2, 100e18);
        IVault(vault2).deposit(user, 100e18);
        vm.stopPrank();

        weightProvider = new VaultDelegatorStakeWeightProvider(address(0));


        // register network
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        vm.stopPrank();

        // register operator
        vm.startPrank(operator);
        operatorRegistry.registerOperator();
        operatorNetworkOptInService.optIn(network);
        operatorVaultOptInService.optIn(vault1);
        operatorVaultOptInService.optIn(vault2);
        vm.stopPrank();


        // set network limit
        vm.startPrank(network);
        INetworkRestakeDelegator(delegator1).setMaxNetworkLimit(subnetworkIdentifier, 100e18);
        INetworkRestakeDelegator(delegator2).setMaxNetworkLimit(subnetworkIdentifier, 100e18);
        vm.stopPrank();

        vm.startPrank(alice);
        INetworkRestakeDelegator(delegator1).setNetworkLimit(network.subnetwork(subnetworkIdentifier), 100e18);
        INetworkRestakeDelegator(delegator2).setNetworkLimit(network.subnetwork(subnetworkIdentifier), 50e18);

        // set operator network shares
        INetworkRestakeDelegator(delegator1).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier), operator, 100e18
        );
        INetworkRestakeDelegator(delegator2).setOperatorNetworkShares(
            network.subnetwork(subnetworkIdentifier), operator, 100e18
        );
        vm.stopPrank();
    }

    function test_getWeightsAndTotal() public view {
        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(vault1)));
        entities[1] = bytes32(uint256(uint160(vault2)));

        uint256[] memory validWeights = new uint256[](2);
        validWeights[0] = 100e18;
        validWeights[1] = 50e18;
        uint256 validTotalWeight = 150e18;

        VaultDelegatorStakeWeightProvider.VaultDelegatorStakeWPData memory data;

        data.operator = operator;
        data.timestamp = type(uint48).max;
        data.subnetworks = new bytes32[](1); 
        data.subnetworks[0] = network.subnetwork(subnetworkIdentifier);
        data.stakeHints = new bytes[][](2);
        data.stakeHints[0] = new bytes[](1);
        data.stakeHints[1] = new bytes[](1);
        data.priceProviderData = new bytes[](0);

        (uint256[] memory weights, uint256 totalWeight) = weightProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights[0], validWeights[0]);
        assertEq(weights[1], validWeights[1]);
        assertEq(totalWeight, validTotalWeight);
    }
}
