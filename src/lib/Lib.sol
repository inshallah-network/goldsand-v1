// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {DepositData} from "./../interfaces/IGoldsand.sol";

library Lib {
    /**
     * @dev Returns the minimum of two numbers.
     * @param a First number.
     * @param b Second number.
     * @return min The minimum of the two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    uint256 constant DEPOSIT_AMOUNT = 32 ether;
    uint64 constant GWEI = 1 gwei;

    function isValidDepositDataRoot(DepositData calldata depositData) internal pure returns (bool) {
        bytes32 node = encode_node(depositData, DEPOSIT_AMOUNT);
        return node == depositData.depositDataRoot;
    }

    function encode_node(DepositData calldata depositData, uint256 amount) internal pure returns (bytes32 node) {
        bytes memory encodedAmount = to_little_endian_64(uint64(amount / GWEI));
        bytes32 pubkey_root = sha256(abi.encodePacked(depositData.pubkey, bytes16(0)));
        bytes32 signature_root = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(depositData.signature[:64])),
                sha256(abi.encodePacked(depositData.signature[64:], bytes32(0)))
            )
        );
        node = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkey_root, depositData.withdrawalCredentials)),
                sha256(abi.encodePacked(encodedAmount, bytes24(0), signature_root))
            )
        );
    }

    function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 bytesValue = bytes8(value);
        // Byteswapping during copying to bytes.
        ret[0] = bytesValue[7];
        ret[1] = bytesValue[6];
        ret[2] = bytesValue[5];
        ret[3] = bytesValue[4];
        ret[4] = bytesValue[3];
        ret[5] = bytesValue[2];
        ret[6] = bytesValue[1];
        ret[7] = bytesValue[0];
    }
}
