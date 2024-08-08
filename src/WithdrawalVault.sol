// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {IERC721} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGoldsand} from "./interfaces/IGoldsand.sol";
import {IWithdrawalVault} from "./interfaces/IWithdrawalVault.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract WithdrawalVault is IWithdrawalVault, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IGoldsand public GOLDSAND;

    /**
     * @dev Constructor that disables the initializers to prevent
     * reinitialization during upgrades.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the Goldsand address.
     * @dev The initialize function supplants the constructor in upgradeable
     * contracts to separate deployment from initialization, enabling upgrades
     * without reinitialization.
     * @param goldsandAddress The address of the Goldsand contract.
     */
    function initialize(address payable goldsandAddress) public initializer {
        __Ownable_init(msg.sender);
        GOLDSAND = IGoldsand(goldsandAddress);
    }

    /**
     * @notice Withdraws `_amount` of ETH to the `recipient` address.
     * @param recipient The address to receive the withdrawn ETH.
     * @param _amount The amount of ETH to withdraw.
     */
    function withdrawETH(address recipient, uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            revert ZeroAmount();
        }

        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert NotEnoughEther(_amount, balance);
        }

        emit IWithdrawalVault.ETHWithdrawn(recipient, msg.sender, _amount);

        (bool ethWithdrawalSuccess,) = payable(recipient).call{value: _amount}("");
        if (!ethWithdrawalSuccess) {
            revert ETHWithdrawalFailed(recipient, _amount);
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
    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            revert ZeroAmount();
        }

        emit ERC20Recovered(recipient, msg.sender, address(_token), _amount);

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
    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) external onlyOwner {
        emit ERC721Recovered(recipient, msg.sender, address(_token), _tokenId);

        _token.transferFrom(address(this), address(GOLDSAND), _tokenId);
    }

    /**
     * @notice Function to receive ETH
     */
    receive() external payable {}

    /**
     * @notice Fallback function to receive ETH
     */
    fallback() external payable {}

    /**
     * @notice Authorizes an upgrade of the contract.
     * @dev This boilerplate function must be included to upgrade contracts
     * based on the UUPS pattern.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
