// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGoldsand} from "./interfaces/IGoldsand.sol";

contract WithdrawalVault {
    using SafeERC20 for IERC20;

    IGoldsand public GOLDSAND;

    // Events
    /**
     * Emitted when the ERC20 `token` recovered (i.e. transferred)
     * to the Goldsand treasury address by `requestedBy` sender.
     */
    event ERC20Recovered(address indexed requestedBy, address indexed token, uint256 amount);

    /**
     * Emitted when the ERC721-compatible `token` (NFT) recovered (i.e. transferred)
     * to the Goldsand treasury address by `requestedBy` sender.
     */
    event ERC721Recovered(address indexed requestedBy, address indexed token, uint256 tokenId);

    // Errors
    error GoldsandZeroAddress();
    error NotGoldsand();
    error NotEnoughEther(uint256 requested, uint256 balance);
    error ZeroAmount();

    constructor() {}

    function setGoldsand(IGoldsand _goldsand) external {
        if (address(_goldsand) == address(0)) {
            revert GoldsandZeroAddress();
        }

        GOLDSAND = _goldsand;
    }

    /**
     * @notice Withdraw `_amount` of accumulated withdrawals to Goldsand contract
     * @dev Can be called only by the Goldsand contract
     * @param _amount amount of ETH to withdraw
     */
    function withdrawWithdrawals(uint256 _amount) external {
        if (msg.sender != address(GOLDSAND)) {
            revert NotGoldsand();
        }
        if (_amount == 0) {
            revert ZeroAmount();
        }

        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert NotEnoughEther(_amount, balance);
        }

        GOLDSAND.receiveWithdrawals{value: _amount}();
    }

    /**
     * Transfers a given `_amount` of an ERC20-token (defined by the `_token` contract address)
     * currently belonging to the burner contract address to the Goldsand treasury address.
     *
     * @param _token an ERC20-compatible token
     * @param _amount token amount
     */
    function recoverERC20(IERC20 _token, uint256 _amount) external {
        if (_amount == 0) {
            revert ZeroAmount();
        }

        emit ERC20Recovered(msg.sender, address(_token), _amount);

        _token.safeTransfer(address(GOLDSAND), _amount);
    }

    /**
     * Transfers a given token_id of an ERC721-compatible NFT (defined by the token contract address)
     * currently belonging to the burner contract address to the Goldsand treasury address.
     *
     * @param _token an ERC721-compatible token
     * @param _tokenId minted token id
     */
    function recoverERC721(IERC721 _token, uint256 _tokenId) external {
        emit ERC721Recovered(msg.sender, address(_token), _tokenId);

        _token.transferFrom(address(this), address(GOLDSAND), _tokenId);
    }

    /**
     * @notice Get the balance of ETH held by the vault
     * @return balance of ETH in the vault
     */
    function balanceOf() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Function to receive ETH
     */
    receive() external payable {}

    /**
     * @notice Fallback function to receive ETH
     */
    fallback() external payable {}
}
