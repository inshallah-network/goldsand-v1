/*
 .d8888b.           888      888                                 888 
d88P  Y88b          888      888                                 888 
888    888          888      888                                 888 
888         .d88b.  888  .d88888 .d8888b   8888b.  88888b.   .d88888 
888  88888 d88""88b 888 d88" 888 88K          "88b 888 "88b d88" 888 
888    888 888  888 888 888  888 "Y8888b. .d888888 888  888 888  888 
Y88b  d88P Y88..88P 888 Y88b 888      X88 888  888 888  888 Y88b 888 
 "Y8888P88  "Y88P"  888  "Y88888  88888P' "Y888888 888  888  "Y88888 


a project by InshAllah Network to enable staking for 2B+ users around
the world.

a special thanks to:

- Imran Khan of Alliance for constant encouragement and inspiration.
- The entire InshAllah Network team for bringing this product to life.
- Most of all, God. This would not be possible without His Grace.

Bismillah...
*/

// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IDepositContract} from "./interfaces/IDepositContract.sol";
import {DepositContract} from "./DepositContract.sol";
import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    DepositData,
    DepositDataAdded,
    Funded,
    ExternalFunded,
    MinEthDepositSet,
    DuplicateDepositDataDetected,
    InvalidPubkeyLength,
    InvalidWithdrawalCredentialsLength,
    InvalidSignatureLength,
    InvalidDepositDataRoot,
    TooSmallDeposit,
    InvalidFunderAddress,
    EMERGENCY_ROLE,
    GOVERNANCE_ROLE,
    OPERATOR_ROLE,
    UPGRADER_ROLE
} from "./interfaces/IGoldsand.sol";
import {IGoldsand} from "./interfaces/IGoldsand.sol";
import {IWithdrawalVault} from "./interfaces/IWithdrawalVault.sol";
import {Lib} from "./../src/lib/Lib.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC1155} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

/**
 * @title Goldsand
 * @author Asjad Syed
 * @notice Sharia-compliant Ethereum staking for 2B+ Muslims around the world
 */
