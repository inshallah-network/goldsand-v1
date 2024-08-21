// SPDX-License-Identifier: UNLICENSED
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
    function deploy() public returns (Goldsand) {
        vm.startBroadcast();

        address withdrawalVaultOwner = 0xf79639951b6d75cDfBce75d019DaDbaC437fe8f3;
        ApprovalProcessResponse memory upgradeApprovalProcess = Defender.getUpgradeApprovalProcess();

        if (upgradeApprovalProcess.via == address(0)) {
            revert(
                string.concat(
                    "Upgrade approval process with id ",
                    upgradeApprovalProcess.approvalProcessId,
                    " has no assigned address"
                )
            );
        }

        Options memory opts;
        opts.defender.salt = "random stringy";
        opts.defender.skipLicenseType = true;
        opts.defender.useDefenderDeploy = true;

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
        } else if (block.chainid == 11155111) {
            DepositContract depositContract = new DepositContract();
            depositContractAddress = payable(address(depositContract));
        } else {
            revert("Unknown network");
        }

        address payable proxyWithdrawalVaultAddress = payable(
            Upgrades.deployUUPSProxy(
                "WithdrawalVault.sol", abi.encodeCall(WithdrawalVault.initialize, (withdrawalVaultOwner)), opts
            )
        );

        address payable proxyGoldsandAddress = payable(
            Upgrades.deployUUPSProxy(
                "Goldsand.sol",
                abi.encodeCall(Goldsand.initialize, (depositContractAddress, proxyWithdrawalVaultAddress)),
                opts
            )
        );
        Goldsand proxyGoldsand = Goldsand(proxyGoldsandAddress);

        console.log("Deployed WithdrawalVault proxy to address", proxyWithdrawalVaultAddress);
        console.log("Deployed Goldsand proxy to address", proxyGoldsandAddress);

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function run() external returns (Goldsand) {
        return deploy();
    }
}
