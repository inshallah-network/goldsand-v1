// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

interface IWithdrawalVault {
    event WithdrawalsReceived(uint256 amount);

    function withdrawWithdrawals(uint256 _amount) external;
}
