// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IWithdrawalVault} from "./IWithdrawalVault.sol";

struct DepositData {
    bytes pubkey;
    bytes withdrawalCredentials;
    bytes signature;
    bytes32 depositDataRoot;
}

event DepositDataAdded(DepositData depositData);

event Funded(address funder, uint256 amount);

event MinEthDepositSet(uint256 amount);

event Withdrawal(address recipient, uint256 amount);

event WithdrawalVaultSet(IWithdrawalVault withdrawalVault);

// DepositContract.deposit(...) emits IDepositContract.DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

// pause() emits a Paused event

// unpause() emits an Unpaused event

error DuplicateDepositDataDetected();

error WithdrawalFailed(address recipient, uint256 amount);

error WithdrawalVaultZeroAddress();

error TooSmallDeposit();

error InvalidPubkeyLength();

error InvalidWithdrawalCredentialsLength();

error InvalidSignatureLength();

error InvalidDepositDataRoot();

interface IGoldsand {
    function getFundersLength() external view returns (uint256);

    function getDepositDatasLength() external view returns (uint256);

    function initialize(address payable depositContractAddress) external;

    fallback() external payable;

    receive() external payable;

    function setWithdrawalVaultAddress(address payable withdrawalVaultAddress) external;

    function setMinEthDeposit(uint256 _minEthDeposit) external;

    function fund() external payable;

    function addDepositData(DepositData calldata _depositData) external;

    function addDepositDatas(DepositData[] calldata _depositDatas) external;

    function callWithdrawETH(uint256 withdrawalsToWithdraw) external;

    function receiveETH() external payable;

    function withdraw() external;

    function pause() external;

    function unpause() external;
}
