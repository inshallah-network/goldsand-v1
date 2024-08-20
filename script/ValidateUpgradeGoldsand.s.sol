// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "../src/Goldsand.sol";
import {WithdrawalVault} from "../src/WithdrawalVault.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/src/Options.sol";

contract ValidateUpgradeGoldsand is Script {
    address payable proxyGoldsandAddress = payable(address(0x6353322D7E7bdDc436aBE571A46b43FAf796198b));

    function setProxyGoldsandAddress(address payable _proxyGoldsandAddress) public {
        proxyGoldsandAddress = _proxyGoldsandAddress;
    }

    function run() external {
        vm.startBroadcast();

        Options memory withdrawalVaultOptions;
        Options memory goldsandOptions;
        withdrawalVaultOptions.referenceContract = "WithdrawalVaultV1.sol:WithdrawalVault";
        goldsandOptions.referenceContract = "GoldsandV1.sol:Goldsand";

        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);
        proxyGoldsand.grantRole(UPGRADER_ROLE, tx.origin);
        Upgrades.upgradeProxy(proxyGoldsandAddress, "GoldsandV2.sol:Goldsand", "", goldsandOptions);
        proxyGoldsand.renounceRole(UPGRADER_ROLE, tx.origin);
        address payable proxyWithdrawalVaultAddress = proxyGoldsand.withdrawalVaultAddress();
        Upgrades.upgradeProxy(
            proxyWithdrawalVaultAddress, "WithdrawalVaultV2.sol:WithdrawalVault", "", withdrawalVaultOptions
        );

        vm.stopBroadcast();
    }
}
