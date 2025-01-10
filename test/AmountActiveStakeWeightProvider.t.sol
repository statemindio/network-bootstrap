// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./helpers/VaultBase.t.sol";
import {AmountActiveStakeWeightProvider} from "../src/weights/AmountActiveStakeWeightProvider.sol";
import "forge-std/Test.sol";
import {MockVault} from "./mocks/MockVault.sol";

contract AmountActiveStakeWeightProviderTest is VaultBaseTest {
    AmountActiveStakeWeightProvider public awProvider;

    IVault public vault_1;
    IVault public vault_2;

    function setUp() public override {
        super.setUp();

        awProvider = new AmountActiveStakeWeightProvider();
        vault_1 = IVault(createVault());
        vault_2 = IVault(createVault());
    }

    function testGetWeightsAndTotal_singleEntity_emptyStake() public view {
        assertEq(vault_1.activeStake(), 0);

        AmountActiveStakeWeightProvider.AmountWPData memory data = AmountActiveStakeWeightProvider.AmountWPData({
            timestamp: uint48(block.timestamp), // 1st condition for get last active stake
            activeStakeAtHints: new bytes[](1)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](1);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));

        (uint256[] memory weights, uint256 totalWeight) = awProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 1);
        assertEq(weights[0], 0);
        assertEq(totalWeight, 0);
    }

    function testGetWeightsAndTotal_multiplyEntities_emptyStake() public view {
        assertEq(vault_1.activeStake(), 0);
        assertEq(vault_2.activeStake(), 0);

        AmountActiveStakeWeightProvider.AmountWPData memory data = AmountActiveStakeWeightProvider.AmountWPData({
            timestamp: type(uint48).max, // 2st condition for get last active stake
            activeStakeAtHints: new bytes[](2)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));
        entities[1] = bytes32(uint256(uint160(address(vault_2))));

        (uint256[] memory weights, uint256 totalWeight) = awProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 2);
        assertEq(weights[0], 0);
        assertEq(weights[1], 0);
        assertEq(totalWeight, 0);
    }

    function testGetWeightsAndTotal_multiplyEntities_nonEmptyStake(uint256 depAm1, uint256 depAm2) public {
        assertEq(vault_1.activeStake(), 0);
        assertEq(vault_2.activeStake(), 0);

        depAm1 = bound(depAm1, 1, 1e18);
        depAm2 = bound(depAm2, 1, 1e18);
        collateral.approve(address(vault_1), depAm1);
        vault_1.deposit(address(this), depAm1);
        collateral.approve(address(vault_2), depAm2);
        vault_2.deposit(address(this), depAm2);

        AmountActiveStakeWeightProvider.AmountWPData memory data = AmountActiveStakeWeightProvider.AmountWPData({
            timestamp: type(uint48).max, // 2st condition for get last active stake
            activeStakeAtHints: new bytes[](2)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));
        entities[1] = bytes32(uint256(uint160(address(vault_2))));

        (uint256[] memory weights, uint256 totalWeight) = awProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 2);
        assertEq(weights[0], depAm1);
        assertEq(weights[1], depAm2);
        assertEq(totalWeight, depAm1 + depAm2);
    }

    // тест когда мы из середины получаем
    function testGetWeightsAndTotal_multiplyEntities_nonEmptyStake_beforeDep1(uint256 depAm1, uint256 depAm2) public {
        assertEq(vault_1.activeStake(), 0);
        assertEq(vault_2.activeStake(), 0);

        depAm1 = bound(depAm1, 1, 1e18);
        depAm2 = bound(depAm2, 1, 1e18);
        collateral.approve(address(vault_1), depAm1);
        vault_1.deposit(address(this), depAm1);
        uint256 dep2Timestamp = block.timestamp + 100;
        vm.warp(dep2Timestamp);
        collateral.approve(address(vault_2), depAm2);
        vault_2.deposit(address(this), depAm2);

        AmountActiveStakeWeightProvider.AmountWPData memory data = AmountActiveStakeWeightProvider.AmountWPData({
            timestamp: uint48(dep2Timestamp) - 1,
            activeStakeAtHints: new bytes[](2)
        });
        // hints empty

        bytes32[] memory entities = new bytes32[](2);
        entities[0] = bytes32(uint256(uint160(address(vault_1))));
        entities[1] = bytes32(uint256(uint160(address(vault_2))));

        (uint256[] memory weights, uint256 totalWeight) = awProvider.getWeightsAndTotal(entities, abi.encode(data));

        assertEq(weights.length, 2);
        assertEq(weights[0], depAm1);
        assertEq(weights[1], 0);
        assertEq(totalWeight, depAm1);
    }

    function testGetWeightsAndTotal_differentCollateral() public {
        _testGetWeightsAndTotal_differentCollateral(0, address(this));
        _testGetWeightsAndTotal_differentCollateral(1, address(this));
        _testGetWeightsAndTotal_differentCollateral(2, address(this));
        _testGetWeightsAndTotal_differentCollateral(3, address(this));
        _testGetWeightsAndTotal_differentCollateral(4, address(this));
        _testGetWeightsAndTotal_differentCollateral(5, address(this));
    }

    function _testGetWeightsAndTotal_differentCollateral(uint256 vaultNumber, address otherCollateral) internal {
        address v1 = _createMockVaultWithCollateral(vaultNumber == 0 ? otherCollateral : address(collateral));
        address v2 = _createMockVaultWithCollateral(vaultNumber == 1 ? otherCollateral : address(collateral));
        address v3 = _createMockVaultWithCollateral(vaultNumber == 2 ? otherCollateral : address(collateral));
        address v4 = _createMockVaultWithCollateral(vaultNumber == 3 ? otherCollateral : address(collateral));
        address v5 = _createMockVaultWithCollateral(vaultNumber == 4 ? otherCollateral : address(collateral));
        address v6 = _createMockVaultWithCollateral(vaultNumber == 5 ? otherCollateral : address(collateral));

        AmountActiveStakeWeightProvider.AmountWPData memory data =
            AmountActiveStakeWeightProvider.AmountWPData({timestamp: uint48(block.timestamp), activeStakeAtHints: new bytes[](6)});
        // hints empty

        bytes32[] memory entities = new bytes32[](6);
        entities[0] = bytes32(uint256(uint160(v1)));
        entities[1] = bytes32(uint256(uint160(v2)));
        entities[2] = bytes32(uint256(uint160(v3)));
        entities[3] = bytes32(uint256(uint160(v4)));
        entities[4] = bytes32(uint256(uint160(v5)));
        entities[5] = bytes32(uint256(uint160(v6)));

        vm.expectRevert(AmountActiveStakeWeightProvider.DifferentVaultCollateral.selector);
        awProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function _createMockVaultWithCollateral(address collateral) internal returns (address) {
        MockVault vault = new MockVault();
        vault.setCollateral(collateral);
        return address(vault);
    }

    //      5) 0 collateral token
    function testGetWeightsAndTotal_zeroCollateral() public {
        _testGetWeightsAndTotal_zeroCollateral(0);
        _testGetWeightsAndTotal_zeroCollateral(1);
        _testGetWeightsAndTotal_zeroCollateral(2);
        _testGetWeightsAndTotal_zeroCollateral(3);
        _testGetWeightsAndTotal_zeroCollateral(4);
        _testGetWeightsAndTotal_zeroCollateral(5);
    }

    function _testGetWeightsAndTotal_zeroCollateral(uint256 vaultNumber) internal {
        address v1 = _createMockVaultWithCollateral(vaultNumber == 0 ? address(0) : address(collateral));
        address v2 = _createMockVaultWithCollateral(vaultNumber == 1 ? address(0) : address(collateral));
        address v3 = _createMockVaultWithCollateral(vaultNumber == 2 ? address(0) : address(collateral));
        address v4 = _createMockVaultWithCollateral(vaultNumber == 3 ? address(0) : address(collateral));
        address v5 = _createMockVaultWithCollateral(vaultNumber == 4 ? address(0) : address(collateral));
        address v6 = _createMockVaultWithCollateral(vaultNumber == 5 ? address(0) : address(collateral));

        AmountActiveStakeWeightProvider.AmountWPData memory data =
            AmountActiveStakeWeightProvider.AmountWPData({timestamp: uint48(block.timestamp), activeStakeAtHints: new bytes[](6)});
        // hints empty

        bytes32[] memory entities = new bytes32[](6);
        entities[0] = bytes32(uint256(uint160(v1)));
        entities[1] = bytes32(uint256(uint160(v2)));
        entities[2] = bytes32(uint256(uint160(v3)));
        entities[3] = bytes32(uint256(uint160(v4)));
        entities[4] = bytes32(uint256(uint160(v5)));
        entities[5] = bytes32(uint256(uint160(v6)));

        vm.expectRevert(AmountActiveStakeWeightProvider.InvalidVaultCollateral.selector);
        awProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function testGetWeightsAndTotal_InvalidTimestamp() public {
        AmountActiveStakeWeightProvider.AmountWPData memory data =
            AmountActiveStakeWeightProvider.AmountWPData({timestamp: 0, activeStakeAtHints: new bytes[](1)});
        // hints empty

        bytes32[] memory entities = new bytes32[](1);
        entities[0] = bytes32(uint256(uint160(address(this))));

        vm.expectRevert(AmountActiveStakeWeightProvider.InvalidTimestamp.selector);
        awProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function testGetWeightsAndTotal_EmptyEntities() public {
        AmountActiveStakeWeightProvider.AmountWPData memory data =
            AmountActiveStakeWeightProvider.AmountWPData({timestamp: 1, activeStakeAtHints: new bytes[](1)});
        // hints empty

        bytes32[] memory entities = new bytes32[](0);

        vm.expectRevert(AmountActiveStakeWeightProvider.EmptyEntities.selector);
        awProvider.getWeightsAndTotal(entities, abi.encode(data));
    }

    function testGetWeightsAndTotal_InvalidActiveStakeHints() public {
        AmountActiveStakeWeightProvider.AmountWPData memory data =
            AmountActiveStakeWeightProvider.AmountWPData({timestamp: 1, activeStakeAtHints: new bytes[](0)});
        // hints empty

        bytes32[] memory entities = new bytes32[](1);
        entities[0] = bytes32(uint256(uint160(address(this))));

        vm.expectRevert(AmountActiveStakeWeightProvider.InvalidActiveStakeHints.selector);
        awProvider.getWeightsAndTotal(entities, abi.encode(data));
    }
}
