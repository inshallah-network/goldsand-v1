// SPDX-FileCopyrightText: 2024 InshAllah Network <info@inshallah.network>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Goldsand} from "./../src/Goldsand.sol";
import {
    DepositData,
    DepositDataAdded,
    DepositDataPopped,
    DepositDatasCleared,
    EmergencyWithdrawn,
    Funded,
    FundedOnBehalf,
    MinEthDepositSet,
    DuplicateDepositDataDetected,
    EmergencyWithdrawalFailed,
    InsufficientDepositDatas,
    InvalidPubkeyLength,
    InvalidWithdrawalCredentialsLength,
    InvalidSignatureLength,
    InvalidDepositDataRoot,
    InvalidFunderAddress,
    TooSmallDeposit,
    EMERGENCY_ROLE,
    GOVERNANCE_ROLE,
    OPERATOR_ROLE,
    UPGRADER_ROLE
} from "./../src/interfaces/IGoldsand.sol";
import {
    ERC20Recovered,
    ERC721Recovered,
    ERC1155Recovered,
    ERC1155BatchRecovered,
    ERC1155NotAccepted,
    ETHWithdrawalFailed,
    ETHWithdrawn,
    ETHWithdrawnForUser,
    GoldsandSet,
    NotEnoughContractEther,
    NotEnoughUserEther,
    ZeroAmount
} from "./../src/interfaces/IWithdrawalVault.sol";
import {IGoldsand} from "./../src/interfaces/IGoldsand.sol";
import {WithdrawalVault} from "./../src/WithdrawalVault.sol";
import {DeployGoldsand} from "./../script/DeployGoldsand.s.sol";
import {UpgradeGoldsand} from "./../script/UpgradeGoldsand.s.sol";
import {IDepositContract} from "./../src/interfaces/IDepositContract.sol";
import {IWithdrawalVault} from "./../src/interfaces/IWithdrawalVault.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC1155, IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {IERC1967} from "openzeppelin-contracts/contracts/interfaces/IERC1967.sol";
import {Lib} from "./../src/lib/Lib.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

contract MyERC20 is ERC20 {
    constructor() ERC20("Test", "TEST") {
        this;
    }

    function mint(address _account, uint256 _amount) public {
        _mint(_account, _amount);
    }
}

contract MyERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        this;
    }

    uint256 private _lastTokenId;

    function mint() public {
        _mint(msg.sender, ++_lastTokenId);
    }

    function transfer(address from, address to, uint256 tokenId) public {
        _transfer(from, to, tokenId);
    }
}

contract MyERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        _mintBatch(to, ids, amounts, data);
    }

    function update(address from, address to, uint256[] memory ids, uint256[] memory values) public {
        _update(from, to, ids, values);
    }
}

contract RejectEther {
    receive() external payable {
        revert("Rejected Ether");
    }

    function callEmergencyWithdraw(IGoldsand proxyGoldsand) external {
        proxyGoldsand.emergencyWithdraw();
    }

    function callFund(IGoldsand proxyGoldsand, uint256 amount) external {
        proxyGoldsand.fund{value: amount}();
    }
}

