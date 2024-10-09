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
    address OPERATOR = address(0);
    address UPGRADER = address(0);

    function setOperatorMultisigAddress(address _operator) public {
        OPERATOR = _operator;
    }

    function setUpgraderMultisigAddress(address _upgrader) public {
        UPGRADER = _upgrader;
    }

    function setOperatorMultisigAddressFromEnv() public {
        OPERATOR = vm.envAddress("OPERATOR_MULTISIG_ADDRESS");
    }

    function setUpgraderMultisigAddressFromEnv() public {
        UPGRADER = vm.envAddress("UPGRADER_MULTISIG_ADDRESS");
    }

    function deploy() public returns (Goldsand) {
        vm.startBroadcast();

        if (OPERATOR == address(0)) {
            setOperatorMultisigAddressFromEnv();
        }

        if (UPGRADER == address(0)) {
            setUpgraderMultisigAddressFromEnv();
        } else {
            UPGRADER = tx.origin;
        }

        // Determine the deposit contract address based on the network
        address payable depositContractAddress;
        if (block.chainid == 1) {
            depositContractAddress = MAINNET_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 17000) {
            depositContractAddress = HOLESKY_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 31337) {
            DepositContract depositContract = new DepositContract();
            depositContractAddress = payable(address(depositContract));
        } else if (block.chainid == 11155111) {
            DepositContract depositContract = new DepositContract();
            depositContractAddress = payable(address(depositContract));
        } else {
            revert("Unknown network");
        }

        address payable proxyWithdrawalVaultAddress = payable(
            Upgrades.deployUUPSProxy("WithdrawalVault.sol", abi.encodeCall(WithdrawalVault.initialize, (tx.origin)))
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
