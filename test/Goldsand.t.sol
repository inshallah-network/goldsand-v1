// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console} from "forge-std/console.sol";
import {
    DepositData,
    DepositDataAdded,
    DuplicateDepositDataDetected,
    Funded,
    Goldsand,
    InvalidPubkeyLength,
    InvalidWithdrawalCredentialsLength,
    InvalidSignatureLength,
    InvalidDepositDataRoot,
    MinEthDepositSet,
    TooSmallDeposit,
    Withdrawal,
    WithdrawalFailed
} from "./../src/Goldsand.sol";
import {DeployGoldsand} from "./../script/DeployGoldsand.s.sol";
import {UpgradeGoldsand} from "./../script/UpgradeGoldsand.s.sol";
import {IDepositContract} from "./../src/interfaces/IDepositContract.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC1967} from "openzeppelin-contracts/contracts/interfaces/IERC1967.sol";
import {Lib} from "./../src/lib/Lib.sol";

contract RejectEther {
    receive() external payable {
        revert("Rejected Ether");
    }

    function callWithdraw(Goldsand goldsand) external {
        goldsand.withdraw();
    }
}

contract GoldsandTest is Test {
    Goldsand goldsand;

    address immutable USER = makeAddr("USER");
    address immutable OWNER = msg.sender;
    uint256 constant USER_STARTING_BALANCE = 256 ether;
    uint256 constant OWNER_STARTING_BALANCE = 0 ether;

    DepositData depositData1 = DepositData(
        hex"a62a1f785056741b19997a0009e15f3bd7c49e5957daa7dfee944554475baa5070248515cac5c092d69704267cdc3bcf",
        hex"00741d6ae3e9797f7f24cddd09d8a1e0812cfdf7bc8d813110c6222f220bccdc",
        hex"897d3dbe914e9dd9943252cda8cfde780545618928c8549648f280ae1e8b9975060f7d06e4dd3ee1a3fc93b09e6e2d93032665c825a09d87b1e2f516e5b54aca7e32395a5c246dcf7ecd7ddc6835c8b5c786eba4eebefb2aabc38229eb9b8f70",
        0xcc6d8b27966880acfe3eeae8b1f0b758903f2ff0e30b4f42f5b1e208b14465e2
    );
    DepositData depositData2 = DepositData(
        hex"8bdb9298e54bbaf40a703692c9fbb3cb674fe76dc5f1a5ca917d852e61b7468aea2bd117f180ba6b7f78291f71677b88",
        hex"00d4505b7d35a37ade01193cfd762aac455be47c57c9a178d46785973211f148",
        hex"91d74fa2ad35c4c85a8beb9a9ffb83c2ab25c22537177415a42ee09f9150ed9cc33110dd4010915de7e36a07eb9fb45906e33ff6eb079f330d8c3b9f702c0dc39b60fcbf7abb26c755244405c9189d076e454a9ee4873951286b8dad7938179a",
        0xc36a89f780f92023e1c947f08616d236cffa336b9c124c5b91cffaa2fbf7ad07
    );
    DepositData depositData3 = DepositData(
        hex"88748ac190b3f35ad54ca76aed3840dc9772598226d38119ba8c9af23ed5a95fa26a882ce501acb232401c7e18db83e5",
        hex"0063300fe1391b913e83a9e4e57a3e8de8f0677d5fde2dd09808135583a67362",
        hex"998a046b295638d7753ca44ddfab9d3eaf81c309f7492df1f4070321ace89f5448a180e5722fe77c3106e779f478acc704572210f96842531b0b0a6fe303c23b85af189c1a1431cd248d693e9574d66dc1b062e42dd0eb5e0bb810c971d6b537",
        0x38a9e452483b66f8f67a244903233af736fc9d887692bc4c19c7073748e9469f
    );
    DepositData depositData4 = DepositData(
        hex"ae79a6625ac81f3dc3b0d0586f484033efd8e16fc68a7e01d27d66581462acbfe8652270490122e352bcbb49c84ffd21",
        hex"00777d10e138b0dee3504f486ad34f3771b1a5eee6852100e16b530dc1379531",
        hex"b824d368238489c3187c887977e5e322850233b03c46d56ed09f84c4f97e4a17ea4b2a8b2f6c3eebf89c92777a9a6ce40b6eb92cb49122bb282fd53c0adc5224cc4bb53aa993e54b06f2ecaab4f2084a2b65a418a798c0f5233c6d80194c5eb9",
        hex"1f9614688e6335a281b880f01c6b24bac08af0b5c182d221c6a2e7785d8a572f"
    );
    DepositData depositDataWithInvalidPubkeyLength = DepositData(
        hex"1234",
        hex"0063300fe1391b913e83a9e4e57a3e8de8f0677d5fde2dd09808135583a67362",
        hex"998a046b295638d7753ca44ddfab9d3eaf81c309f7492df1f4070321ace89f5448a180e5722fe77c3106e779f478acc704572210f96842531b0b0a6fe303c23b85af189c1a1431cd248d693e9574d66dc1b062e42dd0eb5e0bb810c971d6b537",
        0x38a9e452483b66f8f67a244903233af736fc9d887692bc4c19c7073748e9469f
    );
    DepositData depositDataWithInvalidWithdrawalCredentialsLength = DepositData(
        hex"88748ac190b3f35ad54ca76aed3840dc9772598226d38119ba8c9af23ed5a95fa26a882ce501acb232401c7e18db83e5",
        hex"1234",
        hex"998a046b295638d7753ca44ddfab9d3eaf81c309f7492df1f4070321ace89f5448a180e5722fe77c3106e779f478acc704572210f96842531b0b0a6fe303c23b85af189c1a1431cd248d693e9574d66dc1b062e42dd0eb5e0bb810c971d6b537",
        0x38a9e452483b66f8f67a244903233af736fc9d887692bc4c19c7073748e9469f
    );
    DepositData depositDataWithInvalidSignatureLength = DepositData(
        hex"88748ac190b3f35ad54ca76aed3840dc9772598226d38119ba8c9af23ed5a95fa26a882ce501acb232401c7e18db83e5",
        hex"0063300fe1391b913e83a9e4e57a3e8de8f0677d5fde2dd09808135583a67362",
        hex"1234",
        0x38a9e452483b66f8f67a244903233af736fc9d887692bc4c19c7073748e9469f
    );
    DepositData depositDataWithInvalidDataRoot = DepositData(
        hex"88748ac190b3f35ad54ca76aed3840dc9772598226d38119ba8c9af23ed5a95fa26a882ce501acb232401c7e18db83e5",
        hex"0063300fe1391b913e83a9e4e57a3e8de8f0677d5fde2dd09808135583a67362",
        hex"998a046b295638d7753ca44ddfab9d3eaf81c309f7492df1f4070321ace89f5448a180e5722fe77c3106e779f478acc704572210f96842531b0b0a6fe303c23b85af189c1a1431cd248d693e9574d66dc1b062e42dd0eb5e0bb810c971d6b537",
        0x1234567890123456789012345678901234567890123456789012345678901234
    );

    function setUp() public {
        DeployGoldsand deploy = new DeployGoldsand();
        goldsand = deploy.run();
    }

    function test_AddAndFund() public {
        vm.deal(USER, USER_STARTING_BALANCE);
        vm.deal(OWNER, OWNER_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        goldsand.addDepositData(depositData1);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        goldsand.addDepositData(depositData2);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        goldsand.addDepositData(depositData3);

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 3 ether);
        goldsand.fund{value: 3 ether}();

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 67 ether);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(0)
        });
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        goldsand.fund{value: 67 ether}();

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 35 ether);
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(2)
        });
        goldsand.fund{value: 35 ether}();
    }

    function test_FundAndAdd() public {
        vm.deal(USER, USER_STARTING_BALANCE);
        vm.deal(OWNER, OWNER_STARTING_BALANCE);

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 32 * 3 ether);
        goldsand.fund{value: 32 * 3 ether}();

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(0)
        });
        goldsand.addDepositData(depositData1);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        goldsand.addDepositData(depositData2);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(2)
        });
        goldsand.addDepositData(depositData3);
    }

    function test_FundAndAddMany() public {
        vm.deal(USER, USER_STARTING_BALANCE);
        vm.deal(OWNER, OWNER_STARTING_BALANCE);

        DepositData[] memory depositDatas = new DepositData[](4);
        depositDatas[0] = depositData1;
        depositDatas[1] = depositData2;
        depositDatas[2] = depositData3;
        depositDatas[3] = depositData4;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 32 * 4 ether);
        goldsand.fund{value: 32 * 4 ether}();

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        emit DepositDataAdded(depositData2);
        emit DepositDataAdded(depositData3);
        emit DepositDataAdded(depositData4);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(0)
        });
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(2)
        });
        emit IDepositContract.DepositEvent({
            pubkey: depositData4.pubkey,
            withdrawal_credentials: depositData4.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData4.signature,
            index: Lib.to_little_endian_64(3)
        });
        goldsand.addDepositDatas(depositDatas);
    }

    function test_PartialFund() public {
        vm.deal(USER, USER_STARTING_BALANCE);
        vm.deal(OWNER, OWNER_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        goldsand.addDepositData(depositData1);

        for (uint256 i = 0; i < 64; ++i) {
            vm.prank(USER);
            vm.expectEmit(true, true, true, true);
            emit Funded(USER, 0.5 ether);
            if (i == 64 - 1) {
                emit IDepositContract.DepositEvent({
                    pubkey: depositData1.pubkey,
                    withdrawal_credentials: depositData1.withdrawalCredentials,
                    amount: Lib.to_little_endian_64(32 gwei),
                    signature: depositData1.signature,
                    index: Lib.to_little_endian_64(0)
                });
            }
            goldsand.fund{value: 0.5 ether}();
        }
    }

    function test_InvalidAddDepositData() public {
        startHoax(OWNER, OWNER_STARTING_BALANCE);

        vm.expectRevert(InvalidPubkeyLength.selector);
        goldsand.addDepositData(depositDataWithInvalidPubkeyLength);

        vm.expectRevert(InvalidWithdrawalCredentialsLength.selector);
        goldsand.addDepositData(depositDataWithInvalidWithdrawalCredentialsLength);

        vm.expectRevert(InvalidSignatureLength.selector);
        goldsand.addDepositData(depositDataWithInvalidSignatureLength);

        vm.expectRevert(InvalidDepositDataRoot.selector);
        goldsand.addDepositData(depositDataWithInvalidDataRoot);
    }

    function test_Withdraw() public {
        startHoax(USER, USER_STARTING_BALANCE);

        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 123 ether);
        goldsand.fund{value: 123 ether}();

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(OWNER);
        goldsand.pause();

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit Withdrawal(OWNER, 123 ether);
        goldsand.withdraw();

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit Withdrawal(OWNER, 0);
        goldsand.withdraw();

        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Unpaused(OWNER);
        goldsand.unpause();
    }

    function testWithdrawalFailed() public {
        RejectEther rejectEther = new RejectEther();

        startHoax(OWNER, OWNER_STARTING_BALANCE);

        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(OWNER);
        goldsand.pause();

        vm.expectEmit(true, true, true, true);
        emit OwnableUpgradeable.OwnershipTransferred(OWNER, address(rejectEther));
        goldsand.transferOwnership(address(rejectEther));

        vm.expectRevert(abi.encodeWithSelector(WithdrawalFailed.selector, address(rejectEther), 0 ether));
        rejectEther.callWithdraw(goldsand);
    }

    function test_Constructor() public {
        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        Goldsand _goldsand = new Goldsand();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _goldsand.initialize(payable(address(0)));
    }

    function test_Upgrade() public {
        UpgradeGoldsand upgrade = new UpgradeGoldsand();
        upgrade.setMostRecentlyDeployedProxy(address(goldsand));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        upgrade.run();
    }

    function test_TooSmallDeposit() public {
        startHoax(USER, USER_STARTING_BALANCE);

        vm.expectRevert(TooSmallDeposit.selector);
        goldsand.fund{value: 0.001 ether}();
    }

    function test_SetMinEthDeposit() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MinEthDepositSet(0.05 ether);
        goldsand.setMinEthDeposit(0.05 ether);

        startHoax(USER, USER_STARTING_BALANCE);

        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 0.075 ether);
        goldsand.fund{value: 0.075 ether}();

        vm.startPrank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit MinEthDepositSet(0.1 ether);
        goldsand.setMinEthDeposit(0.1 ether);
        vm.stopPrank();

        vm.expectRevert(TooSmallDeposit.selector);
        goldsand.fund{value: 0.075 ether}();
    }

    function test_Receive() public {
        startHoax(USER, USER_STARTING_BALANCE);

        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 1 ether);
        (bool receiveSuccess,) = address(goldsand).call{value: 1 ether}("");
        assertTrue(receiveSuccess);
    }

    function test_Fallback() public {
        startHoax(USER, USER_STARTING_BALANCE);

        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 1 ether);
        (bool fallbackSuccess,) = address(goldsand).call{value: 1 ether}("0x12345678");
        assertTrue(fallbackSuccess);
    }

    function test_KeepStorageAcrossUpgrade() public {
        vm.deal(USER, USER_STARTING_BALANCE);
        vm.deal(OWNER, OWNER_STARTING_BALANCE);

        assertEq(goldsand.getFundersLength(), 0);
        assertEq(goldsand.funderToBalance(USER), 0 ether);
        assertEq(goldsand.getDepositDatasLength(), 0);

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 4 ether);
        goldsand.fund{value: 4 ether}();

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        goldsand.addDepositData(depositData1);

        assertEq(goldsand.getFundersLength(), 1);
        assertEq(goldsand.funderToBalance(USER), 4 ether);
        assertEq(goldsand.getDepositDatasLength(), 1);

        UpgradeGoldsand upgrade = new UpgradeGoldsand();
        upgrade.setMostRecentlyDeployedProxy(address(goldsand));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        upgrade.run();

        assertEq(goldsand.getFundersLength(), 1);
        assertEq(goldsand.funderToBalance(USER), 4 ether);
        assertEq(goldsand.getDepositDatasLength(), 1);
    }

    function test_PreventDoubleDeposit() public {
        vm.deal(USER, USER_STARTING_BALANCE);
        vm.deal(OWNER, OWNER_STARTING_BALANCE);

        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER, 32 * 4 ether);
        goldsand.fund{value: 32 * 4 ether}();

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        goldsand.addDepositData(depositData1);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData1);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData1);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        goldsand.addDepositData(depositData2);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData2);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData2);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        goldsand.addDepositData(depositData3);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData3);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData3);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData4);
        goldsand.addDepositData(depositData4);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData4);

        vm.prank(OWNER);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        goldsand.addDepositData(depositData4);
    }
}
