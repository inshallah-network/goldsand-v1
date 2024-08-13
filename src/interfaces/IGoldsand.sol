// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC1155} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
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

// DepositContract.deposit(...) emits IDepositContract.DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

// pause() emits a Paused event

// unpause() emits an Unpaused event

error DuplicateDepositDataDetected();

error InvalidPubkeyLength();

error InvalidWithdrawalCredentialsLength();

error InvalidSignatureLength();

error InvalidDepositDataRoot();

error TooSmallDeposit();

bytes32 constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE"); // 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26

bytes32 constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE"); // 0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1

bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE"); // 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929

bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); // 0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3

address payable constant MAINNET_DEPOSIT_CONTRACT_ADDRESS = payable(0x00000000219ab540356cBB839Cbe05303d7705Fa);

address payable constant HOLESKY_DEPOSIT_CONTRACT_ADDRESS = payable(0x4242424242424242424242424242424242424242);

address payable constant ANVIL_DEPOSIT_CONTRACT_ADDRESS = payable(0x00000000219ab540356cBB839Cbe05303d7705Fa);

interface IGoldsand {
    function getDepositDatasLength() external view returns (uint256);

    function initialize(address payable depositContractAddress, address payable withdrawalVaultAddress) external;

    fallback() external payable;

    receive() external payable;

    function setMinEthDeposit(uint256 _minEthDeposit) external;

    function fund() external payable;

    function addDepositData(DepositData calldata _depositData) external;

    function addDepositDatas(DepositData[] calldata _depositDatas) external;

    function withdrawETH(address recipient, uint256 _amount) external;

    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) external;

    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) external;

    function recoverERC1155(address recipient, IERC1155 _token, uint256 _tokenId, uint256 _amount) external;

    function recoverBatchERC1155(
        address recipient,
        IERC1155 _token,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external;

    function emergencyWithdraw() external;

    function pause() external;

    function unpause() external;
}
