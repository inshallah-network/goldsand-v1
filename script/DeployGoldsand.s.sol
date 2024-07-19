// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IGoldsand} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "./../src/Goldsand.sol";
import {DepositContract} from "./../src/DepositContract.sol";
import {ERC1967Proxy} from
    "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WithdrawalVault} from "./../src/WithdrawalVault.sol";

contract DeployGoldsand is Script {
    address payable constant MAINNET_DEPOSIT_CONTRACT_ADDRESS = payable(0x00000000219ab540356cBB839Cbe05303d7705Fa);
    address payable constant HOLESKY_DEPOSIT_CONTRACT_ADDRESS = payable(0x4242424242424242424242424242424242424242);

    function deploy() public returns (address) {
        vm.startBroadcast();
        Goldsand goldsand = new Goldsand();
        address payable depositContractAddress;

        if (block.chainid == 1) {
            depositContractAddress = MAINNET_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 17000) {
            depositContractAddress = HOLESKY_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 31337) {
            DepositContract depositContract = new DepositContract();
            depositContractAddress = payable(address(depositContract));
        } else {
            revert("Unknown network");
        }
        WithdrawalVault withdrawalVault = new WithdrawalVault();
        address payable withdrawalVaultAddress = payable(address(withdrawalVault));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(goldsand), abi.encodeCall(Goldsand.initialize, (depositContractAddress, withdrawalVaultAddress))
        );
        withdrawalVault.setGoldsand(IGoldsand(payable(address(proxy))));

        vm.stopBroadcast();
        return address(proxy);
    }

    function run() external returns (Goldsand) {
        return Goldsand(payable(address(deploy())));
    }
}
