// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {
    MAINNET_DEPOSIT_CONTRACT_ADDRESS,
    HOLESKY_DEPOSIT_CONTRACT_ADDRESS,
    ANVIL_DEPOSIT_CONTRACT_ADDRESS
} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "./../src/Goldsand.sol";
import {DepositContract} from "./../src/DepositContract.sol";
import {WithdrawalVault} from "./../src/WithdrawalVault.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {Defender, ApprovalProcessResponse} from "openzeppelin-foundry-upgrades/src/Defender.sol";

contract SafeDeployGoldsand is Script {
    address OPERATOR = vm.envAddress("OPERATOR_ADDRESS");
    address UPGRADER = vm.envAddress("UPGRADER_ADDRESS");
    string internal contractSalt = vm.envString("GOLDSAND_CONTRACT_SALT");
    bytes32 internal salt = keccak256(abi.encodePacked(contractSalt));
    
    mapping(uint256 => address payable) private networkDepositAddresses;
    mapping(string => uint256) private chainToId;

    constructor() {
        chainToId["MAINNET"] = 1;
        chainToId["HOLESKY"] = 17000;
        chainToId["ANVIL"] = 31337;
        chainToId["SEPOLIA"] = 11155111;
        networkDepositAddresses[chainToId["MAINNET"]] = MAINNET_DEPOSIT_CONTRACT_ADDRESS;
        networkDepositAddresses[chainToId["HOLESKY"]] = HOLESKY_DEPOSIT_CONTRACT_ADDRESS;
    }

    function getDepositContractAddress() internal returns (address payable) {
        if (networkDepositAddresses[block.chainid] != address(0)) {
            return networkDepositAddresses[block.chainid];
        }

        if (block.chainid == chainToId["ANVIL"] || block.chainid == chainToId["SEPOLIA"]) {
            return deployTestDepositContract();
        }

        revert("Unknown network");
    }

    function deployTestDepositContract() internal returns (address payable) {
        DepositContract depositContract = new DepositContract();
        if (block.chainid == chainToId["ANVIL"]) {
            vm.etch(ANVIL_DEPOSIT_CONTRACT_ADDRESS, address(depositContract).code);
            return ANVIL_DEPOSIT_CONTRACT_ADDRESS;
        }
        return payable(address(depositContract));
    }

    function getDeploymentOptions(bool useDefender) internal returns (Options memory, ApprovalProcessResponse memory) {
        Options memory opts;
        ApprovalProcessResponse memory upgradeApprovalProcess;

        if (useDefender) {
            upgradeApprovalProcess = Defender.getUpgradeApprovalProcess();

            if (upgradeApprovalProcess.via == address(0)) {
                revert(
                    string.concat(
                        "Upgrade approval process with id ",
                        upgradeApprovalProcess.approvalProcessId,
                        " has no assigned address"
                    )
                );
            }

            opts.defender.salt = salt;
            opts.defender.skipLicenseType = true;
            opts.defender.useDefenderDeploy = true;
        } else {
            upgradeApprovalProcess.via = tx.origin;
        }

        return (opts, upgradeApprovalProcess);
    }

    function deploy(bool useDefender) public returns (Goldsand) {
        vm.startBroadcast();
        console.log("env var:", contractSalt);

        (Options memory opts, ApprovalProcessResponse memory upgradeApprovalProcess) = getDeploymentOptions(useDefender);

        if (useDefender) {
            console.logBytes32(salt);
        }

        address payable depositContractAddress = getDepositContractAddress();

        address payable proxyWithdrawalVaultAddress = payable(
            Upgrades.deployUUPSProxy(
                "WithdrawalVault.sol", abi.encodeCall(WithdrawalVault.initialize, (upgradeApprovalProcess.via)), opts
            )
        );
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(proxyWithdrawalVaultAddress);
        console.log("Deployed WithdrawalVault proxy to address", address(proxyWithdrawalVault));

        address payable proxyGoldsandAddress = payable(
            Upgrades.deployUUPSProxy(
                "Goldsand.sol",
                abi.encodeCall(Goldsand.initialize, (UPGRADER, depositContractAddress, proxyWithdrawalVaultAddress)),
                opts
            )
        );
        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);
        console.log("Deployed Goldsand proxy to address", address(proxyGoldsand));

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function postDeploy(address payable proxyGoldsandAddress) public {
        vm.startBroadcast();

        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(proxyGoldsand.withdrawalVaultAddress());

        // Give the WithdrawalVault the Goldsand address now that Goldsand is deployed
        proxyWithdrawalVault.setOperatorAddress(OPERATOR);
        console.log("Set the Goldsand address in the WithdrawalVault");

        // Give the UPGRADER ownership of the WithdrawalVault
        proxyWithdrawalVault.transferOwnership(UPGRADER);

        vm.stopBroadcast();
    }

    function run() external returns (Goldsand) {
        bool useDefender = vm.envBool("USE_DEFENDER_DEPLOY");
        return deploy(useDefender);
    }
}
