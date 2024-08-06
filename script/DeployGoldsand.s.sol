// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IGoldsand, MAINNET_DEPOSIT_CONTRACT_ADDRESS, HOLESKY_DEPOSIT_CONTRACT_ADDRESS, ANVIL_DEPOSIT_CONTRACT_ADDRESS} from "./../src/interfaces/IGoldsand.sol";
import {EMERGENCY_ROLE, GOVERNANCE_ROLE, OPERATOR_ROLE, UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "./../src/Goldsand.sol";
import {DepositContract} from "./../src/DepositContract.sol";
import {ERC1967Proxy} from
    "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WithdrawalVault} from "./../src/WithdrawalVault.sol";

contract DeployGoldsand is Script {
    function deploy() public returns (Goldsand) {
        vm.startBroadcast();

        // 1. Determine the deposit contract address based on the network
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

        // 2. Deploy the Goldsand implementation contract
        Goldsand newGoldsandImpl = new Goldsand();

        // 3. Deploy the ERC1967Proxy with the Goldsand implementation contract and initialize it with the deposit contract address
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(newGoldsandImpl), abi.encodeCall(Goldsand.initialize, (depositContractAddress)));
        Goldsand proxyGoldsand = Goldsand(payable(address(proxy)));

        // 4. Deploy the WithdrawalVault contract, set its address in the Goldsand contract, and transfer ownership to the proxy
        proxyGoldsand.grantRole(UPGRADER_ROLE, tx.origin);
        WithdrawalVault withdrawalVault = new WithdrawalVault(payable(address(proxyGoldsand)));
        address payable withdrawalVaultAddress = payable(address(withdrawalVault));
        proxyGoldsand.setWithdrawalVaultAddress(withdrawalVaultAddress);
        proxyGoldsand.renounceRole(UPGRADER_ROLE, tx.origin);

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function run() external returns (Goldsand) {
        return deploy();
    }
}
