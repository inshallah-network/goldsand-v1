// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console} from "forge-std/console.sol";
import {IDepositContract} from "./interfaces/IDepositContract.sol";
import {DepositContract} from "./DepositContract.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    DepositData,
    DepositDataAdded,
    Funded,
    MinEthDepositSet,
    Withdrawal,
    WithdrawalFailed,
    TooSmallDeposit,
    InvalidPubkeyLength,
    InvalidWithdrawalCredentialsLength,
    InvalidSignatureLength,
    InvalidDepositDataRoot
} from "./interfaces/IGoldsand.sol";
import {Lib} from "./../src/lib/Lib.sol";

/**
 * @title Goldsand
 * @author Asjad Syed
 * @notice Sharia-compliant Ethereum staking for 2B+ Muslims around the world
 */
contract Goldsand is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    /**
     * @notice Array of funder addresses.
     * @dev Used to index into funderToBalance.
     */
    address[] public funders;

    /**
     * @notice Mapping of funder addresses to their balances.
     * @dev The keys are addresses of funders from the funders array.
     */
    mapping(address funder => uint256 balance) public funderToBalance;

    /**
     * @notice Stack of deposit data entries.
     * @dev This is pushed in addDepositData(...) and popped in depositFundsIfPossible().
     */
    DepositData[] public depositDatas;

    /**
     * @notice Address of the deposit contract.
     * @dev This is dependent on the chain we are deployed on.
     */
    address payable private DEPOSIT_CONTRACT_ADDRESS;

    /**
     * @notice Minimum ETH deposit amount.
     * @dev Keeping a minimum ETH deposit amount protects us from managing tiny
     * unprofitable deposits. Set it with setMinEthDeposit(...).
     */
    uint256 private minEthDeposit;

    /**
     * @notice Gets the number of funders.
     * @dev Only used for tests.
     * @return The number of funders.
     */
    function getFundersLength() public view returns (uint256) {
        return funders.length;
    }

    /**
     * @notice Gets the number of deposit datas.
     * @dev Only used for tests.
     * @return The number of deposit datas.
     */
    function getDepositDatasLength() public view returns (uint256) {
        return depositDatas.length;
    }

    /**
     * @dev Constructor that disables the initializers to prevent
     * reinitialization during upgrades.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the deposit contract address.
     * @dev The initialize function supplants the constructor in upgradeable
     * contracts to separate deployment from initialization, enabling upgrades
     * without reinitialization.
     * @param depositContractAddress The address of the deposit contract.
     */
    function initialize(address payable depositContractAddress) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        DEPOSIT_CONTRACT_ADDRESS = depositContractAddress;
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
    function setMinEthDeposit(uint256 _minEthDeposit) external onlyOwner {
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
        if (funderToBalance[msg.sender] == 0) {
            funders.push(msg.sender);
        }
        funderToBalance[msg.sender] += msg.value;
        depositFundsIfPossible();
        emit Funded(msg.sender, msg.value);
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
            IDepositContract(DEPOSIT_CONTRACT_ADDRESS).deposit{value: 32 ether}(
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
    function addDepositData(DepositData calldata _depositData) public onlyOwner whenNotPaused {
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
    function addDepositDatas(DepositData[] calldata _depositDatas) external onlyOwner whenNotPaused {
        for (uint256 i = 0; i < _depositDatas.length; ++i) {
            addDepositData(_depositDatas[i]);
        }
    }

    /**
     * @notice Emergency function: Withdraw all funds from the contract.
     */
    function withdraw() external onlyOwner whenPaused {
        uint256 balance = address(this).balance;
        (bool withdrawSuccess,) = payable(msg.sender).call{value: balance}("");
        if (!withdrawSuccess) {
            revert WithdrawalFailed(msg.sender, balance);
        }
        emit Withdrawal(msg.sender, balance);
    }

    /**
     * @notice Emergency function: Pause the contract.
     * @dev This boilerplate function must be included to pause contracts
     * based on the Pausable module.
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Emergency function: Unpause the contract.
     * @dev This boilerplate function must be included to unpause contracts
     * based on the Pausable module.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Authorizes an upgrade of the contract.
     * @dev This boilerplate function must be included to upgrade contracts
     * based on the UUPS pattern.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
