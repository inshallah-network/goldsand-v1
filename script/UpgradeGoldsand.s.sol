// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Goldsand} from "../src/Goldsand.sol";
import "../src/Goldsand.sol" as ContractA;
import "../src/Goldsand.sol" as ContractB;
import "../script/DeployGoldsand.s.sol" as DeployContractB;

import {ERC1967Proxy} from
    "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeGoldsand is Script {
    address mostRecentlyDeployedProxy = address(0x7251315da4a59d86222eBe99df30d92c10187D93);

    function setMostRecentlyDeployedProxy(address proxyAddress) public {
        mostRecentlyDeployedProxy = proxyAddress;
    }

    function run() external returns (address) {
        vm.startBroadcast();
        Goldsand goldsand = new Goldsand();
        vm.stopBroadcast();
        address proxy = upgradeAddress(mostRecentlyDeployedProxy, address(goldsand));
        return proxy;
    }

    function upgradeAddress(address proxyAddress, address newGoldsandImpl) public returns (address) {
        vm.startBroadcast();
        ContractA.Goldsand proxy = ContractA.Goldsand(payable(proxyAddress));
        proxy.upgradeToAndCall(address(newGoldsandImpl), "");
        vm.stopBroadcast();
        return address(proxy);
    }
}
