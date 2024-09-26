// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {
    IGoldsand,
    MAINNET_DEPOSIT_CONTRACT_ADDRESS,
    HOLESKY_DEPOSIT_CONTRACT_ADDRESS,
    ANVIL_DEPOSIT_CONTRACT_ADDRESS
} from "./../src/interfaces/IGoldsand.sol";
import {EMERGENCY_ROLE, GOVERNANCE_ROLE, OPERATOR_ROLE, UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "./../src/Goldsand.sol";
import {DepositContract} from "./../src/DepositContract.sol";
import {ERC1967Proxy} from
    "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WithdrawalVault} from "./../src/WithdrawalVault.sol";
import {console} from "forge-std/console.sol";

contract DeployGoldsand is Script {
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

        // Deploy the WithdrawalVault implementation contract
        WithdrawalVault newWithdrawalVaultImpl = new WithdrawalVault();

        // Deploy an ERC1967Proxy with the WithdrawalVault implementation contract and initialize it
        ERC1967Proxy proxyWithdrawalVaultERC1967 =
            new ERC1967Proxy(address(newWithdrawalVaultImpl), abi.encodeCall(WithdrawalVault.initialize, (UPGRADER)));
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(payable(address(proxyWithdrawalVaultERC1967)));
        console.log("Deployed WithdrawalVault proxy to address", address(proxyWithdrawalVault));

        // Deploy the Goldsand implementation contract
        Goldsand newGoldsandImpl = new Goldsand();

        // Deploy an ERC1967Proxy with the Goldsand implementation contract and initialize it
        address payable withdrawalVaultAddress = payable(address(proxyWithdrawalVault));
        ERC1967Proxy proxyGoldsandERC1967 = new ERC1967Proxy(
            address(newGoldsandImpl),
            abi.encodeCall(Goldsand.initialize, (UPGRADER, depositContractAddress, withdrawalVaultAddress))
        );
        Goldsand proxyGoldsand = Goldsand(payable(address(proxyGoldsandERC1967)));
        console.log("Deployed Goldsand proxy to address", address(proxyGoldsand));

        // Give the WithdrawalVault the Goldsand address now that Goldsand is deployed
        proxyWithdrawalVault.setOperatorAddress(OPERATOR);
        console.log("Set the Goldsand address in the WithdrawalVault");

        // Give the UPGRADER ownership of the WithdrawalVault
        proxyWithdrawalVault.transferOwnership(UPGRADER);

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function run() external returns (Goldsand) {
        return deploy();
    }
}
