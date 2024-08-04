// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {EMERGENCY_ROLE, GOVERNANCE_ROLE, OPERATOR_ROLE, UPGRADER_ROLE} from "./../src/interfaces/IGoldsand.sol";
import {Goldsand} from "../src/Goldsand.sol";
import {ERC1967Proxy} from
    "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeGoldsand is Script {
    address payable mostRecentlyDeployedProxy = payable(address(0x22b935fe868Ca243a7ab21B4B26aEd2288784540));

    function setMostRecentlyDeployedProxy(address payable proxyAddress) public {
        mostRecentlyDeployedProxy = proxyAddress;
    }

    function run() external {
        vm.startBroadcast();
        Goldsand goldsand = new Goldsand();
        vm.stopBroadcast();
        upgradeAddress(mostRecentlyDeployedProxy, address(goldsand));
    }

    function upgradeAddress(address payable proxyAddress, address newGoldsandImpl) public {
        vm.startBroadcast();
        Goldsand proxyGoldsand = Goldsand(proxyAddress);
        proxyGoldsand.grantRole(UPGRADER_ROLE, tx.origin);
        Goldsand proxy = Goldsand(payable(proxyAddress));
        proxy.upgradeToAndCall(address(newGoldsandImpl), "");
        proxyGoldsand.renounceRole(UPGRADER_ROLE, tx.origin);
        vm.stopBroadcast();
    }
}