contract GoldsandTest is Test {
    Goldsand goldsand;
    IGoldsand proxyGoldsand;
    IWithdrawalVault proxyWithdrawalVault;
    RejectEther rejectEther;
    MyERC20 myERC20;
    MyERC721 myERC721;
    MyERC1155 myERC1155;

    address immutable USER1 = makeAddr("USER1"); // 0x856243F11eFbE357db89aeb2DC809768cC055b1B
    address immutable USER2 = makeAddr("USER2"); // 0x0B229287723Ca8eEb2Dbb7B926f94909026b55f8
    address immutable OWNER = msg.sender; // 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    address immutable EMERGENCY = makeAddr("EMERGENCY"); // 0x4721cB0D6C1215210b1C1979Cb90446366344A7E
    address immutable GOVERNANCE = makeAddr("GOVERNANCE"); // 0xFC538Ae3f25F29Bfc39188Dbe726D46cbf3D00C6
    address immutable OPERATOR = makeAddr("OPERATOR"); // 0xd1b0c5cBF884fcc27dAF9f733739b39FB0B7DAa1
    address immutable UPGRADER = makeAddr("UPGRADER"); // 0x8B1D4B40080A998c21c5175fC6f0dd531Fe2Cb5E
    uint256 constant OWNER_STARTING_BALANCE = 0 ether;
    uint256 constant USER1_STARTING_BALANCE = 256 ether;
    uint256 constant USER2_STARTING_BALANCE = 256 ether;
    uint256 constant OPERATOR_STARTING_BALANCE = 256 ether;
    uint256 constant WITHDRAWAL_VAULT_STARTING_BALANCE = 16 ether;
    uint256 constant REJECT_ETHER_STARTING_BALANCE = 256 ether;

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
    DepositData depositDataWithInvalidDepositDataRoot = DepositData(
        hex"88748ac190b3f35ad54ca76aed3840dc9772598226d38119ba8c9af23ed5a95fa26a882ce501acb232401c7e18db83e5",
        hex"0063300fe1391b913e83a9e4e57a3e8de8f0677d5fde2dd09808135583a67362",
        hex"998a046b295638d7753ca44ddfab9d3eaf81c309f7492df1f4070321ace89f5448a180e5722fe77c3106e779f478acc704572210f96842531b0b0a6fe303c23b85af189c1a1431cd248d693e9574d66dc1b062e42dd0eb5e0bb810c971d6b537",
        0x1234567890123456789012345678901234567890123456789012345678901234
    );

    function setUp() public {
        DeployGoldsand deploy = new DeployGoldsand();
        goldsand = deploy.run();
        proxyGoldsand = IGoldsand(goldsand);
        proxyWithdrawalVault = IWithdrawalVault(proxyGoldsand.withdrawalVaultAddress());

        vm.prank(msg.sender);
        goldsand.grantRole(EMERGENCY_ROLE, EMERGENCY);
        vm.prank(msg.sender);
        goldsand.grantRole(GOVERNANCE_ROLE, GOVERNANCE);
        vm.prank(msg.sender);
        goldsand.grantRole(OPERATOR_ROLE, OPERATOR);
        vm.prank(msg.sender);
        goldsand.grantRole(UPGRADER_ROLE, UPGRADER);

        rejectEther = new RejectEther();
        myERC20 = new MyERC20();
        myERC721 = new MyERC721("Test", "TEST");
        myERC1155 = new MyERC1155();
    }

    function test_AddAndFund() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        proxyGoldsand.addDepositData(depositData2);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        proxyGoldsand.addDepositData(depositData3);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 3 ether);
        proxyGoldsand.fund{value: 3 ether}();

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 67 ether);
        proxyGoldsand.fund{value: 67 ether}();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(0)
        });
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        proxyGoldsand.depositFundsIfPossible();

        vm.prank(USER1);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(2)
        });
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 35 ether);
        proxyGoldsand.fund{value: 35 ether}();
    }

    function test_FundAndAdd() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 32 * 3 ether);
        proxyGoldsand.fund{value: 32 * 3 ether}();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(0)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        proxyGoldsand.addDepositData(depositData2);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(2)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        proxyGoldsand.addDepositData(depositData3);
    }

    function test_FundAndAddMany() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        DepositData[] memory depositDatas = new DepositData[](4);
        depositDatas[0] = depositData1;
        depositDatas[1] = depositData2;
        depositDatas[2] = depositData3;
        depositDatas[3] = depositData4;

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 32 * 4 ether);
        proxyGoldsand.fund{value: 32 * 4 ether}();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(0)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(2)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData4.pubkey,
            withdrawal_credentials: depositData4.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData4.signature,
            index: Lib.to_little_endian_64(3)
        });
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData4);
        proxyGoldsand.addDepositDatas(depositDatas);
    }

    function test_PopDepositData() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectRevert(InsufficientDepositDatas.selector);
        proxyGoldsand.popDepositData();

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        assertEq(proxyGoldsand.getDepositDatasLength(), 1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        proxyGoldsand.addDepositData(depositData2);

        assertEq(proxyGoldsand.getDepositDatasLength(), 2);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData2);
        proxyGoldsand.popDepositData();

        assertEq(proxyGoldsand.getDepositDatasLength(), 1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData1);
        proxyGoldsand.popDepositData();

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectRevert(InsufficientDepositDatas.selector);
        proxyGoldsand.popDepositData();

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);
    }

    function test_PopDepositDatas() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        DepositData[] memory depositDatas = new DepositData[](4);
        depositDatas[0] = depositData1;
        depositDatas[1] = depositData2;
        depositDatas[2] = depositData3;
        depositDatas[3] = depositData4;

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectRevert(InsufficientDepositDatas.selector);
        proxyGoldsand.popDepositDatas(1);

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData4);
        proxyGoldsand.addDepositDatas(depositDatas);

        assertEq(proxyGoldsand.getDepositDatasLength(), 4);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData4);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData3);
        proxyGoldsand.popDepositDatas(2);

        assertEq(proxyGoldsand.getDepositDatasLength(), 2);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData2);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData1);
        proxyGoldsand.popDepositDatas(2);

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectRevert(InsufficientDepositDatas.selector);
        proxyGoldsand.popDepositDatas(1);

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);
    }

    function test_ClearDepositDatas() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        DepositData[] memory depositDatas = new DepositData[](4);
        depositDatas[0] = depositData1;
        depositDatas[1] = depositData2;
        depositDatas[2] = depositData3;
        depositDatas[3] = depositData4;

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDatasCleared();
        proxyGoldsand.clearDepositDatas();

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData4);
        proxyGoldsand.addDepositDatas(depositDatas);

        assertEq(proxyGoldsand.getDepositDatasLength(), 4);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData4);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData3);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData2);
        vm.expectEmit(true, true, true, true);
        emit DepositDataPopped(depositData1);
        vm.expectEmit(true, true, true, true);
        emit DepositDatasCleared();
        proxyGoldsand.clearDepositDatas();

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDatasCleared();
        proxyGoldsand.clearDepositDatas();

        assertEq(proxyGoldsand.getDepositDatasLength(), 0);
    }

    function test_PartialFund() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        for (uint256 i = 0; i < 64; ++i) {
            vm.prank(USER1);
            vm.expectEmit(true, true, true, true);
            emit Funded(USER1, 0.5 ether);
            if (i == 64 - 1) {
                emit IDepositContract.DepositEvent({
                    pubkey: depositData1.pubkey,
                    withdrawal_credentials: depositData1.withdrawalCredentials,
                    amount: Lib.to_little_endian_64(32 gwei),
                    signature: depositData1.signature,
                    index: Lib.to_little_endian_64(0)
                });
            }
            proxyGoldsand.fund{value: 0.5 ether}();
        }
    }

    function test_PartialFundOnBehalfAccount() public {
        vm.deal(OPERATOR, OPERATOR_STARTING_BALANCE);
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        for (uint256 i = 0; i < 64; ++i) {
            vm.prank(OPERATOR);
            vm.expectEmit(true, true, true, true);
            emit FundedOnBehalf(OPERATOR, USER1, 0.5 ether);
            if (i == 64 - 1) {
                emit IDepositContract.DepositEvent({
                    pubkey: depositData1.pubkey,
                    withdrawal_credentials: depositData1.withdrawalCredentials,
                    amount: Lib.to_little_endian_64(32 gwei),
                    signature: depositData1.signature,
                    index: Lib.to_little_endian_64(0)
                });
            }
            proxyGoldsand.fundOnBehalf{value: 0.5 ether}(USER1);
        }
    }

    function test_AddAndFundOnBehalfAccount() public {
        vm.deal(OPERATOR, OPERATOR_STARTING_BALANCE);
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        proxyGoldsand.addDepositData(depositData2);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        proxyGoldsand.addDepositData(depositData3);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit FundedOnBehalf(OPERATOR, USER1, 3 ether);
        proxyGoldsand.fundOnBehalf{value: 3 ether}(USER1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit FundedOnBehalf(OPERATOR, USER1, 67 ether);
        proxyGoldsand.fundOnBehalf{value: 67 ether}(USER1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData3.pubkey,
            withdrawal_credentials: depositData3.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData3.signature,
            index: Lib.to_little_endian_64(0)
        });
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData2.pubkey,
            withdrawal_credentials: depositData2.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData2.signature,
            index: Lib.to_little_endian_64(1)
        });
        proxyGoldsand.depositFundsIfPossible();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit FundedOnBehalf(OPERATOR, USER1, 35 ether);
        proxyGoldsand.fundOnBehalf{value: 35 ether}(USER1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit IDepositContract.DepositEvent({
            pubkey: depositData1.pubkey,
            withdrawal_credentials: depositData1.withdrawalCredentials,
            amount: Lib.to_little_endian_64(32 gwei),
            signature: depositData1.signature,
            index: Lib.to_little_endian_64(2)
        });
        proxyGoldsand.depositFundsIfPossible();
    }

    function test_FundOnBehalfAccount_RevertsIfFunderIsZeroAddress() public {
        vm.deal(OPERATOR, OPERATOR_STARTING_BALANCE);
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectRevert(InvalidFunderAddress.selector);
        proxyGoldsand.fundOnBehalf{value: 1 ether}(address(0));
    }

    function test_InvalidAddDepositData() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectRevert(InvalidPubkeyLength.selector);
        proxyGoldsand.addDepositData(depositDataWithInvalidPubkeyLength);

        vm.prank(OPERATOR);
        vm.expectRevert(InvalidWithdrawalCredentialsLength.selector);
        proxyGoldsand.addDepositData(depositDataWithInvalidWithdrawalCredentialsLength);

        vm.prank(OPERATOR);
        vm.expectRevert(InvalidSignatureLength.selector);
        proxyGoldsand.addDepositData(depositDataWithInvalidSignatureLength);

        vm.prank(OPERATOR);
        vm.expectRevert(InvalidDepositDataRoot.selector);
        proxyGoldsand.addDepositData(depositDataWithInvalidDepositDataRoot);
    }

    function test_EmergencyWithdrawSucceeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 123 ether);
        proxyGoldsand.fund{value: 123 ether}();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(EMERGENCY);
        proxyGoldsand.pause();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawn(EMERGENCY, 123 ether);
        proxyGoldsand.emergencyWithdraw();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawn(EMERGENCY, 0 ether);
        proxyGoldsand.emergencyWithdraw();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Unpaused(EMERGENCY);
        proxyGoldsand.unpause();

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 123 ether);
        proxyGoldsand.fund{value: 123 ether}();

        (bool callSuccess,) = payable(address(proxyWithdrawalVault)).call{value: 111 ether}("");
        assertTrue(callSuccess);

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(EMERGENCY);
        proxyGoldsand.pause();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawn(EMERGENCY, 123 ether);
        proxyGoldsand.emergencyWithdraw();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Unpaused(EMERGENCY);
        proxyGoldsand.unpause();
    }

    function test_EmergencyWithdrawalFailed() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 123 ether);
        proxyGoldsand.fund{value: 123 ether}();

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(EMERGENCY);
        proxyGoldsand.pause();

        vm.prank(msg.sender);
        goldsand.grantRole(EMERGENCY_ROLE, address(rejectEther));

        vm.expectRevert(abi.encodeWithSelector(EmergencyWithdrawalFailed.selector, address(rejectEther), 123 ether));
        rejectEther.callEmergencyWithdraw(proxyGoldsand);

        vm.prank(EMERGENCY);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Unpaused(EMERGENCY);
        proxyGoldsand.unpause();
    }

    function test_GoldsandConstructor() public {
        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        Goldsand _goldsand = new Goldsand();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _goldsand.initialize(payable(0), payable(address(0)), payable(address(0)));
    }

    function test_WithdrawalVaultConstructor() public {
        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        WithdrawalVault _withdrawalVault = new WithdrawalVault();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _withdrawalVault.initialize(payable(0));
    }

    function test_Deploy() public {
        DeployGoldsand deploy = new DeployGoldsand();

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        deploy.run();
    }

    function test_Upgrade() public {
        UpgradeGoldsand upgrade = new UpgradeGoldsand();
        upgrade.setProxyGoldsandAddress(payable(address(proxyGoldsand)));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        upgrade.run();
    }

    function test_TooSmallDeposit() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectRevert(TooSmallDeposit.selector);
        proxyGoldsand.fund{value: 0.001 ether}();
    }

    function test_SetMinEthDeposit() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(GOVERNANCE);
        vm.expectEmit(true, true, true, true);
        emit MinEthDepositSet(0.05 ether);
        proxyGoldsand.setMinEthDeposit(0.05 ether);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 0.075 ether);
        proxyGoldsand.fund{value: 0.075 ether}();

        vm.prank(GOVERNANCE);
        vm.expectEmit(true, true, true, true);
        emit MinEthDepositSet(0.1 ether);
        proxyGoldsand.setMinEthDeposit(0.1 ether);

        vm.prank(USER1);
        vm.expectRevert(TooSmallDeposit.selector);
        proxyGoldsand.fund{value: 0.075 ether}();
    }

    function test_Receive() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 1 ether);
        (bool receiveSuccess,) = address(proxyGoldsand).call{value: 1 ether}("");
        assertTrue(receiveSuccess);
    }

    function test_Fallback() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 1 ether);
        (bool fallbackSuccess,) = address(proxyGoldsand).call{value: 1 ether}("0x12345678");
        assertTrue(fallbackSuccess);
    }

    function test_KeepStorageAcrossUpgrade() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        assertEq(proxyGoldsand.funderToBalance(USER1), 0 ether);
        assertEq(proxyGoldsand.getDepositDatasLength(), 0);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 4 ether);
        proxyGoldsand.fund{value: 4 ether}();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        assertEq(proxyGoldsand.funderToBalance(USER1), 4 ether);
        assertEq(proxyGoldsand.getDepositDatasLength(), 1);

        UpgradeGoldsand upgrade = new UpgradeGoldsand();
        upgrade.setProxyGoldsandAddress(payable(address(proxyGoldsand)));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2 ** 64 - 1);
        upgrade.run();

        assertEq(proxyGoldsand.funderToBalance(USER1), 4 ether);
        assertEq(proxyGoldsand.getDepositDatasLength(), 1);
    }

    function test_PreventDoubleDeposit() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 32 * 4 ether);
        proxyGoldsand.fund{value: 32 * 4 ether}();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData1);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData1);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData2);
        proxyGoldsand.addDepositData(depositData2);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData2);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData2);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData3);
        proxyGoldsand.addDepositData(depositData3);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData3);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData3);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData4);
        proxyGoldsand.addDepositData(depositData4);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData4);

        vm.prank(OPERATOR);
        vm.expectRevert(DuplicateDepositDataDetected.selector);
        proxyGoldsand.addDepositData(depositData4);
    }

    function test_CallWithdrawETHToGoldsandNotEnoughContractEther() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        assertEq(address(proxyWithdrawalVault).balance, 0 ether);
        assertEq(address(proxyGoldsand).balance, 0 ether);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughContractEther.selector, 16 ether, 0));
        proxyWithdrawalVault.withdrawETHToGoldsand(16 ether);

        assertEq(address(proxyWithdrawalVault).balance, 0 ether);
        assertEq(address(proxyGoldsand).balance, 0 ether);
    }

    function test_CallWithdrawETHToGoldsandZeroAmount() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(ZeroAmount.selector));
        proxyWithdrawalVault.withdrawETHToGoldsand(0 ether);
    }

    function test_CallWithdrawETHToGoldsandSucceeds() public {
        vm.deal(OWNER, OWNER_STARTING_BALANCE);
        vm.deal(USER1, USER1_STARTING_BALANCE);

        (bool callSuccess,) = payable(address(proxyWithdrawalVault)).call{value: 32 ether}("");
        assertTrue(callSuccess);

        assertEq(address(proxyWithdrawalVault).balance, 32 ether);
        assertEq(address(proxyGoldsand).balance, 0 ether);
        assertEq(OWNER.balance, OWNER_STARTING_BALANCE);
        assertEq(USER1.balance, USER1_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ETHWithdrawn(address(proxyGoldsand), OWNER, 4 ether);
        proxyWithdrawalVault.withdrawETHToGoldsand(4 ether);

        assertEq(address(proxyWithdrawalVault).balance, 32 ether - 4 ether);
        assertEq(address(proxyGoldsand).balance, 4 ether);
        assertEq(OWNER.balance, OWNER_STARTING_BALANCE);
        assertEq(USER1.balance, USER1_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ETHWithdrawn(address(proxyGoldsand), OWNER, 4 ether);
        proxyWithdrawalVault.withdrawETHToGoldsand(4 ether);

        assertEq(proxyGoldsand.withdrawalVaultAddress().balance, 32 ether - 8 ether);
        assertEq(address(proxyGoldsand).balance, 8 ether);
        assertEq(OWNER.balance, OWNER_STARTING_BALANCE);
        assertEq(USER1.balance, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, USER1));
        proxyWithdrawalVault.withdrawETHToGoldsand(4 ether);

        assertEq(address(proxyWithdrawalVault).balance, 32 ether - 8 ether);
        assertEq(address(proxyGoldsand).balance, 8 ether);
        assertEq(OWNER.balance, OWNER_STARTING_BALANCE);
        assertEq(USER1.balance, USER1_STARTING_BALANCE);
    }

    function test_GoldsandBalance() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        assertNotEq(address(proxyGoldsand), address(0));

        assertEq(address(proxyGoldsand).balance, 0 ether);

        vm.prank(USER1);
        (bool withdrawSuccess,) = payable(address(proxyGoldsand)).call{value: 16 ether}("");
        assertTrue(withdrawSuccess);

        assertEq(address(proxyGoldsand).balance, 16 ether);
    }

    function test_WithdrawalVaultBalance() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        assertNotEq(address(proxyWithdrawalVault), address(0));

        assertEq(address(proxyWithdrawalVault).balance, 0 ether);

        vm.prank(USER1);
        (bool withdrawSuccess,) = payable(address(proxyWithdrawalVault)).call{value: 16 ether}("");
        assertTrue(withdrawSuccess);

        assertEq(address(proxyWithdrawalVault).balance, 16 ether);
    }

    function test_GoldsandRecoverERC20ZeroAmount() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectRevert(ZeroAmount.selector);
        proxyGoldsand.recoverERC20(USER1, myERC20, 0 ether);
    }

    function test_WithdrawalVaultRecoverERC20ZeroAmount() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectRevert(ZeroAmount.selector);
        proxyWithdrawalVault.recoverERC20(USER1, myERC20, 0 ether);
    }

    function test_GoldsandRecoverERC20Succeeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        myERC20.mint(address(proxyGoldsand), 1 ether);

        assertEq(myERC20.balanceOf(address(proxyGoldsand)), 1 ether);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ERC20Recovered(USER1, OPERATOR, address(myERC20), 0.5 ether);
        proxyGoldsand.recoverERC20(USER1, myERC20, 0.5 ether);
    }

    function test_WithdrawalVaultRecoverERC20Succeeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        myERC20.mint(address(proxyWithdrawalVault), 1 ether);

        assertEq(myERC20.balanceOf(address(proxyWithdrawalVault)), 1 ether);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ERC20Recovered(USER1, OWNER, address(myERC20), 0.5 ether);
        proxyWithdrawalVault.recoverERC20(USER1, myERC20, 0.5 ether);
    }

    function test_WithdrawalVaultRecoverERC721() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(address(proxyWithdrawalVault));
        myERC721.mint();

        assertEq(myERC721.balanceOf(USER1), 0);
        assertEq(myERC721.balanceOf(address(proxyGoldsand)), 0);
        assertEq(myERC721.balanceOf(address(proxyWithdrawalVault)), 1);

        vm.prank(address(proxyWithdrawalVault));
        myERC721.mint();

        assertEq(myERC721.balanceOf(USER1), 0);
        assertEq(myERC721.balanceOf(address(proxyGoldsand)), 0);
        assertEq(myERC721.balanceOf(address(proxyWithdrawalVault)), 2);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ERC721Recovered(USER1, OWNER, address(myERC721), 1);
        proxyWithdrawalVault.recoverERC721(USER1, myERC721, 1);

        assertEq(myERC721.balanceOf(USER1), 1);
        assertEq(myERC721.balanceOf(address(proxyGoldsand)), 0);
        assertEq(myERC721.balanceOf(address(proxyWithdrawalVault)), 1);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ERC721Recovered(USER1, OWNER, address(myERC721), 2);
        proxyWithdrawalVault.recoverERC721(USER1, myERC721, 2);

        assertEq(myERC721.balanceOf(USER1), 2);
        assertEq(myERC721.balanceOf(address(proxyGoldsand)), 0);
        assertEq(myERC721.balanceOf(address(proxyWithdrawalVault)), 0);

        vm.prank(USER1);
        myERC721.transferFrom(USER1, address(proxyGoldsand), 1);

        assertEq(myERC721.balanceOf(USER1), 1);
        assertEq(myERC721.balanceOf(address(proxyGoldsand)), 1);
        assertEq(myERC721.balanceOf(address(proxyWithdrawalVault)), 0);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ERC721Recovered(USER1, OPERATOR, address(myERC721), 1);
        proxyGoldsand.recoverERC721(USER1, myERC721, 1);

        assertEq(myERC721.balanceOf(USER1), 2);
        assertEq(myERC721.balanceOf(address(proxyGoldsand)), 0);
        assertEq(myERC721.balanceOf(address(proxyWithdrawalVault)), 0);
    }

    function test_GoldsandRecoverERC1155ZeroAmount() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectRevert(ZeroAmount.selector);
        proxyGoldsand.recoverERC1155(USER1, myERC1155, 1, 0 ether);
    }

    function test_WithdrawalVaultRecoverERC1155ZeroAmount() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectRevert(ZeroAmount.selector);
        proxyWithdrawalVault.recoverERC1155(USER1, myERC1155, 1, 0 ether);
    }

    function test_GoldsandRecoverBatchERC1155ZeroAmount() public {
        uint256[] memory validIds = new uint256[](3);
        validIds[0] = uint256(2);
        validIds[1] = uint256(3);
        validIds[2] = uint256(4);
        uint256[] memory validValues = new uint256[](3);
        validValues[0] = uint256(0.1 ether);
        validValues[1] = uint256(0.2 ether);
        validValues[2] = uint256(0.3 ether);

        uint256[] memory invalidIds = new uint256[](0);
        uint256[] memory invalidValues = new uint256[](0);

        // myERC1155.mintBatch(USER1, validIds, validValues, "");
        // myERC1155.update(USER1, address(proxyGoldsand), validIds, validValues);
        myERC1155.update(address(0), address(proxyGoldsand), validIds, validValues);

        vm.prank(OPERATOR);
        vm.expectRevert(ZeroAmount.selector);
        proxyGoldsand.recoverBatchERC1155(USER1, myERC1155, validIds, invalidValues);

        vm.prank(OPERATOR);
        vm.expectRevert(ZeroAmount.selector);
        proxyGoldsand.recoverBatchERC1155(USER1, myERC1155, invalidIds, validValues);

        vm.prank(OPERATOR);
        vm.expectRevert(ZeroAmount.selector);
        proxyGoldsand.recoverBatchERC1155(USER1, myERC1155, invalidIds, invalidValues);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ERC1155BatchRecovered(USER1, OPERATOR, address(myERC1155), validIds, validValues);
        proxyGoldsand.recoverBatchERC1155(USER1, myERC1155, validIds, validValues);
    }

    function test_WithdrawalVaultRecoverBatchERC1155ZeroAmount() public {
        uint256[] memory validIds = new uint256[](3);
        validIds[0] = uint256(2);
        validIds[1] = uint256(3);
        validIds[2] = uint256(4);
        uint256[] memory validValues = new uint256[](3);
        validValues[0] = uint256(0.1 ether);
        validValues[1] = uint256(0.2 ether);
        validValues[2] = uint256(0.3 ether);

        uint256[] memory invalidIds = new uint256[](0);
        uint256[] memory invalidValues = new uint256[](0);

        // myERC1155.mintBatch(USER1, validIds, validValues, "");
        // myERC1155.update(USER1, address(proxyWithdrawalVault), validIds, validValues);
        myERC1155.update(address(0), address(proxyWithdrawalVault), validIds, validValues);

        vm.prank(OWNER);
        vm.expectRevert(ZeroAmount.selector);
        proxyWithdrawalVault.recoverBatchERC1155(USER1, myERC1155, validIds, invalidValues);

        vm.prank(OWNER);
        vm.expectRevert(ZeroAmount.selector);
        proxyWithdrawalVault.recoverBatchERC1155(USER1, myERC1155, invalidIds, validValues);

        vm.prank(OWNER);
        vm.expectRevert(ZeroAmount.selector);
        proxyWithdrawalVault.recoverBatchERC1155(USER1, myERC1155, invalidIds, invalidValues);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ERC1155BatchRecovered(USER1, OWNER, address(myERC1155), validIds, validValues);
        proxyWithdrawalVault.recoverBatchERC1155(USER1, myERC1155, validIds, validValues);
    }

    function test_GoldsandMintERC1155NotAccepted() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectRevert(ERC1155NotAccepted.selector);
        myERC1155.mint(address(proxyGoldsand), 1, 2 ether, "");

        assertEq(myERC1155.balanceOf(address(proxyGoldsand), 1), 0 ether);
    }

    function test_WithdrawalVaultMintERC1155NotAccepted() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectRevert(ERC1155NotAccepted.selector);
        myERC1155.mint(address(proxyWithdrawalVault), 1, 2 ether, "");

        assertEq(myERC1155.balanceOf(address(proxyWithdrawalVault), 1), 0 ether);
    }

    function test_GoldsandRecoverERC1155Succeeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        myERC1155.mint(USER1, 1, 2 ether, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = uint256(1);
        uint256[] memory values = new uint256[](1);
        values[0] = uint256(2 ether);

        vm.prank(USER1);
        myERC1155.update(USER1, address(proxyGoldsand), ids, values);

        assertEq(myERC1155.balanceOf(address(proxyGoldsand), 1), 2 ether);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ERC1155Recovered(USER1, OPERATOR, address(myERC1155), 1, 2 ether);
        proxyGoldsand.recoverERC1155(USER1, myERC1155, 1, 2 ether);

        assertEq(myERC1155.balanceOf(USER1, 1), 2 ether);
    }

    function test_WithdrawalVaultRecoverERC1155Succeeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        myERC1155.mint(USER1, 1, 2 ether, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = uint256(1);
        uint256[] memory values = new uint256[](1);
        values[0] = uint256(2 ether);

        vm.prank(USER1);
        myERC1155.update(USER1, address(proxyWithdrawalVault), ids, values);

        assertEq(myERC1155.balanceOf(address(proxyWithdrawalVault), 1), 2 ether);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ERC1155Recovered(USER1, OWNER, address(myERC1155), 1, 2 ether);
        proxyWithdrawalVault.recoverERC1155(USER1, myERC1155, 1, 2 ether);

        assertEq(myERC1155.balanceOf(USER1, 1), 2 ether);
    }

    function test_GoldsandMintBatchERC1155NotAccepted() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        uint256[] memory ids = new uint256[](3);
        ids[0] = uint256(2);
        ids[1] = uint256(3);
        ids[2] = uint256(4);
        uint256[] memory values = new uint256[](3);
        values[0] = uint256(0.1 ether);
        values[1] = uint256(0.2 ether);
        values[2] = uint256(0.3 ether);

        vm.prank(USER1);
        vm.expectRevert(ERC1155NotAccepted.selector);
        myERC1155.mintBatch(address(proxyGoldsand), ids, values, "");

        assertEq(myERC1155.balanceOf(address(proxyGoldsand), 1), 0 ether);
    }

    function test_WithdrawalVaultMintBatchERC1155NotAccepted() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        uint256[] memory ids = new uint256[](3);
        ids[0] = uint256(2);
        ids[1] = uint256(3);
        ids[2] = uint256(4);
        uint256[] memory values = new uint256[](3);
        values[0] = uint256(0.1 ether);
        values[1] = uint256(0.2 ether);
        values[2] = uint256(0.3 ether);

        vm.prank(USER1);
        vm.expectRevert(ERC1155NotAccepted.selector);
        myERC1155.mintBatch(address(proxyWithdrawalVault), ids, values, "");

        assertEq(myERC1155.balanceOf(address(proxyWithdrawalVault), 1), 0 ether);
    }

    function test_GoldsandRecoverBatchERC1155Succeeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        uint256[] memory ids = new uint256[](3);
        ids[0] = uint256(2);
        ids[1] = uint256(3);
        ids[2] = uint256(4);
        uint256[] memory values = new uint256[](3);
        values[0] = uint256(0.1 ether);
        values[1] = uint256(0.2 ether);
        values[2] = uint256(0.3 ether);

        myERC1155.mintBatch(USER1, ids, values, "");

        vm.prank(USER1);
        myERC1155.update(USER1, address(proxyGoldsand), ids, values);

        assertEq(myERC1155.balanceOf(address(proxyGoldsand), ids[0]), values[0]);
        assertEq(myERC1155.balanceOf(address(proxyGoldsand), ids[1]), values[1]);
        assertEq(myERC1155.balanceOf(address(proxyGoldsand), ids[2]), values[2]);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ERC1155BatchRecovered(USER1, OPERATOR, address(myERC1155), ids, values);
        proxyGoldsand.recoverBatchERC1155(USER1, myERC1155, ids, values);

        assertEq(myERC1155.balanceOf(USER1, ids[0]), values[0]);
        assertEq(myERC1155.balanceOf(USER1, ids[1]), values[1]);
        assertEq(myERC1155.balanceOf(USER1, ids[2]), values[2]);
    }

    function test_WithdrawalVaultRecoverBatchERC1155Succeeds() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        uint256[] memory ids = new uint256[](3);
        ids[0] = uint256(2);
        ids[1] = uint256(3);
        ids[2] = uint256(4);
        uint256[] memory values = new uint256[](3);
        values[0] = uint256(0.1 ether);
        values[1] = uint256(0.2 ether);
        values[2] = uint256(0.3 ether);

        myERC1155.mintBatch(USER1, ids, values, "");

        vm.prank(USER1);
        myERC1155.update(USER1, address(proxyWithdrawalVault), ids, values);

        assertEq(myERC1155.balanceOf(address(proxyWithdrawalVault), ids[0]), values[0]);
        assertEq(myERC1155.balanceOf(address(proxyWithdrawalVault), ids[1]), values[1]);
        assertEq(myERC1155.balanceOf(address(proxyWithdrawalVault), ids[2]), values[2]);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit ERC1155BatchRecovered(USER1, OWNER, address(myERC1155), ids, values);
        proxyWithdrawalVault.recoverBatchERC1155(USER1, myERC1155, ids, values);

        assertEq(myERC1155.balanceOf(USER1, ids[0]), values[0]);
        assertEq(myERC1155.balanceOf(USER1, ids[1]), values[1]);
        assertEq(myERC1155.balanceOf(USER1, ids[2]), values[2]);
    }

    function test_GoldsandReceive() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        (bool receiveSuccess,) = address(proxyGoldsand).call{value: 1 ether}("");
        assert(receiveSuccess);
    }

    function test_WithdrawalVaultReceive() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);

        vm.prank(USER1);
        (bool receiveSuccess,) = address(proxyWithdrawalVault).call{value: 1 ether}("");
        assert(receiveSuccess);
    }

    function test_withdrawETHToGoldsandETHWithdrawalFailed() public {
        vm.deal(address(proxyWithdrawalVault), WITHDRAWAL_VAULT_STARTING_BALANCE);

        assertEq(address(proxyGoldsand).balance, 0 ether);
        assertEq(address(proxyWithdrawalVault).balance, WITHDRAWAL_VAULT_STARTING_BALANCE);

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true);
        emit GoldsandSet(OWNER, address(rejectEther));
        proxyWithdrawalVault.setGoldsandAddress(address(rejectEther));

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                ETHWithdrawalFailed.selector, address(rejectEther), address(proxyWithdrawalVault).balance
            )
        );
        proxyWithdrawalVault.withdrawETHToGoldsand(address(proxyWithdrawalVault).balance);
    }

    function test_operatorWithdrawETHForUser() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);
        vm.deal(USER2, USER2_STARTING_BALANCE);

        vm.prank(OPERATOR);
        vm.expectRevert(ZeroAmount.selector);
        proxyGoldsand.operatorWithdrawETHForUser(USER1, 0 ether);

        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughContractEther.selector, 1 ether, 0 ether));
        proxyGoldsand.operatorWithdrawETHForUser(USER1, 1 ether);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 32 ether);
        proxyGoldsand.fund{value: 32 ether}();

        vm.prank(USER2);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER2, 32 ether);
        proxyGoldsand.fund{value: 32 ether}();

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ETHWithdrawnForUser(USER1, OPERATOR, 16 ether);
        proxyGoldsand.operatorWithdrawETHForUser(USER1, 16 ether);

        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughUserEther.selector, 32 ether, 16 ether));
        proxyGoldsand.operatorWithdrawETHForUser(USER1, 32 ether);

        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit ETHWithdrawnForUser(USER1, OPERATOR, 16 ether);
        proxyGoldsand.operatorWithdrawETHForUser(USER1, 16 ether);
    }

    function test_operatorWithdrawETHForUserETHWithdrawalFailed() public {
        vm.deal(address(rejectEther), REJECT_ETHER_STARTING_BALANCE);

        rejectEther.callFund(proxyGoldsand, 32 ether);

        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(ETHWithdrawalFailed.selector, address(rejectEther), 32 ether));
        proxyGoldsand.operatorWithdrawETHForUser(address(rejectEther), 32 ether);
    }

    function test_GoldsandSupportsInterface() public view {
        assertTrue(proxyGoldsand.supportsInterface(type(IERC165).interfaceId));
        assertTrue(proxyGoldsand.supportsInterface(type(IGoldsand).interfaceId));
        assertTrue(proxyGoldsand.supportsInterface(type(Initializable).interfaceId));
        assertTrue(proxyGoldsand.supportsInterface(type(AccessControlUpgradeable).interfaceId));
        assertTrue(proxyGoldsand.supportsInterface(type(PausableUpgradeable).interfaceId));
        assertTrue(proxyGoldsand.supportsInterface(type(UUPSUpgradeable).interfaceId));
        assertTrue(proxyGoldsand.supportsInterface(type(IERC1155Receiver).interfaceId));

        assertFalse(proxyGoldsand.supportsInterface(type(IWithdrawalVault).interfaceId));
        assertFalse(proxyGoldsand.supportsInterface(bytes4(0x00000001)));
    }

    function test_WithdrawalVaultSupportsInterface() public view {
        assertTrue(proxyWithdrawalVault.supportsInterface(type(IERC165).interfaceId));
        assertTrue(proxyWithdrawalVault.supportsInterface(type(IWithdrawalVault).interfaceId));
        assertTrue(proxyWithdrawalVault.supportsInterface(type(Initializable).interfaceId));
        assertTrue(proxyWithdrawalVault.supportsInterface(type(OwnableUpgradeable).interfaceId));
        assertTrue(proxyWithdrawalVault.supportsInterface(type(UUPSUpgradeable).interfaceId));
        assertTrue(proxyWithdrawalVault.supportsInterface(type(IERC1155Receiver).interfaceId));

        assertFalse(proxyWithdrawalVault.supportsInterface(type(IGoldsand).interfaceId));
        assertFalse(proxyWithdrawalVault.supportsInterface(bytes4(0x00000001)));
    }

    function test_depositFundsIfPossibleDepositDataEarlyExit() public {
        vm.deal(USER1, USER1_STARTING_BALANCE);
        vm.deal(USER2, USER2_STARTING_BALANCE);

        vm.prank(USER1);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER1, 32 ether);
        proxyGoldsand.fund{value: 32 ether}();

        vm.prank(USER2);
        vm.expectEmit(true, true, true, true);
        emit Funded(USER2, 32 ether);
        proxyGoldsand.fund{value: 32 ether}();

        vm.recordLogs();
        vm.prank(OPERATOR);
        proxyGoldsand.depositFundsIfPossible();
        vm.assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_depositFundsIfPossibleFundsEarlyExit() public {
        vm.prank(OPERATOR);
        vm.expectEmit(true, true, true, true);
        emit DepositDataAdded(depositData1);
        proxyGoldsand.addDepositData(depositData1);

        vm.recordLogs();
        vm.prank(OPERATOR);
        proxyGoldsand.depositFundsIfPossible();
        vm.assertEq(vm.getRecordedLogs().length, 0);
    }
}
