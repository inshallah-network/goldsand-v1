// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "../src/Goldsand.sol";
import {WithdrawalVault} from "../src/WithdrawalVault.sol";

contract UpgradeGoldsand is Script {
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

        // Deploy the Goldsand implementation contract
        Goldsand newGoldsandImpl = new Goldsand();

        // Deploy the WithdrawalVault implementation contract
        WithdrawalVault newWithdrawalVaultImpl = new WithdrawalVault();

        vm.stopBroadcast();

        // Upgrade the Goldsand implementation contract
        upgradeAddress(proxyGoldsandAddress, address(newGoldsandImpl), address(newWithdrawalVaultImpl));
    }

    function upgradeAddress(
        address payable _proxyGoldsandAddress,
        address newGoldsandImplAddress,
        address newWithdrawalVaultImplAddress
    ) public {
        vm.startBroadcast();
        address UPGRADER = tx.origin;
        Goldsand proxyGoldsand = Goldsand(_proxyGoldsandAddress);
        address payable proxyWithdrawalVaultAddress = proxyGoldsand.withdrawalVaultAddress();
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(proxyWithdrawalVaultAddress);
        proxyGoldsand.grantRole(UPGRADER_ROLE, UPGRADER);
        proxyGoldsand.upgradeToAndCall(newGoldsandImplAddress, "");
        proxyGoldsand.renounceRole(UPGRADER_ROLE, UPGRADER);
        proxyWithdrawalVault.upgradeToAndCall(newWithdrawalVaultImplAddress, "");
        vm.stopBroadcast();
    }
}
