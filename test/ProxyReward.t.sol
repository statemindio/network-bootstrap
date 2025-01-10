// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "./helpers/DefaultRewardsBase.t.sol";
import "./helpers/VaultBase.t.sol";
import {Operators} from "@symbioticfi/middleware-sdk/extensions/operators/Operators.sol";
import {IOperators} from "@symbioticfi/middleware-sdk/interfaces/extensions/operators/IOperators.sol";
import {BaseStakerRewardsManager} from "../src/managers/rewards/BaseStakerRewardsManager.sol";
import {DefaultRewardsDistributorRoles} from "../src/extensions/rewards/DefaultRewardsDistributorRoles.sol";
import {EqualStakePower} from "@symbioticfi/middleware-sdk/extensions/managers/stake-powers/EqualStakePower.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {NoKeyManager} from "@symbioticfi/middleware-sdk/extensions/managers/keys/NoKeyManager.sol";
import {ProxyRewardManager} from "../src/managers/rewards/ProxyRewardManager.sol";
import {ProxyRewardRoles} from "../src/extensions/rewards/ProxyRewardRoles.sol";
import {ProxyReward} from "../src/extensions/rewards/ProxyReward.sol";
import {TimestampCapture} from
    "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";
import {Token} from "./mocks/Token.sol";

