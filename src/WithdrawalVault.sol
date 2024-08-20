// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {IERC1155} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGoldsand} from "./interfaces/IGoldsand.sol";
import {IWithdrawalVault} from "./interfaces/IWithdrawalVault.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Lib} from "./lib/Lib.sol";

contract WithdrawalVault is IWithdrawalVault, Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC1155Receiver {
    using SafeERC20 for IERC20;

    /**
     * @dev Constructor that disables the initializers to prevent
     * reinitialization during upgrades.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @dev The initialize function supplants the constructor in upgradeable
     * contracts to separate deployment from initialization, enabling upgrades
     * without reinitialization.
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    /**
     * @notice Withdraws `_amount` of ETH to the `recipient` address.
     * @param recipient The address to receive the withdrawn ETH.
     * @param _amount The amount of ETH to withdraw.
     */
    function withdrawETH(address recipient, uint256 _amount) external onlyOwner {
        return Lib.withdrawETH(recipient, _amount);
    }

    /**
     * @notice Transfers a given `_amount` of an ERC20 token (defined by the `_token` contract address)
     * to the `recipient` address.
     * @param recipient The address to receive the recovered ERC20 tokens.
     * @param _token The ERC20 token contract.
     * @param _amount The amount of ERC20 tokens to transfer.
     */
    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) external onlyOwner {
        return Lib.recoverERC20(recipient, _token, _amount);
    }

    /**
     * @notice Transfers a given ERC721 token (defined by the `_token` contract address) with `_tokenId`
     * to the `recipient` address.
     * @param recipient The address to receive the recovered ERC721 NFT.
     * @param _token The ERC721 token contract.
     * @param _tokenId The ID of the ERC721 token to transfer.
     */
    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) external onlyOwner {
        return Lib.recoverERC721(recipient, _token, _tokenId);
    }

    /**
     * @notice Transfers a given `_amount` of an ERC1155 token (defined by the `_token` contract address)
     * with `_tokenId` to the `recipient` address.
     * @param recipient The address to receive the recovered ERC1155 token.
     * @param _token The ERC1155 token contract.
     * @param _tokenId The ID of the ERC1155 token to transfer.
     * @param _amount The amount of ERC1155 tokens to transfer.
     */
    function recoverERC1155(address recipient, IERC1155 _token, uint256 _tokenId, uint256 _amount) external onlyOwner {
        return Lib.recoverERC1155(recipient, _token, _tokenId, _amount);
    }

    /**
     * @notice Transfers a batch of ERC1155 tokens (defined by the `_token` contract address)
     * with `_tokenIds` and corresponding `_amounts` to the `recipient` address.
     * @param recipient The address to receive the recovered ERC1155 tokens.
     * @param _token The ERC1155 token contract.
     * @param _tokenIds The IDs of the ERC1155 tokens to transfer.
     * @param _amounts The amounts of ERC1155 tokens to transfer.
     */
    function recoverBatchERC1155(
        address recipient,
        IERC1155 _token,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external onlyOwner {
        return Lib.recoverBatchERC1155(recipient, _token, _tokenIds, _amounts);
    }

    function onERC1155Received(
        address, // operator
        address, // from
        uint256, // id
        uint256, // value
        bytes calldata // data
    ) external pure override returns (bytes4) {
        revert ERC1155NotAccepted();
    }

    function onERC1155BatchReceived(
        address, // operator,
        address, // from,
        uint256[] calldata, // ids,
        uint256[] calldata, // values,
        bytes calldata // data
    ) external pure override returns (bytes4) {
        revert ERC1155NotAccepted();
    }

    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IWithdrawalVault).interfaceId
            || interfaceId == type(Initializable).interfaceId || interfaceId == type(OwnableUpgradeable).interfaceId
            || interfaceId == type(UUPSUpgradeable).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /**
     * @notice Function to receive ETH
     */
    receive() external payable {
        emit ETHReceived(msg.value, msg.sender);
    }

    /**
     * @notice Authorizes an upgrade of the contract.
     * @dev This boilerplate function must be included to upgrade contracts
     * based on the UUPS pattern.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
