// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {EMERGENCY_ROLE, GOVERNANCE_ROLE, OPERATOR_ROLE, UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "../src/Goldsand.sol";
import {IGoldsand, MAINNET_DEPOSIT_CONTRACT_ADDRESS, HOLESKY_DEPOSIT_CONTRACT_ADDRESS, ANVIL_DEPOSIT_CONTRACT_ADDRESS} from "../src/interfaces/IGoldsand.sol";
import {ERC1967Proxy} from
    "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeGoldsand is Script {
    address payable mostRecentlyDeployedProxy = payable(address(0x22b935fe868Ca243a7ab21B4B26aEd2288784540));

    function setMostRecentlyDeployedProxy(address payable proxyAddress) public {
        mostRecentlyDeployedProxy = proxyAddress;
    }

    function run() external {
        vm.startBroadcast();

        // 1. Determine the deposit contract address based on the network
        address payable depositContractAddress;
        if (block.chainid == 1) {
            depositContractAddress = MAINNET_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 17000) {
            depositContractAddress = HOLESKY_DEPOSIT_CONTRACT_ADDRESS;
        } else if (block.chainid == 31337) {
            depositContractAddress = ANVIL_DEPOSIT_CONTRACT_ADDRESS;
        } else {
            revert("Unknown network");
        }

        // 2. Deploy the Goldsand implementation contract
        Goldsand newGoldsandImpl = new Goldsand();

        vm.stopBroadcast();

        // 3. Upgrade the Goldsand implementation contract
        upgradeAddress(mostRecentlyDeployedProxy, address(newGoldsandImpl));
    }

    function upgradeAddress(address payable proxyAddress, address newGoldsandImpl) public {
        vm.startBroadcast();
        Goldsand proxyGoldsand = Goldsand(proxyAddress);
        proxyGoldsand.grantRole(UPGRADER_ROLE, tx.origin);
        proxyGoldsand.upgradeToAndCall(address(newGoldsandImpl), "");
        proxyGoldsand.renounceRole(UPGRADER_ROLE, tx.origin);
        vm.stopBroadcast();
    }
}
