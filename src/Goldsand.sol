// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console} from "forge-std/console.sol";
import {IDepositContract} from "./interfaces/IDepositContract.sol";
import {DepositContract} from "./DepositContract.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

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

error WithdrawalFailed(address recipient, uint256 amount);

error TooSmallDeposit();

error InvalidPubkeyLength();

error InvalidWithdrawalCredentialsLength();

error InvalidSignatureLength();

error InvalidDepositDataRoot();

library Lib {
    /**
     * @dev Returns the minimum of two numbers.
     * @param a First number.
     * @param b Second number.
     * @return min The minimum of the two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    uint256 constant DEPOSIT_AMOUNT = 32 ether;
    uint64 constant GWEI = 1 gwei;

    function isValidDepositDataRoot(DepositData calldata depositData) internal pure returns (bool) {
        bytes32 node = encode_node(depositData, DEPOSIT_AMOUNT);
        return node == depositData.depositDataRoot;
    }

    function slice(bytes memory a, uint32 offset, uint32 size) internal pure returns (bytes memory result) {
        result = new bytes(size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = a[offset + i];
        }
    }

    function encode_node(DepositData calldata depositData, uint256 amount) internal pure returns (bytes32) {
        bytes16 zero_bytes16;
        bytes24 zero_bytes24;
        bytes32 zero_bytes32;
        bytes32 pubkey_root = sha256(abi.encodePacked(depositData.pubkey, zero_bytes16));
        bytes32 signature_root = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(slice(depositData.signature, 0, 64))),
                sha256(abi.encodePacked(slice(depositData.signature, 64, 32), zero_bytes32))
            )
        );
        bytes memory encodedAmount = to_little_endian_64(uint64(amount / GWEI));
        return sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkey_root, depositData.withdrawalCredentials)),
                sha256(abi.encodePacked(encodedAmount, zero_bytes24, signature_root))
            )
        );
    }

    function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 bytesValue = bytes8(value);
        // Byteswapping during copying to bytes.
        ret[0] = bytesValue[7];
        ret[1] = bytesValue[6];
        ret[2] = bytesValue[5];
        ret[3] = bytesValue[4];
        ret[4] = bytesValue[3];
        ret[5] = bytesValue[2];
        ret[6] = bytesValue[1];
        ret[7] = bytesValue[0];
    }
}

contract Goldsand is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    address[] public funders;
    mapping(address funder => uint256 balance) public funderToBalance;

    DepositData[] public depositDatas;

    address payable private DEPOSIT_CONTRACT_ADDRESS;
    uint256 private minEthDeposit;

    constructor() {
        _disableInitializers();
    }

    function initialize(address payable depositContractAddress) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
        DEPOSIT_CONTRACT_ADDRESS = depositContractAddress;
        minEthDeposit = 0.05 ether;
    }

    fallback() external payable whenNotPaused {
        fund();
    }

    receive() external payable whenNotPaused {
        fund();
    }

    function setMinEthDeposit(uint256 _minEthDeposit) external onlyOwner {
        minEthDeposit = _minEthDeposit;
        emit MinEthDepositSet(_minEthDeposit);
    }

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

    function depositFundsIfPossible() internal whenNotPaused {
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

    function addDepositData(DepositData calldata _depositData) public whenNotPaused {
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

    function addDepositDatas(DepositData[] calldata _depositDatas) public whenNotPaused {
        for (uint256 i = 0; i < _depositDatas.length; ++i) {
            addDepositData(_depositDatas[i]);
        }
    }

    function withdraw() external onlyOwner whenPaused {
        uint256 balance = address(this).balance;
        (bool withdrawSuccess,) = payable(msg.sender).call{value: balance}("");
        if (!withdrawSuccess) {
            revert WithdrawalFailed(msg.sender, balance);
        }
        emit Withdrawal(msg.sender, balance);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
