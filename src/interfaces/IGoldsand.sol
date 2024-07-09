// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

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

// DepositContract.deposit(...) emits IDepositContract.DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

// pause() emits a Paused event

// unpause() emits an Unpaused event

error DuplicateDepositDataDetected();

error WithdrawalFailed(address recipient, uint256 amount);

error TooSmallDeposit();

error InvalidPubkeyLength();

error InvalidWithdrawalCredentialsLength();

error InvalidSignatureLength();

error InvalidDepositDataRoot();

interface IGoldsand {
    function initialize(address payable depositContractAddress) external;

    fallback() external payable;

    receive() external payable;

    function setMinEthDeposit(uint256 _minEthDeposit) external;

    function fund() external payable;

    function depositFundsIfPossible() external;

    function addDepositData(DepositData calldata _depositData) external;

    function addDepositDatas(DepositData[] calldata _depositDatas) external;

    function withdraw() external;

    function pause() external;

    function unpause() external;
}
