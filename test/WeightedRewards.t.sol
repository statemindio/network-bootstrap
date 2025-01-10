// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../src/extensions/SdkMiddlewareReader.sol";
import "../src/managers/rewards/BaseDefaultOperatorRewardsManager.sol";
import "./helpers/DefaultRewardsBase.t.sol";
import "./helpers/VaultBase.t.sol";
import {ConfigWeightProvider} from "../src/weights/ConfigWeightProvider.sol";
import {EqualStakePower} from "@symbioticfi/middleware-sdk/extensions/managers/stake-powers/EqualStakePower.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {NoKeyManager} from "@symbioticfi/middleware-sdk/extensions/managers/keys/NoKeyManager.sol";
import {ProxyReward} from "../src/extensions/rewards/ProxyReward.sol";
import {TimestampCapture} from "@symbioticfi/middleware-sdk/extensions/managers/capture-timestamps/TimestampCapture.sol";
import {WeightedRewardManager} from "../src/managers/rewards/WeightedRewardManager.sol";
import {WeightedRewardsRoles} from "../src/extensions/rewards/WeightedRewardsRoles.sol";
import {WeightedRewards} from "../src/extensions/rewards/WeightedRewards.sol";
import {SharedVaults} from "@symbioticfi/middleware-sdk/extensions/SharedVaults.sol";
import {ISharedVaults} from "@symbioticfi/middleware-sdk/interfaces/extensions/ISharedVaults.sol";
import {IWeightProvider} from "../src/interfaces/weights/IWeightProvider.sol";

