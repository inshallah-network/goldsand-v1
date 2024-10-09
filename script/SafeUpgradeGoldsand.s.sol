// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {
    IGoldsand,
    UPGRADER_ROLE,
    MAINNET_DEPOSIT_CONTRACT_ADDRESS,
    HOLESKY_DEPOSIT_CONTRACT_ADDRESS,
    ANVIL_DEPOSIT_CONTRACT_ADDRESS
} from "./../src/interfaces/IGoldsand.sol";
import {Options} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {
    ProposeUpgradeResponse, Defender, ApprovalProcessResponse
} from "openzeppelin-foundry-upgrades/src/Defender.sol";

contract SafeUpgradeGoldsand is Script {
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

        bool upgradeGoldsand = true;
        bool upgradeWithdrawalVault = false;
        require(
            upgradeGoldsand != upgradeWithdrawalVault,
            "Only upgrade one contract at a time, or else the other upgrade gets cancelled/rejected in Safe"
        );

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

        Options memory withdrawalVaultOptions;
        Options memory goldsandOptions;
        withdrawalVaultOptions.referenceContract = "WithdrawalVaultV1.sol:WithdrawalVault";
        withdrawalVaultOptions.defender.salt = keccak256(abi.encodePacked(vm.envString("GOLDSAND_CONTRACT_SALT")));
        withdrawalVaultOptions.defender.skipLicenseType = true;
        withdrawalVaultOptions.defender.useDefenderDeploy = true;
        goldsandOptions.referenceContract = "GoldsandV1.sol:Goldsand";
        goldsandOptions.defender.salt = keccak256(abi.encodePacked(vm.envString("GOLDSAND_CONTRACT_SALT")));
        goldsandOptions.defender.skipLicenseType = true;
        goldsandOptions.defender.useDefenderDeploy = true;

        IGoldsand proxyGoldsand = IGoldsand(proxyGoldsandAddress);
        address payable proxyWithdrawalVaultAddress = proxyGoldsand.withdrawalVaultAddress();

        if (upgradeGoldsand) {
            ProposeUpgradeResponse memory goldsandResponse =
                Defender.proposeUpgrade(proxyGoldsandAddress, "GoldsandV2.sol:Goldsand", goldsandOptions);
            console.log("Goldsand Proposal ID", goldsandResponse.proposalId);
            console.log("Goldsand URL", goldsandResponse.url);
        }

        if (upgradeWithdrawalVault) {
            ProposeUpgradeResponse memory withdrawalVaultResponse = Defender.proposeUpgrade(
                proxyWithdrawalVaultAddress, "WithdrawalVaultV2.sol:WithdrawalVault", withdrawalVaultOptions
            );
            console.log("WithdrawalVault Proposal ID", withdrawalVaultResponse.proposalId);
            console.log("WithdrawalVault URL", withdrawalVaultResponse.url);
        }

        vm.stopBroadcast();
    }
}
