// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {IGoldsand} from "./IGoldsand.sol";

interface IWithdrawalVault {
    // Events

    /**
     * Emitted when `amount` of ETH is withdrawn
     * to the `recipient` address by `requestedBy` sender.
     */
    event ETHWithdrawn(address recipient, address indexed requestedBy, uint256 amount);

    /**
     * Emitted when the ERC20 `token` recovered (i.e. transferred)
     * to the `recipient` address by `requestedBy` sender.
     */
    event ERC20Recovered(address recipient, address indexed requestedBy, address indexed token, uint256 amount);

    /**
     * Emitted when the ERC721-compatible `token` (NFT) recovered (i.e. transferred)
     * to the `recipient` address by `requestedBy` sender.
     */
    event ERC721Recovered(address recipient, address indexed requestedBy, address indexed token, uint256 tokenId);

    // Errors
    error ETHWithdrawalFailed(address recipient, uint256 amount);
    error NotEnoughEther(uint256 requested, uint256 balance);
    error ZeroAmount();

    function withdrawETH(address recipient, uint256 _amount) external;

    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) external;

    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) external;
}
