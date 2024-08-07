// SPDX-License-Identifier: UNLICENSED
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

        // 3. Deploy the WithdrawalVault implementation contract
        WithdrawalVault newWithdrawalVaultImpl = new WithdrawalVault();

        // 4. Deploy an ERC1967Proxy with the Goldsand implementation contract and initialize it with the deposit contract address
        ERC1967Proxy proxyGoldsandERC1967 =
            new ERC1967Proxy(address(newGoldsandImpl), abi.encodeCall(Goldsand.initialize, (depositContractAddress)));
        Goldsand proxyGoldsand = Goldsand(payable(address(proxyGoldsandERC1967)));

        // 5. Deploy an ERC1967Proxy with the WithdrawalVault implementation contract and initialize it with the proxy Goldsand contract address
        ERC1967Proxy proxyWithdrawalVaultERC1967 = new ERC1967Proxy(
            address(newWithdrawalVaultImpl),
            abi.encodeCall(WithdrawalVault.initialize, (payable(address(proxyGoldsand))))
        );
        WithdrawalVault proxyWithdrawalVault = WithdrawalVault(payable(address(proxyWithdrawalVaultERC1967)));

        // 6. Set the WithdrawalVault's address in the Goldsand contract
        address payable withdrawalVaultAddress = payable(address(proxyWithdrawalVault));
        proxyGoldsand.grantRole(UPGRADER_ROLE, tx.origin);
        proxyGoldsand.setWithdrawalVaultAddress(withdrawalVaultAddress);
        proxyGoldsand.renounceRole(UPGRADER_ROLE, tx.origin);

        // 7. Give the deployer ownership of the WithdrawalVault
        proxyWithdrawalVault.transferOwnership(tx.origin);

        vm.stopBroadcast();
        return proxyGoldsand;
    }

    function run() external returns (Goldsand) {
        return deploy();
    }
}
