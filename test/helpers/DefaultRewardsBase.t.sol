// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {DefaultOperatorRewardsFactory} from
    "@symbioticfi/rewards/src/contracts/defaultOperatorRewards/DefaultOperatorRewardsFactory.sol";
import {DefaultOperatorRewards} from
    "@symbioticfi/rewards/src/contracts/defaultOperatorRewards/DefaultOperatorRewards.sol";
import {DefaultStakerRewardsFactory} from
    "@symbioticfi/rewards/src/contracts/defaultStakerRewards/DefaultStakerRewardsFactory.sol";

import {DefaultStakerRewards} from "@symbioticfi/rewards/src/contracts/defaultStakerRewards/DefaultStakerRewards.sol";
import {DelegatorFactory} from "@symbioticfi/core/src/contracts/DelegatorFactory.sol";
import {FullRestakeDelegator} from "@symbioticfi/core/src/contracts/delegator/FullRestakeDelegator.sol";
import {IBaseDelegator} from "@symbioticfi/core/src/interfaces/delegator/IBaseDelegator.sol";
import {IBaseSlasher} from "@symbioticfi/core/src/interfaces/slasher/IBaseSlasher.sol";
import {IDefaultStakerRewards} from "@symbioticfi/rewards/src/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {INetworkRestakeDelegator} from "@symbioticfi/core/src/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IOperatorSpecificDelegator} from "@symbioticfi/core/src/interfaces/delegator/IOperatorSpecificDelegator.sol";

import {ISlasher} from "@symbioticfi/core/src/interfaces/slasher/ISlasher.sol";
import {IVault} from "@symbioticfi/core/src/interfaces/vault/IVault.sol";
import {MetadataService} from "@symbioticfi/core/src/contracts/service/MetadataService.sol";
import {NetworkMiddlewareService} from "@symbioticfi/core/src/contracts/service/NetworkMiddlewareService.sol";
import {NetworkRegistry} from "@symbioticfi/core/src/contracts/NetworkRegistry.sol";
import {NetworkRestakeDelegator} from "@symbioticfi/core/src/contracts/delegator/NetworkRestakeDelegator.sol";

import {OperatorRegistry} from "@symbioticfi/core/src/contracts/OperatorRegistry.sol";
import {OperatorSpecificDelegator} from "@symbioticfi/core/src/contracts/delegator/OperatorSpecificDelegator.sol";
import {OptInService} from "@symbioticfi/core/src/contracts/service/OptInService.sol";
import {SlasherFactory} from "@symbioticfi/core/src/contracts/SlasherFactory.sol";
import {Slasher} from "@symbioticfi/core/src/contracts/slasher/Slasher.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Token} from "./../mocks/Token.sol";

import {VaultConfigurator, IVaultConfigurator} from "@symbioticfi/core/src/contracts/VaultConfigurator.sol";
import {VaultFactory} from "@symbioticfi/core/src/contracts/VaultFactory.sol";
import {Vault} from "@symbioticfi/core/src/contracts/vault/Vault.sol";
import {VetoSlasher} from "@symbioticfi/core/src/contracts/slasher/VetoSlasher.sol";

import "./VaultBase.t.sol";

