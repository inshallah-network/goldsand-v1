// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IERC721} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {IERC1155} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {IGoldsand} from "./IGoldsand.sol";

// Events

/**
 * Emitted when `amount` of ETH is received from the `sender`.
 */
event ETHReceived(uint256 amount, address sender);

/**
 * Emitted when `amount` of ETH is withdrawn
 * to the `recipient` address by `requestedBy` sender.
 */
event ETHWithdrawn(address recipient, address requestedBy, uint256 amount);

/**
 * Emitted when `amount` of ETH is withdrawn for the user
 * to the `recipient` address by `requestedBy` sender.
 */
event ETHWithdrawnForUser(address recipient, address requestedBy, uint256 amount);

/**
 * Emitted when `amount` of ERC20 `token` is recovered (i.e. transferred)
 * to the `recipient` address by `requestedBy` sender.
 */
event ERC20Recovered(address recipient, address requestedBy, address token, uint256 amount);

/**
 * Emitted when the ERC721 `token`  with `tokenId` is recovered (i.e. transferred)
 * to the `recipient` address by `requestedBy` sender.
 */
event ERC721Recovered(address recipient, address requestedBy, address token, uint256 tokenId);

/**
 * Emitted when `amount` of ERC1155 `token` with `tokenId` is recovered (i.e. transferred)
 * to the `recipient` address by `requestedBy` sender.
 */
event ERC1155Recovered(address recipient, address requestedBy, address token, uint256 tokenId, uint256 amount);

/**
 * Emitted when a batch of ERC1155 `token` with `tokenIds` and corresponding `amounts` is recovered (i.e. transferred)
 * to the `recipient` address by `requestedBy` sender.
 */
event ERC1155BatchRecovered(
    address recipient, address requestedBy, address token, uint256[] tokenIds, uint256[] amounts
);

/**
 * @dev Emitted when the Operator address is set in the WithdrawalVault.
 * @param newGoldsandProxyAddress The new Goldsand proxy address.
 * @param requestedBy The address that requested the change.
 */
event OperatorSet(address newGoldsandProxyAddress, address requestedBy);

// Errors
error ETHWithdrawalFailed(address recipient, uint256 amount);
error NotEnoughContractEther(uint256 requested, uint256 balance);
error NotEnoughUserEther(uint256 requested, uint256 balance);
error ZeroAmount();
error ERC1155NotAccepted();

interface IWithdrawalVault {
    function setOperatorAddress(address _goldsandAddress) external;

    function withdrawETHToOperator(uint256 _amount) external;

    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) external;

    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) external;

    function recoverERC1155(address recipient, IERC1155 _token, uint256 _tokenId, uint256 _amount) external;

    function recoverBatchERC1155(
        address recipient,
        IERC1155 _token,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external;

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        pure
        returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4);

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool);
}