contract WeightedRewardsTest is DefaultRewardsBaseTest {
    Token rewardToken;
    ConfigWeightProvider configWeightProvider;
    DefaultStakerRewards defaultStakerRewards1;
    DefaultStakerRewards defaultStakerRewards2;
    DefaultStakerRewards defaultStakerRewards3;
    DefaultOperatorRewards defaultOperatorRewards;
    TestNetworkMiddleware weightRewards;

    address carl = makeAddr("carl");
    address distributeStakerRewardsRole = makeAddr("distributeStakerRewardsRole");
    address distributeOperatorRewardsRole = makeAddr("distributeOperatorRewardsRole");
    address configProviderOwner = makeAddr("configProviderOwner");
    address distributeRewardsRole = makeAddr("distributeRewardsRole");
    address registerSharedVaultRole = makeAddr("registerSharedVaultRole");

    uint48 internal epochDuration = 600; // 10 minutes
    uint256 admin_fee = 0; // 10%
    uint256 ADMIN_FEE_BASE = 10_000;

    Vault vault2;
    Vault vault3;

    bytes32[] entities = new bytes32[](3);
    uint128[] weights = new uint128[](3);

    function setUp() public override(DefaultRewardsBaseTest) {
        DefaultRewardsBaseTest.setUp();

        // Different operators for cover BaseStakerRewardsManager._checkActiveVault()
        (uint64 delegatorIndex, bytes memory delegatorParams) = defaultNetworkRestakeDelegatorParams();
        vault = Vault(createVaultWithDelegator(delegatorIndex, delegatorParams));
        vault2 = Vault(createVaultWithDelegator(delegatorIndex, delegatorParams));
        vault3 = Vault(createVaultWithDelegator(delegatorIndex, delegatorParams));

        defaultStakerRewards1 = createDefaultStakerRewards(admin_fee, address(vault));
        defaultStakerRewards2 = createDefaultStakerRewards(admin_fee, address(vault2));
        defaultStakerRewards3 = createDefaultStakerRewards(admin_fee, address(vault3));
        address[] memory stakerRewardsDistributors = new address[](3);
        stakerRewardsDistributors[0] = address(defaultStakerRewards1);
        stakerRewardsDistributors[1] = address(defaultStakerRewards2);
        stakerRewardsDistributors[2] = address(defaultStakerRewards3);
        defaultOperatorRewards = createDefaultOperatorRewards();

        address[] memory vaults = new address[](3);
        vaults[0] = address(vault);
        vaults[1] = address(vault2);
        vaults[2] = address(vault3);

        // Нужен weightProvider
        entities[0] = bytes32(uint256(uint160(address(vault))));
        entities[1] = bytes32(uint256(uint160(address(vault2))));
        entities[2] = bytes32(uint256(uint160(address(vault3))));

        weights[0] = 2e17;
        weights[1] = 3e17;
        weights[2] = 5e17;

        configWeightProvider = new ConfigWeightProvider(configProviderOwner);
        vm.prank(configProviderOwner);
        configWeightProvider.setWalletConfigs(entities, weights);

        address reader = address(new SdkMiddlewareReader());

        // Initialize WeightedRewards
        TestNetworkMiddleware.InitializeParams memory initializeParams = TestNetworkMiddleware.InitializeParams(
            network,
            slashingWindow,
            address(vaultFactory),
            address(operatorRegistry),
            address(operatorNetworkOptInService),
            reader,
            vaults,
            stakerRewardsDistributors,
            address(defaultStakerRewardsFactory),
            address(defaultOperatorRewards),
            address(defaultOperatorRewardsFactory),
            distributeRewardsRole,
            address(configWeightProvider),
            registerSharedVaultRole
        );

        weightRewards = new TestNetworkMiddleware();
        weightRewards.initialize(initializeParams);

        rewardToken = new Token("Reward");
        rewardToken.mint(distributeRewardsRole, 10_000 ether);

        // Register middleware
        vm.startPrank(network);
        networkRegistry.registerNetwork();
        networkMiddlewareService.setMiddleware(address(weightRewards));
        vm.stopPrank();

        // Register Vaults
        vm.startPrank(registerSharedVaultRole);
        weightRewards.registerSharedVault(address(vault));
        weightRewards.registerSharedVault(address(vault2));
        weightRewards.registerSharedVault(address(vault3));
        vm.stopPrank();

        // Deposit into Vaults
        collateral.mint(carl, 100_000 ether);
        vm.startPrank(carl);
        collateral.approve(address(vault), type(uint256).max);
        collateral.approve(address(vault2), type(uint256).max);
        collateral.approve(address(vault3), type(uint256).max);

        vault.deposit(carl, 1 ether);
        vault2.deposit(carl, 1 ether);
        vault3.deposit(carl, 1 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1000);
    }

    function test_distributeRewardsIncorrectRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                bytes32(WeightedRewards.distributeRewards.selector)
            )
        );
        weightRewards.distributeRewards(address(rewardToken), 1000, 0, bytes32(0), "0x");
    }

    function test_distributeRewardsZeroAmountError() public {
        vm.startPrank(distributeRewardsRole);
        vm.expectRevert(WeightedRewardManager.ZeroAmount.selector);
        weightRewards.distributeRewards(address(rewardToken), 0, 0, bytes32(0), "0x");
        vm.stopPrank();
    }

    function test_distributeRewardsZeroTokenError() public {
        vm.startPrank(distributeRewardsRole);
        vm.expectRevert(WeightedRewardManager.ZeroToken.selector);
        weightRewards.distributeRewards(address(0), 1000, 0, bytes32(0), "0x");
        vm.stopPrank();
    }

    function test_distributeRewardsOnlyForStakersInvalidRootError() public {
        vm.startPrank(distributeRewardsRole);
        rewardToken.approve(address(weightRewards), 1000);
        vm.expectRevert(WeightedRewardManager.InvalidRoot.selector);
        weightRewards.distributeRewards(
            address(rewardToken), 1000, 0, 0x0000000000000000000000000000000000000000000000000000000000000001, "0x"
        );
        vm.stopPrank();
    }

    function test_distributeRewardsOnlyForOperatorsInvalidRootError() public {
        vm.startPrank(distributeRewardsRole);
        rewardToken.approve(address(weightRewards), 1000);
        vm.expectRevert(WeightedRewardManager.InvalidRoot.selector);
        weightRewards.distributeRewards(
            address(rewardToken), 1000, 1000, 0x0000000000000000000000000000000000000000000000000000000000000000, "0x"
        );
        vm.stopPrank();
    }

    function test_distributeRewardsOnlyForStakers() public {
        uint256 distributeAmount = 100e18;
        bytes[] memory weightsAtHints = new bytes[](3);
        for (uint256 i; i < weightsAtHints.length; i++) {
            weightsAtHints[i] = "";
        }

        bytes memory configWPData =
            abi.encode(ConfigWeightProvider.ConfigWPData(uint48(block.timestamp) - 1, weightsAtHints));

        bytes[] memory stakerRewardsDistributorData = new bytes[](3);
        for (uint256 i; i < stakerRewardsDistributorData.length; i++) {
            stakerRewardsDistributorData[i] = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");
        }

        WeightedRewardManager.WeightedRewardManagerData memory weightedRewardManagerData =
            WeightedRewardManager.WeightedRewardManagerData(configWPData, stakerRewardsDistributorData);
        bytes memory data = abi.encode(weightedRewardManagerData);

        vm.startPrank(distributeRewardsRole);
        rewardToken.approve(address(weightRewards), distributeAmount);
        weightRewards.distributeRewards(address(rewardToken), distributeAmount, 0, bytes32(0), data);
        vm.stopPrank();

        bytes memory dataForClaim = abi.encode(network, type(uint256).max);
        assertEq(
            defaultStakerRewards1.claimable(address(rewardToken), carl, dataForClaim),
            distributeAmount * weights[0] / configWeightProvider.ONE()
        );
        assertEq(
            defaultStakerRewards2.claimable(address(rewardToken), carl, dataForClaim),
            distributeAmount * weights[1] / configWeightProvider.ONE()
        );
        assertEq(
            defaultStakerRewards3.claimable(address(rewardToken), carl, dataForClaim),
            distributeAmount * weights[2] / configWeightProvider.ONE()
        );
    }

    function test_distributeRewardsOnlyForOperators() public {
        uint256 distributeAmount = 100e18;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(carl, distributeAmount))));
        bytes32 root = leaf;

        vm.startPrank(distributeRewardsRole);
        rewardToken.approve(address(weightRewards), distributeAmount);
        weightRewards.distributeRewards(address(rewardToken), distributeAmount, distributeAmount, root, "0x");
        vm.stopPrank();

        assertEq(defaultOperatorRewards.root(network, address(rewardToken)), root);
        assertEq(rewardToken.balanceOf(address(defaultOperatorRewards)), distributeAmount);
    }

    function test_distributeRewardsForOperatorsAndStakers() public {
        uint256 distributeAmountForStakers = 100e18;
        uint256 distributeAmountForOperators = 1e18;
        uint256 totalDistributeAmount = distributeAmountForStakers + distributeAmountForOperators;

        // create data for stakers
        bytes[] memory weightsAtHints = new bytes[](3);
        for (uint256 i; i < weightsAtHints.length; i++) {
            weightsAtHints[i] = "";
        }

        bytes memory configWPData =
            abi.encode(ConfigWeightProvider.ConfigWPData(uint48(block.timestamp) - 1, weightsAtHints));
        bytes[] memory stakerRewardsDistributorData = new bytes[](3);
        for (uint256 i; i < stakerRewardsDistributorData.length; i++) {
            stakerRewardsDistributorData[i] = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");
        }
        WeightedRewardManager.WeightedRewardManagerData memory weightedRewardManagerData =
            WeightedRewardManager.WeightedRewardManagerData(configWPData, stakerRewardsDistributorData);
        bytes memory data = abi.encode(weightedRewardManagerData);

        // create data for operators
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(carl, distributeAmountForOperators))));
        bytes32 root = leaf;

        // distribute rewards for stakers and operators
        vm.startPrank(distributeRewardsRole);
        rewardToken.approve(address(weightRewards), totalDistributeAmount);
        weightRewards.distributeRewards(
            address(rewardToken), totalDistributeAmount, distributeAmountForOperators, root, data
        );
        vm.stopPrank();

        bytes memory dataForClaim = abi.encode(network, type(uint256).max);
        assertEq(
            defaultStakerRewards1.claimable(address(rewardToken), carl, dataForClaim),
            distributeAmountForStakers * weights[0] / configWeightProvider.ONE()
        );
        assertEq(
            defaultStakerRewards2.claimable(address(rewardToken), carl, dataForClaim),
            distributeAmountForStakers * weights[1] / configWeightProvider.ONE()
        );
        assertEq(
            defaultStakerRewards3.claimable(address(rewardToken), carl, dataForClaim),
            distributeAmountForStakers * weights[2] / configWeightProvider.ONE()
        );
    }

    function test_distributeStakerRewardsInvalidWeightsError() public {
        // set up FakeWeightProvider
        FakeWeightProvider fake = new FakeWeightProvider();
        vm.store(
            address(weightRewards),
            0x4423cc4749f187f556c2cf57bfa668c17041e10377239b7f03142dc42480f800,
            bytes32(uint256(uint160(address(fake))))
        );

        uint256 distributeAmount = 100e18;
        bytes[] memory weightsAtHints = new bytes[](3);
        for (uint256 i; i < weightsAtHints.length; i++) {
            weightsAtHints[i] = "";
        }

        bytes memory configWPData =
            abi.encode(ConfigWeightProvider.ConfigWPData(uint48(block.timestamp) - 1, weightsAtHints));

        bytes[] memory stakerRewardsDistributorData = new bytes[](3);
        for (uint256 i; i < stakerRewardsDistributorData.length; i++) {
            stakerRewardsDistributorData[i] = abi.encode(uint48(block.timestamp) - 1, uint256(admin_fee), "", "");
        }

        WeightedRewardManager.WeightedRewardManagerData memory weightedRewardManagerData =
            WeightedRewardManager.WeightedRewardManagerData(configWPData, stakerRewardsDistributorData);
        bytes memory data = abi.encode(weightedRewardManagerData);

        vm.startPrank(distributeRewardsRole);
        rewardToken.approve(address(weightRewards), distributeAmount);
        vm.expectRevert(WeightedRewardManager.InvalidWeights.selector);
        weightRewards.distributeRewards(address(rewardToken), distributeAmount, 0, bytes32(0), data);
        vm.stopPrank();
    }
}