contract DefaultRewardsBaseTest is Test {
    address owner;
    address alice;
    uint256 alicePrivateKey;
    address bob;
    uint256 bobPrivateKey;

    VaultFactory vaultFactory;
    DelegatorFactory delegatorFactory;
    SlasherFactory slasherFactory;
    NetworkRegistry networkRegistry;
    OperatorRegistry operatorRegistry;
    MetadataService operatorMetadataService;
    MetadataService networkMetadataService;
    NetworkMiddlewareService networkMiddlewareService;
    OptInService networkVaultOptInService;
    OptInService operatorVaultOptInService;
    OptInService operatorNetworkOptInService;

    Token collateral;
    VaultConfigurator vaultConfigurator;

    Vault vault;
    FullRestakeDelegator delegator;
    Slasher slasher;

    DefaultStakerRewardsFactory defaultStakerRewardsFactory;

    DefaultOperatorRewardsFactory defaultOperatorRewardsFactory;

    address operator = makeAddr("operator");

    address network = makeAddr("network");
    uint48 internal slashingWindow = 1200; // 20 minutes

    function setUp() public virtual {
        owner = address(this);
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");

        vaultFactory = new VaultFactory(owner);
        delegatorFactory = new DelegatorFactory(owner);
        slasherFactory = new SlasherFactory(owner);
        networkRegistry = new NetworkRegistry();
        operatorRegistry = new OperatorRegistry();
        operatorMetadataService = new MetadataService(address(operatorRegistry));
        networkMetadataService = new MetadataService(address(networkRegistry));
        networkMiddlewareService = new NetworkMiddlewareService(address(networkRegistry));
        operatorVaultOptInService =
            new OptInService(address(operatorRegistry), address(vaultFactory), "OperatorVaultOptInService");
        operatorNetworkOptInService =
            new OptInService(address(operatorRegistry), address(networkRegistry), "OperatorNetworkOptInService");

        address vaultImpl =
            address(new Vault(address(delegatorFactory), address(slasherFactory), address(vaultFactory)));
        vaultFactory.whitelist(vaultImpl);

        address networkRestakeDelegatorImpl = address(
            new NetworkRestakeDelegator(
                address(networkRegistry),
                address(vaultFactory),
                address(operatorVaultOptInService),
                address(operatorNetworkOptInService),
                address(delegatorFactory),
                delegatorFactory.totalTypes()
            )
        );
        delegatorFactory.whitelist(networkRestakeDelegatorImpl);

        address fullRestakeDelegatorImpl = address(
            new FullRestakeDelegator(
                address(networkRegistry),
                address(vaultFactory),
                address(operatorVaultOptInService),
                address(operatorNetworkOptInService),
                address(delegatorFactory),
                delegatorFactory.totalTypes()
            )
        );
        delegatorFactory.whitelist(fullRestakeDelegatorImpl);

        address operatorSpecificDelegatorImpl = address(
            new OperatorSpecificDelegator(
                address(operatorRegistry),
                address(networkRegistry),
                address(vaultFactory),
                address(operatorVaultOptInService),
                address(operatorNetworkOptInService),
                address(delegatorFactory),
                delegatorFactory.totalTypes()
            )
        );
        delegatorFactory.whitelist(operatorSpecificDelegatorImpl);

        address slasherImpl = address(
            new Slasher(
                address(vaultFactory),
                address(networkMiddlewareService),
                address(slasherFactory),
                slasherFactory.totalTypes()
            )
        );
        slasherFactory.whitelist(slasherImpl);

        address vetoSlasherImpl = address(
            new VetoSlasher(
                address(vaultFactory),
                address(networkMiddlewareService),
                address(networkRegistry),
                address(slasherFactory),
                slasherFactory.totalTypes()
            )
        );
        slasherFactory.whitelist(vetoSlasherImpl);

        vaultConfigurator =
            new VaultConfigurator(address(vaultFactory), address(delegatorFactory), address(slasherFactory));

        collateral = new Token("Token");

        address[] memory networkLimitSetRoleHolders = new address[](1);
        networkLimitSetRoleHolders[0] = alice;
        address[] memory operatorNetworkSharesSetRoleHolders = new address[](1);
        operatorNetworkSharesSetRoleHolders[0] = alice;
        (address vault_,,) = vaultConfigurator.create(
            IVaultConfigurator.InitParams({
                version: vaultFactory.lastVersion(),
                owner: alice,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: address(collateral),
                        burner: address(0xdEaD),
                        epochDuration: 7 days,
                        depositWhitelist: false,
                        isDepositLimit: false,
                        depositLimit: 0,
                        defaultAdminRoleHolder: alice,
                        depositWhitelistSetRoleHolder: alice,
                        depositorWhitelistRoleHolder: alice,
                        isDepositLimitSetRoleHolder: alice,
                        depositLimitSetRoleHolder: alice
                    })
                ),
                delegatorIndex: 0,
                delegatorParams: abi.encode(
                    INetworkRestakeDelegator.InitParams({
                        baseParams: IBaseDelegator.BaseParams({
                            defaultAdminRoleHolder: alice,
                            hook: address(0),
                            hookSetRoleHolder: alice
                        }),
                        networkLimitSetRoleHolders: networkLimitSetRoleHolders,
                        operatorNetworkSharesSetRoleHolders: operatorNetworkSharesSetRoleHolders
                    })
                ),
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: abi.encode(ISlasher.InitParams({baseParams: IBaseSlasher.BaseParams({isBurnerHook: true})}))
            })
        );

        vault = Vault(vault_);

        address defaultStakerRewards_ =
            address(new DefaultStakerRewards(address(vaultFactory), address(networkMiddlewareService)));

        defaultStakerRewardsFactory = new DefaultStakerRewardsFactory(defaultStakerRewards_);

        address defaultOperatorRewards_ = address(new DefaultOperatorRewards(address(networkMiddlewareService)));

        defaultOperatorRewardsFactory = new DefaultOperatorRewardsFactory(defaultOperatorRewards_);
    }

    function createDefaultStakerRewards(
        uint256 adminFee,
        address vault_
    ) public returns (DefaultStakerRewards defaultStakerRewards) {
        address defaultStakerRewardsAddress = defaultStakerRewardsFactory.create(
            IDefaultStakerRewards.InitParams({
                vault: vault_,
                adminFee: adminFee,
                defaultAdminRoleHolder: address(101),
                adminFeeClaimRoleHolder: address(102),
                adminFeeSetRoleHolder: address(104)
            })
        );
        defaultStakerRewards = DefaultStakerRewards(defaultStakerRewardsAddress);
    }

    function createDefaultOperatorRewards() public returns (DefaultOperatorRewards defaultOperatorRewards) {
        address defaultOperatorRewardsAddress = defaultOperatorRewardsFactory.create();
        defaultOperatorRewards = DefaultOperatorRewards(defaultOperatorRewardsAddress);
    }

    function createVaultWithDelegator(uint64 delegatorIndex, bytes memory delegatorParams) public returns (address) {
        (address vault_,,) = vaultConfigurator.create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: alice,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: address(collateral),
                        burner: address(0xdEaD),
                        epochDuration: 7 days,
                        depositWhitelist: false,
                        isDepositLimit: false,
                        depositLimit: 0,
                        defaultAdminRoleHolder: alice,
                        depositWhitelistSetRoleHolder: alice,
                        depositorWhitelistRoleHolder: alice,
                        isDepositLimitSetRoleHolder: alice,
                        depositLimitSetRoleHolder: alice
                    })
                ),
                delegatorIndex: delegatorIndex,
                delegatorParams: delegatorParams,
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: abi.encode(ISlasher.InitParams({baseParams: IBaseSlasher.BaseParams({isBurnerHook: false})}))
            })
        );

        return vault_;
    }

    function defaultNetworkRestakeDelegatorParams() internal view returns (uint64 delegatorIndex, bytes memory delegatorParams) {
        address[] memory networkLimitSetRoleHolders = new address[](1);
        networkLimitSetRoleHolders[0] = alice;
        address[] memory operatorNetworkSharesSetRoleHolders = new address[](1);
        operatorNetworkSharesSetRoleHolders[0] = alice;

        delegatorIndex = 0;
        delegatorParams = abi.encode(
            INetworkRestakeDelegator.InitParams({
                baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: alice,
                hook: address(0),
                hookSetRoleHolder: alice
            }),
                networkLimitSetRoleHolders: networkLimitSetRoleHolders,
                operatorNetworkSharesSetRoleHolders: operatorNetworkSharesSetRoleHolders
            })
        );
    }

    function defaultOperatorSpecificDelegatorParams() internal view returns (uint64 delegatorIndex, bytes memory delegatorParams) {
        address[] memory networkLimitSetRoleHolders = new address[](1);
        networkLimitSetRoleHolders[0] = alice;
        delegatorIndex = 2;
        delegatorParams = abi.encode(
            IOperatorSpecificDelegator.InitParams({
                baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: alice,
                hook: address(0),
                hookSetRoleHolder: alice
            }),
                networkLimitSetRoleHolders: networkLimitSetRoleHolders,
                operator: operator
            })
        );
    }
}
