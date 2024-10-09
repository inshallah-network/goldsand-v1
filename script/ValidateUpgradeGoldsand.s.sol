// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "../src/Goldsand.sol";
import {WithdrawalVault} from "../src/WithdrawalVault.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/src/Options.sol";

contract ValidateUpgradeGoldsand is Script {
    address payable proxyGoldsandAddress = payable(address(0));

    function setProxyGoldsandAddress(address payable _proxyGoldsandAddress) public {
        proxyGoldsandAddress = _proxyGoldsandAddress;
    }

    function setProxyGoldsandAddressFromEnv() public {
        proxyGoldsandAddress = payable(vm.envAddress("GOLDSAND_PROXY_ADDRESS"));
    }

    function run() external {
        vm.startBroadcast();

        if (proxyGoldsandAddress == payable(address(0))) {
            setProxyGoldsandAddressFromEnv();
        }

        address UPGRADER = tx.origin;

        Options memory withdrawalVaultOptions;
        Options memory goldsandOptions;
        withdrawalVaultOptions.referenceContract = "WithdrawalVaultV1.sol:WithdrawalVault";
        goldsandOptions.referenceContract = "GoldsandV1.sol:Goldsand";

        // TODO check salt
        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);
        proxyGoldsand.grantRole(UPGRADER_ROLE, UPGRADER);
        Upgrades.upgradeProxy(proxyGoldsandAddress, "GoldsandV2.sol:Goldsand", "", goldsandOptions);
        proxyGoldsand.renounceRole(UPGRADER_ROLE, UPGRADER);
        address payable proxyWithdrawalVaultAddress = proxyGoldsand.withdrawalVaultAddress();
        Upgrades.upgradeProxy(
            proxyWithdrawalVaultAddress, "WithdrawalVaultV2.sol:WithdrawalVault", "", withdrawalVaultOptions
        );

        vm.stopBroadcast();
    }
}
