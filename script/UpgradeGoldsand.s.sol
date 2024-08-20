// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "../src/Goldsand.sol";
import {WithdrawalVault} from "../src/WithdrawalVault.sol";

contract UpgradeGoldsand is Script {
    address payable proxyGoldsandAddress = payable(address(0x6353322D7E7bdDc436aBE571A46b43FAf796198b));

    function setProxyGoldsandAddress(address payable _proxyGoldsandAddress) public {
        proxyGoldsandAddress = _proxyGoldsandAddress;
    }

    function run() external {
        vm.startBroadcast();

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
        Goldsand proxyGoldsand = Goldsand(_proxyGoldsandAddress);
        address payable proxyWithdrawalVaultAddress = proxyGoldsand.withdrawalVaultAddress();
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(proxyWithdrawalVaultAddress);
        proxyGoldsand.grantRole(UPGRADER_ROLE, tx.origin);
        proxyGoldsand.upgradeToAndCall(newGoldsandImplAddress, "");
        proxyGoldsand.renounceRole(UPGRADER_ROLE, tx.origin);
        proxyWithdrawalVault.upgradeToAndCall(newWithdrawalVaultImplAddress, "");
        vm.stopBroadcast();
    }
}