contract ProxyRewardTest is DefaultRewardsBaseTest {
    TestMiddleware proxyReward;
    DefaultStakerRewards defaultStakerRewards;
    DefaultOperatorRewards defaultOperatorRewards;
    Token rewardToken;

    address carl = makeAddr("carl");
    address distributeStakerRewardsRole = makeAddr("distributeStakerRewardsRole");
    address distributeOperatorRewardsRole = makeAddr("distributeOperatorRewardsRole");
    address registerOperatorRole = makeAddr("registerOperatorRole");
    address registerOperatorVaultRole = makeAddr("registerOperatorVaultRole");

    uint48 internal epochDuration = 600; // 10 minutes
    uint256 admin_fee = 1000; // 10%
    uint256 ADMIN_FEE_BASE = 10_000;

    function setUp() public override {
        super.setUp();

        vm.prank(network);
        networkRegistry.registerNetwork();
        vm.startPrank(operator);
        operatorRegistry.registerOperator();
        operatorNetworkOptInService.optIn(network);
        vm.stopPrank();

        // Different operators for cover BaseStakerRewardsManager._checkActiveVault()
        (uint64 delegatorIndex, bytes memory delegatorParams) = defaultOperatorSpecificDelegatorParams();
        vault = Vault(createVaultWithDelegator(delegatorIndex, delegatorParams));

        address reader = address(new SdkMiddlewareReader());
        defaultStakerRewards = createDefaultStakerRewards(admin_fee, address(vault));
        defaultOperatorRewards = createDefaultOperatorRewards();

        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        address[] memory stakerRewardsDistributors = new address[](1);
        stakerRewardsDistributors[0] = address(defaultStakerRewards);

        TestMiddleware.InitializeParams memory initializeParams = TestMiddleware.InitializeParams(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            vaults,
            stakerRewardsDistributors,
            address(defaultStakerRewardsFactory),
            distributeStakerRewardsRole,
            distributeOperatorRewardsRole,
            address(defaultOperatorRewards),
            address(defaultOperatorRewardsFactory),
            registerOperatorRole,
            registerOperatorVaultRole
        );

        proxyReward = new TestMiddleware();
        proxyReward.initialize(initializeParams);

        rewardToken = new Token("Reward");
        rewardToken.mint(distributeStakerRewardsRole, 10_000_000e18);
        rewardToken.mint(distributeOperatorRewardsRole, 10_000_000e18);

        // Для депозита в Vault
        collateral.mint(carl, 10_000 ether);

        vm.startPrank(network);
        networkMiddlewareService.setMiddleware(address(proxyReward));
        vm.stopPrank();

        vm.prank(registerOperatorRole);
        proxyReward.registerOperator(operator, new bytes(0), address(0));
        // Register Vaults
        vm.prank(registerOperatorVaultRole);
        proxyReward.registerOperatorVault(operator, address(vault));

        // carl deposit into vaults
        vm.startPrank(carl);
        collateral.approve(address(vault), 1 ether);
        vault.deposit(carl, 1 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1000);
    }

    function test_distributeStakerRewardsNoneRole() public {
        bytes memory dataForDistributor = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");
        ProxyRewardManager.StakerRewardsData memory data =
            ProxyRewardManager.StakerRewardsData(address(vault), 100e18, address(rewardToken), dataForDistributor);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(ProxyReward.distributeStakerRewards.selector)
            )
        );
        proxyReward.distributeStakerRewards(data);
    }

    function test_distributeStakerRewardsSuccess() public {
        uint256 distributeAmount = 100e18;
        bytes memory dataForDistributor = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");

        ProxyRewardManager.StakerRewardsData memory data = ProxyRewardManager.StakerRewardsData(
            address(vault), distributeAmount, address(rewardToken), dataForDistributor
        );

        vm.startPrank(distributeStakerRewardsRole);
        rewardToken.approve(address(proxyReward), distributeAmount);
        proxyReward.distributeStakerRewards(data);
        vm.stopPrank();

        vm.startPrank(carl);
        bytes memory dataForClaim = abi.encode(network, type(uint256).max);
        uint256 claimableAmount = defaultStakerRewards.claimable(address(rewardToken), carl, dataForClaim);
        vm.stopPrank();

        assertEq(claimableAmount, distributeAmount - distributeAmount * admin_fee / ADMIN_FEE_BASE);
    }

    function test_distributeOperatorRewardsNoneRole() public {
        uint256 distributeAmount = 100e18;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(carl, distributeAmount))));
        bytes32 root = leaf;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(ProxyReward.distributeOperatorRewards.selector)
            )
        );
        proxyReward.distributeOperatorRewards(address(rewardToken), distributeAmount, root);
    }

    function test_distributeOperatorRewardsSuccess() public {
        uint256 distributeAmount = 100e18;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(carl, distributeAmount))));
        bytes32 root = leaf;

        vm.startPrank(distributeOperatorRewardsRole);
        rewardToken.approve(address(proxyReward), distributeAmount);
        proxyReward.distributeOperatorRewards(address(rewardToken), distributeAmount, root);
        vm.stopPrank();

        assertEq(defaultOperatorRewards.root(network, address(rewardToken)), root);
        assertEq(rewardToken.balanceOf(address(defaultOperatorRewards)), distributeAmount);
    }

    function test_distributeStakerRewardsBatchSuccess() public {
        uint256 distributeAmount = 100e18;
        bytes memory dataForDistributor = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");

        ProxyRewardManager.StakerRewardsData[] memory batchData = new ProxyRewardManager.StakerRewardsData[](2);
        batchData[0] = ProxyRewardManager.StakerRewardsData(
            address(vault), distributeAmount, address(rewardToken), dataForDistributor
        );

        batchData[1] = ProxyRewardManager.StakerRewardsData(
            address(vault), distributeAmount, address(rewardToken), dataForDistributor
        );

        vm.startPrank(distributeStakerRewardsRole);
        rewardToken.approve(address(proxyReward), 2 * distributeAmount);
        proxyReward.distributeStakerRewardsBatch(batchData);
        vm.stopPrank();

        vm.startPrank(carl);
        bytes memory dataForClaim = abi.encode(network, type(uint256).max);
        uint256 claimableAmount = defaultStakerRewards.claimable(address(rewardToken), carl, dataForClaim);
        vm.stopPrank();

        assertEq(claimableAmount, 2 * (distributeAmount - distributeAmount * admin_fee / ADMIN_FEE_BASE));
    }

    function test_distributeStakerRewardsBatchEmptyData() public {
        ProxyRewardManager.StakerRewardsData[] memory batchData = new ProxyRewardManager.StakerRewardsData[](0);

        vm.startPrank(distributeStakerRewardsRole);
        vm.expectRevert(ProxyReward.EmptyData.selector);
        proxyReward.distributeStakerRewardsBatch(batchData);
        vm.stopPrank();
    }

    function test_distributeStakerRewardsBatchNoneRole() public {
        ProxyRewardManager.StakerRewardsData[] memory batchData = new ProxyRewardManager.StakerRewardsData[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(ProxyReward.distributeStakerRewardsBatch.selector)
            )
        );
        proxyReward.distributeStakerRewardsBatch(batchData);
    }

    function test_distributeStakerRewardsZeroAmount() public {
        uint256 distributeAmount = 0;
        bytes memory dataForDistributor = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");

        ProxyRewardManager.StakerRewardsData memory data = ProxyRewardManager.StakerRewardsData(
            address(vault), distributeAmount, address(rewardToken), dataForDistributor
        );

        vm.startPrank(distributeStakerRewardsRole);
        vm.expectRevert(ProxyRewardManager.ZeroAmount.selector);
        proxyReward.distributeStakerRewards(data);
        vm.stopPrank();
    }

    function test_distributeStakerRewardsZeroToken() public {
        uint256 distributeAmount = 100e18;
        bytes memory dataForDistributor = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");

        ProxyRewardManager.StakerRewardsData memory data =
            ProxyRewardManager.StakerRewardsData(address(vault), distributeAmount, address(0), dataForDistributor);

        vm.startPrank(distributeStakerRewardsRole);
        vm.expectRevert(ProxyRewardManager.ZeroToken.selector);
        proxyReward.distributeStakerRewards(data);
        vm.stopPrank();
    }

    function test_distributeStakerRewardsZeroVault() public {
        uint256 distributeAmount = 100e18;
        bytes memory dataForDistributor = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");

        ProxyRewardManager.StakerRewardsData memory data =
            ProxyRewardManager.StakerRewardsData(address(0), distributeAmount, address(rewardToken), dataForDistributor);

        vm.startPrank(distributeStakerRewardsRole);
        vm.expectRevert(BaseStakerRewardsManager.ZeroVault.selector);
        proxyReward.distributeStakerRewards(data);
        vm.stopPrank();
    }

    function test_distributeOperatorRewardsZeroToken() public {
        uint256 distributeAmount = 100e18;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(carl, distributeAmount))));
        bytes32 root = leaf;

        vm.startPrank(distributeOperatorRewardsRole);
        vm.expectRevert(ProxyRewardManager.ZeroToken.selector);
        proxyReward.distributeOperatorRewards(address(0), distributeAmount, root);
        vm.stopPrank();
    }

    function test_distributeOperatorRewardsZeroAmount() public {
        uint256 distributeAmount = 100e18;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(carl, distributeAmount))));
        bytes32 root = leaf;

        vm.startPrank(distributeOperatorRewardsRole);
        vm.expectRevert(ProxyRewardManager.ZeroAmount.selector);
        proxyReward.distributeOperatorRewards(address(rewardToken), 0, root);
        vm.stopPrank();
    }
}

