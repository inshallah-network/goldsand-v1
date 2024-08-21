// SPDX-License-Identifier: UNLICENSED
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

contract ValidateDeployGoldsand is Script {
    function deploy() public returns (Goldsand) {
        vm.startBroadcast();

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
            Upgrades.deployUUPSProxy("WithdrawalVault.sol", abi.encodeCall(WithdrawalVault.initialize, (tx.origin)))
        );

        address payable proxyGoldsandAddress = payable(
            Upgrades.deployUUPSProxy(
                "Goldsand.sol",
                abi.encodeCall(Goldsand.initialize, (depositContractAddress, proxyWithdrawalVaultAddress))
            )
        );
        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function run() external returns (Goldsand) {
        return deploy();
    }
}
