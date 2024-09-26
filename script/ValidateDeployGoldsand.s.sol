// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {
    MAINNET_DEPOSIT_CONTRACT_ADDRESS,
    HOLESKY_DEPOSIT_CONTRACT_ADDRESS,
    ANVIL_DEPOSIT_CONTRACT_ADDRESS
} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "./../src/Goldsand.sol";
import {DepositContract} from "./../src/DepositContract.sol";
import {WithdrawalVault} from "./../src/WithdrawalVault.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {console} from "forge-std/console.sol";

contract ValidateDeployGoldsand is Script {
    function deploy() public returns (Goldsand) {
        vm.startBroadcast();

        address OPERATOR = vm.envAddress("OPERATOR_ADDRESS");
        address UPGRADER = tx.origin;

        // Determine the deposit contract address based on the network
        address payable depositContractAddress;
        if (block.chainid == 1) {
            depositContractAddress = MAINNET_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 17000) {
            depositContractAddress = HOLESKY_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 31337) {
            DepositContract depositContract = new DepositContract();
            vm.etch(ANVIL_DEPOSIT_CONTRACT_ADDRESS, address(depositContract).code);
            depositContractAddress = ANVIL_DEPOSIT_CONTRACT_ADDRESS;
        } else {
            revert("Unknown network");
        }

        address payable proxyWithdrawalVaultAddress = payable(
            Upgrades.deployUUPSProxy("WithdrawalVault.sol", abi.encodeCall(WithdrawalVault.initialize, (UPGRADER)))
        );
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(proxyWithdrawalVaultAddress);
        console.log("Deployed WithdrawalVault proxy to address", address(proxyWithdrawalVault));

        address payable proxyGoldsandAddress = payable(
            Upgrades.deployUUPSProxy(
                "Goldsand.sol",
                abi.encodeCall(Goldsand.initialize, (UPGRADER, depositContractAddress, proxyWithdrawalVaultAddress))
            )
        );
        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);
        console.log("Deployed Goldsand proxy to address", address(proxyGoldsand));

        // Give the WithdrawalVault the Goldsand address now that Goldsand is deployed
        proxyWithdrawalVault.setOperatorAddress(OPERATOR);
        console.log("Set the Goldsand address in the WithdrawalVault");

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function run() external returns (Goldsand) {
        return deploy();
    }
}