contract TestMiddleware is ProxyRewardRoles, Operators, NoKeyManager, EqualStakePower, TimestampCapture {
    struct InitializeParams {
        address network;
        uint48 slashingWindow;
        address vaultRegistry;
        address operatorRegistry;
        address operatorNetOptIn;
        address reader;
        address[] vaults;
        address[] stakerRewardsDistributors;
        address stakerRewardRegistry;
        address distributeStakerRewardsRole;
        address distributeOperatorRewardsRole;
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        address registerOperator;
        address registerOperatorVault;
    }

    function initialize(InitializeParams memory initializeParams) public initializer {
        __BaseMiddleware_init(
            initializeParams.network,
            initializeParams.slashingWindow,
            initializeParams.vaultRegistry,
            initializeParams.operatorRegistry,
            initializeParams.operatorNetOptIn,
            initializeParams.reader
        );
        __ProxyRewardRoles_init(
            initializeParams.distributeStakerRewardsRole, initializeParams.distributeOperatorRewardsRole
        );
        __BaseDefaultRewardsManager_init(
            initializeParams.operatorRewardsDistributor, initializeParams.operatorRewardsRegistry
        );
        __BaseDefaultStakerRewardsManager_init(
            initializeParams.vaults, initializeParams.stakerRewardsDistributors, initializeParams.stakerRewardRegistry
        );
        bytes4 selector = IOperators.registerOperator.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, initializeParams.registerOperator);
        selector = IOperators.registerOperatorVault.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, initializeParams.registerOperatorVault);
    }
}
