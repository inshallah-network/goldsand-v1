// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {DepositData} from "./../interfaces/IGoldsand.sol";
import {IWithdrawalVault} from "./../interfaces/IWithdrawalVault.sol";
import {IERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IERC721} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

library Lib {
    using SafeERC20 for IERC20;

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

    /**
     * @notice Withdraws `_amount` of ETH to the `recipient` address.
     * @param recipient The address to receive the withdrawn ETH.
     * @param _amount The amount of ETH to withdraw.
     */
    function withdrawETH(address recipient, uint256 _amount) internal {
        if (_amount == 0) {
            revert IWithdrawalVault.ZeroAmount();
        }

        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert IWithdrawalVault.NotEnoughEther(_amount, balance);
        }

        emit IWithdrawalVault.ETHWithdrawn(recipient, msg.sender, _amount);

        (bool ethWithdrawalSuccess,) = payable(recipient).call{value: _amount}("");
        if (!ethWithdrawalSuccess) {
            revert IWithdrawalVault.ETHWithdrawalFailed(recipient, _amount);
        }
    }

    /**
     * Transfers a given `_amount` of an ERC20-token (defined by the `_token` contract address)
     * to the `recipient` address.
     *
     * @param recipient The address to receive the recovered ERC20 tokens.
     * @param _token an ERC20-compatible token
     * @param _amount token amount
     */
    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) internal {
        if (_amount == 0) {
            revert IWithdrawalVault.ZeroAmount();
        }

        emit IWithdrawalVault.ERC20Recovered(recipient, msg.sender, address(_token), _amount);

        _token.safeTransfer(recipient, _amount);
    }

    /**
     * Transfers a given `_tokenId` of an ERC721-compatible NFT (defined by the `_token` contract address)
     * to the `recipient` address.
     *
     * @param recipient The address to receive the recovered ERC721 NFT.
     * @param _token an ERC721-compatible token
     * @param _tokenId minted token id
     */
    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) internal {
        emit IWithdrawalVault.ERC721Recovered(recipient, msg.sender, address(_token), _tokenId);

        _token.transferFrom(address(this), recipient, _tokenId);
    }
}