contract Goldsand is
    IGoldsand,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IERC1155Receiver
{
    /**
     * @notice Mapping of funder addresses to their balances.
     */
    mapping(address funder => uint256 balance) public funderToBalance;

    /**
     * @notice A mapping to check if we've already added a given deposit data.
     * @dev The keys are deposit data pubkeys.
     */
    mapping(bytes pubkey => bool added) public pubkeyToAdded;

    /**
     * @notice Stack of deposit data entries.
     * @dev This is pushed in addDepositData(...) and popped in depositFundsIfPossible().
     */
    DepositData[] public depositDatas;

    /**
     * @notice Address of the deposit contract.
     * @dev This is dependent on the chain we are deployed on.
     */
    address payable private depositContractAddress;

    /**
     * @notice Address of the withdrawal vault contract.
     */
    address payable public withdrawalVaultAddress;

    /**
     * @notice Minimum ETH deposit amount.
     * @dev Keeping a minimum ETH deposit amount protects us from managing tiny
     * unprofitable deposits. Set it with setMinEthDeposit(...).
     */
    uint256 private minEthDeposit;

    /**
     * @notice Gets the number of deposit datas.
     * @return The number of deposit datas.
     */
    function getDepositDatasLength() public view returns (uint256) {
        return depositDatas.length;
    }

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
     * @param _depositContractAddress The address of the deposit contract.
     * @param _withdrawalVaultAddress The address of the withdrawal vault.
     */
    function initialize(address payable _depositContractAddress, address payable _withdrawalVaultAddress)
        public
        initializer
    {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        depositContractAddress = _depositContractAddress;
        withdrawalVaultAddress = _withdrawalVaultAddress;
        minEthDeposit = 0.05 ether;
    }

    /**
     * @notice Fallback function
     * @dev Handles Ether sent directly to the contract.
     */
    fallback() external payable whenNotPaused {
        fund();
    }

    /**
     * @notice Receive function
     * @dev Handles Ether sent directly to the contract.
     */
    receive() external payable whenNotPaused {
        fund();
    }

    /**
     * @notice Sets the minimum ETH deposit amount.
     * @dev Keeping a minimum ETH deposit amount protects us from managing tiny
     * unprofitable deposits.
     * @param _minEthDeposit The new minimum ETH deposit amount.
     */
    function setMinEthDeposit(uint256 _minEthDeposit) external onlyRole(GOVERNANCE_ROLE) {
        minEthDeposit = _minEthDeposit;
        emit MinEthDepositSet(_minEthDeposit);
    }

    /**
     * @notice Deposits funds into the contract.
     * @dev If we've accumulated >32 ETH and have deposit datas, we'll call
     * the deposit contract as well.
     */
    function fund() public payable whenNotPaused {
        if (msg.value < minEthDeposit) {
            revert TooSmallDeposit();
        }
        funderToBalance[msg.sender] += msg.value;
        depositFundsIfPossible();
        emit Funded(msg.sender, msg.value);
    }

    /**
     * @notice Deposits funds into the contract but assigns the funds to
     * another account. This function can only be used by Goldsand.
     * @dev If we've accumulated >32 ETH and have deposit datas, we'll call
     * the deposit contract as well.
     */
    function externalFund(address _funderAccount) public payable onlyRole(OPERATOR_ROLE) whenNotPaused {
        if (_funderAccount == address(0)) {
            revert InvalidFunderAddress();
        }
        funderToBalance[_funderAccount] += msg.value;
        depositFundsIfPossible();
        emit ExternalFunded(msg.sender, _funderAccount, msg.value);
    }

    /**
     * @notice Deposits funds into the deposit contract if we have deposit data as well.
     */
    function depositFundsIfPossible() private whenNotPaused {
        uint256 numberOfValidatorFunds = address(this).balance / 32 ether;
        if (numberOfValidatorFunds == 0) {
            return;
        }
        uint256 numberOfDepositDatas = depositDatas.length;
        if (numberOfDepositDatas == 0) {
            return;
        }
        uint256 numberOfDeposits = Lib.min(Lib.min(numberOfValidatorFunds, numberOfDepositDatas), 100);

        for (uint256 i = 0; i < numberOfDeposits; ++i) {
            // DepositContract emits an IDepositContract.DepositEvent
            IDepositContract(depositContractAddress).deposit{value: 32 ether}(
                depositDatas[numberOfDepositDatas - 1].pubkey,
                depositDatas[numberOfDepositDatas - 1].withdrawalCredentials,
                depositDatas[numberOfDepositDatas - 1].signature,
                depositDatas[numberOfDepositDatas - 1].depositDataRoot
            );
            depositDatas.pop();
            --numberOfDepositDatas;
        }
    }

    /**
     * @notice Adds a deposit data entry to the stack.
     * @dev If we've accumulated >32 ETH, we'll call the deposit contract as well.
     * We call this periodically to top up the contract with deposit datas.
     * @param _depositData The deposit data to add.
     */
    function addDepositData(DepositData calldata _depositData) public onlyRole(OPERATOR_ROLE) whenNotPaused {
        if (_depositData.pubkey.length != 48) {
            revert InvalidPubkeyLength();
        }
        if (_depositData.withdrawalCredentials.length != 32) {
            revert InvalidWithdrawalCredentialsLength();
        }
        if (_depositData.signature.length != 96) {
            revert InvalidSignatureLength();
        }
        if (!Lib.isValidDepositDataRoot(_depositData)) {
            revert InvalidDepositDataRoot();
        }
        if (pubkeyToAdded[_depositData.pubkey]) {
            revert DuplicateDepositDataDetected();
        }

        pubkeyToAdded[_depositData.pubkey] = true;
        depositDatas.push(_depositData);
        depositFundsIfPossible();
        emit DepositDataAdded(_depositData);
    }

    /**
     * @notice Adds multiple deposit data entries to the stack.
     * @dev If we've accumulated >32 ETH, we call the deposit contract as well.
     * We call this periodically to top up the contract with deposit datas.
     * @param _depositDatas Array of deposit data entries to add.
     */
    function addDepositDatas(DepositData[] calldata _depositDatas) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        for (uint256 i = 0; i < _depositDatas.length; ++i) {
            addDepositData(_depositDatas[i]);
        }
    }

    /**
     * @notice Withdraws `_amount` of ETH to the `recipient` address.
     * @param recipient The address to receive the withdrawn ETH.
     * @param _amount The amount of ETH to withdraw.
     */
    function withdrawETH(address recipient, uint256 _amount) external onlyRole(OPERATOR_ROLE) {
        return Lib.withdrawETH(recipient, _amount);
    }

    /**
     * @notice Transfers a given `_amount` of an ERC20 token (defined by the `_token` contract address)
     * to the `recipient` address.
     * @param recipient The address to receive the recovered ERC20 tokens.
     * @param _token The ERC20 token contract.
     * @param _amount The amount of ERC20 tokens to transfer.
     */
    function recoverERC20(address recipient, IERC20 _token, uint256 _amount) external onlyRole(OPERATOR_ROLE) {
        return Lib.recoverERC20(recipient, _token, _amount);
    }

    /**
     * @notice Transfers a given ERC721 token (defined by the `_token` contract address) with `_tokenId`
     * to the `recipient` address.
     * @param recipient The address to receive the recovered ERC721 NFT.
     * @param _token The ERC721 token contract.
     * @param _tokenId The ID of the ERC721 token to transfer.
     */
    function recoverERC721(address recipient, IERC721 _token, uint256 _tokenId) external onlyRole(OPERATOR_ROLE) {
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
    function recoverERC1155(address recipient, IERC1155 _token, uint256 _tokenId, uint256 _amount)
        external
        onlyRole(OPERATOR_ROLE)
    {
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
    ) external onlyRole(OPERATOR_ROLE) {
        return Lib.recoverBatchERC1155(recipient, _token, _tokenIds, _amounts);
    }

    function onERC1155Received(
        address, // operator
        address, // from
        uint256, // id
        uint256, // value
        bytes calldata // data
    ) external pure override returns (bytes4) {
        revert IWithdrawalVault.ERC1155NotAccepted();
    }

    function onERC1155BatchReceived(
        address, // operator,
        address, // from,
        uint256[] calldata, // ids,
        uint256[] calldata, // values,
        bytes calldata // data
    ) external pure override returns (bytes4) {
        revert IWithdrawalVault.ERC1155NotAccepted();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override(IERC165, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IGoldsand).interfaceId
            || interfaceId == type(Initializable).interfaceId || interfaceId == type(AccessControlUpgradeable).interfaceId
            || interfaceId == type(PausableUpgradeable).interfaceId || interfaceId == type(UUPSUpgradeable).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /**
     * @notice Emergency function: Withdraw all funds from the contract.
     */
    function emergencyWithdraw() external onlyRole(EMERGENCY_ROLE) whenPaused {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            Lib.withdrawETH(msg.sender, balance);
        }
    }

    /**
     * @notice Emergency function: Pause the contract.
     * @dev This boilerplate function must be included to pause contracts
     * based on the Pausable module.
     */
    function pause() external onlyRole(EMERGENCY_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @notice Emergency function: Unpause the contract.
     * @dev This boilerplate function must be included to unpause contracts
     * based on the Pausable module.
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) whenPaused {
        _unpause();
    }

    /**
     * @notice Authorizes an upgrade of the contract.
     * @dev This boilerplate function must be included to upgrade contracts
     * based on the UUPS pattern.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
