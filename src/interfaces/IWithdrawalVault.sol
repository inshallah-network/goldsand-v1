// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {IGoldsand} from "./IGoldsand.sol";

interface IWithdrawalVault {
    // Events

    event GoldsandSet(IGoldsand goldsand);

    event ETHWithdrawn(address indexed requestedBy, uint256 amount);

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
    error ETHWithdrawalFailed(address recipient, uint256 amount);
    error GoldsandZeroAddress();
    error NotEnoughEther(uint256 requested, uint256 balance);
    error ZeroAmount();

    /**
     * @notice Withdraw `_amount` of accumulated withdrawals to Goldsand contract
     * @dev Can be called only by the Goldsand contract
     * @param _amount amount of ETH to withdraw
     */
    function withdrawETH(address recipient, uint256 _amount) external;

    /**
     * Transfers a given `_amount` of an ERC20-token (defined by the `_token` contract address)
     * currently belonging to the burner contract address to the Goldsand treasury address.
     *
     * @param _token an ERC20-compatible token
     * @param _amount token amount
     */
    function recoverERC20(IERC20 _token, uint256 _amount) external;

    /**
     * Transfers a given token_id of an ERC721-compatible NFT (defined by the token contract address)
     * currently belonging to the burner contract address to the Goldsand treasury address.
     *
     * @param _token an ERC721-compatible token
     * @param _tokenId minted token id
     */
    function recoverERC721(IERC721 _token, uint256 _tokenId) external;
}