contract TestNetworkMiddleware is WeightedRewardsRoles, SharedVaults, NoKeyManager, EqualStakePower, TimestampCapture {

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
        address operatorRewardsDistributor;
        address operatorRewardsRegistry;
        address distributeRewardsRole;
        address weightProvider;
        address registerSharedVault;
    }

    function initialize(InitializeParams memory initializeParams) external initializer {
        __BaseMiddleware_init(
            initializeParams.network,
            initializeParams.slashingWindow,
            initializeParams.vaultRegistry,
            initializeParams.operatorRegistry,
            initializeParams.operatorNetOptIn,
            initializeParams.reader
        );
        __RewardWeightProviderStorage_init(initializeParams.weightProvider);
        __BaseDefaultRewardsManager_init(
            initializeParams.operatorRewardsDistributor, initializeParams.operatorRewardsRegistry
        );
        __BaseDefaultStakerRewardsManager_init(
            initializeParams.vaults, initializeParams.stakerRewardsDistributors, initializeParams.stakerRewardRegistry
        );
        __WeightedRewardsRoles_init(initializeParams.distributeRewardsRole);
        bytes4 selector = ISharedVaults.registerSharedVault.selector;
        _setSelectorRole(selector, selector);
        _grantRole(selector, initializeParams.registerSharedVault);
    }
}

contract FakeWeightProvider is IWeightProvider {

    uint64 public constant TYPE = 1;

    function getWeightsAndTotal(
        bytes32[] memory entities,
        bytes memory /*data*/
    ) public pure override returns (uint256[] memory weights, uint256 totalWeight) {
        weights = new uint256[](entities.length);
        for (uint256 i; i < entities.length; i++) {
            weights[i] = 0;
        }
        return (weights, 0);
    }
}
