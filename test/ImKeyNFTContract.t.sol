// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockUSD.sol";
import "../src/contract/ImKeyNFTContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract TestImKeyNFTContractt is Test {
    using SafeERC20 for IERC20;

    address constant SENDER_ADDRESS =
        0x3De70dA882f101b4b3d5f3393c7f90e00E64edB9;

    address constant SOME_ADDRESS = 0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address constant MULTIPLE_SIGNATURE_ADDRESS =
        0xC0f068774D46ba26013677b179934Efd7bdefA3F;

    address constant OWNER_ADDRESS = 0xC565FC29F6df239Fe3848dB82656F2502286E97d;
    address constant SINGER_ADDRESS =
        0xC565FC29F6df239Fe3848dB82656F2502286E97d;

    address constant usdtToken = 0xED85184DC4BECf731358B2C63DE971856623e056;
    uint256 constant mintPrice = 60 * 10 ** 6;
    MockUSD _usdtToken;
    MockUSD _usdcToken;

    address private proxy;
    ImKeyNFTContract private instance;

    function setUp() public {
        console.log("=======setUp============");

        proxy = Upgrades.deployUUPSProxy(
            "ImKeyNFTContract.sol",
            abi.encodeCall(ImKeyNFTContract.initialize, OWNER_ADDRESS)
        );

        console.log("uups proxy -> %s", proxy);

        instance = ImKeyNFTContract(proxy);
        assertEq(instance.owner(), OWNER_ADDRESS);

        address implAddressV1 = Upgrades.getImplementationAddress(proxy);

        console.log("impl proxy -> %s", implAddressV1);

        _usdtToken = new MockUSD("Mock USDT", "USDT");
        _usdcToken = new MockUSD("Mock USDC", "USDC");

        console.log("_usdtToken address -> %s", address(_usdtToken));
        console.log("_usdcToken address -> %s", address(_usdcToken));
        _usdtToken.transfer(SENDER_ADDRESS, mintPrice);
        _usdcToken.transfer(SENDER_ADDRESS, mintPrice);
    }
    function testSetConstantAddress_local() public {
        vm.startPrank(OWNER_ADDRESS);

        //Local test
        //move to ImKeyNFTContract
        // address public _usdtToken;
        // address public _usdcToken;
        // address public _moneyAddress;

        //      function setAddress(
        //     address usdtToken,
        //     address usdcToken,
        //     address moneyAddress
        // ) external onlyOwner {
        //     _usdtToken = usdtToken;
        //     _usdcToken = usdcToken;
        //     _moneyAddress = moneyAddress;
        // }

        // instance.setAddress(
        //     address(_usdtToken),
        //     address(_usdcToken),
        //     SOME_ADDRESS
        // );
        vm.stopPrank();
    }
    function testMint() public {
        console.log("testMint");
        // vm.prank(OWNER_ADDRESS);

        //Local test
        testSetConstantAddress_local();

        vm.startPrank(OWNER_ADDRESS);

        uint256 ownerBalance1_usdtToken = IERC20(_usdtToken).balanceOf(
            OWNER_ADDRESS
        );
        console.log(
            "ownerBalance1_usdtToken _usdtToken -> %s",
            ownerBalance1_usdtToken
        );
        uint256 ownerBalance1_usdcToken = IERC20(_usdcToken).balanceOf(
            OWNER_ADDRESS
        );
        console.log(
            "ownerBalance1_usdcToken _usdtToken -> %s",
            ownerBalance1_usdcToken
        );

        assertEq(instance.MINT_PRICE(), mintPrice);

        vm.stopPrank();

        console.log("-------mint-------");
        vm.startPrank(SENDER_ADDRESS);
        console.log("balanceOf");
        uint256 senderBalance_usdtToken = IERC20(_usdtToken).balanceOf(
            SENDER_ADDRESS
        );
        assertEq(
            senderBalance_usdtToken,
            mintPrice,
            "senderBalance_usdtToken should be 60 USDT"
        );
        console.log("senderBalance_usdtToken  -> %s", senderBalance_usdtToken);

        uint256 senderBalance_usdcToken = IERC20(_usdcToken).balanceOf(
            SENDER_ADDRESS
        );
        assertEq(
            senderBalance_usdcToken,
            mintPrice,
            "senderBalance_usdcToken should be 60 USDT"
        );
        console.log("senderBalance_usdcToken  -> %s", senderBalance_usdcToken);

        console.log("approve");
        // IERC20(_usdtToken).approve(address(instance), mintPrice);
        // IERC20(_usdcToken).approve(address(instance), mintPrice);
        IERC20(_usdtToken).approve(MULTIPLE_SIGNATURE_ADDRESS, mintPrice);
        IERC20(_usdcToken).approve(MULTIPLE_SIGNATURE_ADDRESS, mintPrice);

        console.log("balanceOf _usdtToken");
        instance.mint(address(_usdtToken), 1);
        uint256 user1TokenId = instance.balanceOf(SENDER_ADDRESS);
        assertEq(user1TokenId, 1, "nuf number 1");

        console.log("balanceOf _usdcToken");
        instance.mint(address(_usdcToken), 1);
        uint256 user1TokenId_2 = instance.balanceOf(SENDER_ADDRESS);
        assertEq(user1TokenId_2, 2, "nuf number 2");

        console.log("--------- isExercisable 1 ---------");
        assertEq(instance.isExercisable(SENDER_ADDRESS, 1, 1), true);
        assertEq(instance.isExercised(SENDER_ADDRESS, 1, 1), false);
        console.log("--------- exercisePrivilege 1 ---------");
        instance.exercisePrivilege(SENDER_ADDRESS, 1, 1, "");

        console.log("--------- isExercisable 1 ---------");
        assertEq(instance.isExercisable(SENDER_ADDRESS, 1, 1), false);
        assertEq(instance.isExercised(SENDER_ADDRESS, 1, 1), true);

        console.log("--------- isExercisable 2 ---------");
        assertEq(instance.isExercisable(SENDER_ADDRESS, 2, 1), true);
        assertEq(instance.isExercised(SENDER_ADDRESS, 2, 1), false);
        console.log("--------- exercisePrivilege 2 ---------");
        instance.exercisePrivilege(SENDER_ADDRESS, 2, 1, "");

        console.log("--------- isExercisable 2 ---------");
        assertEq(instance.isExercisable(SENDER_ADDRESS, 2, 1), false);
        assertEq(instance.isExercised(SENDER_ADDRESS, 2, 1), true);

        uint256[] memory privilegeIds = instance.getPrivilegeIds(1);
        for (uint i = 0; i < privilegeIds.length; i++) {
            emit log_uint(privilegeIds[i]);
        }
        vm.stopPrank();

        // console.log("-------withdrawUSD-------");

        // vm.startPrank(OWNER_ADDRESS);

        // uint256 ownerBalance2_usdtToken = IERC20(_usdtToken).balanceOf(
        //     OWNER_ADDRESS
        // );
        // console.log("ownerBalance2_usdtToken -> %s", ownerBalance2_usdtToken);

        // instance.withdrawUSD(address(_usdtToken));

        // uint256 ownerBalance3_usdtToken = IERC20(_usdtToken).balanceOf(
        //     OWNER_ADDRESS
        // );
        // console.log("ownerBalance3_usdtToken -> %s", ownerBalance3_usdtToken);

        // uint256 ownerBalance2_usdcToken = IERC20(_usdcToken).balanceOf(
        //     OWNER_ADDRESS
        // );
        // console.log("ownerBalance2_usdcToken -> %s", ownerBalance2_usdcToken);

        // instance.withdrawUSD(address(_usdcToken));

        // uint256 ownerBalance3_usdcToken = IERC20(_usdcToken).balanceOf(
        //     OWNER_ADDRESS
        // );
        // console.log("ownerBalance3_usdcToken -> %s", ownerBalance3_usdcToken);

        // uint256 some_address_usdcToken = IERC20(_usdcToken).balanceOf(
        //     SOME_ADDRESS
        // );
        // console.log("some_address_usdcToken -> %s", some_address_usdcToken);
        // uint256 some_address_usdtToken = IERC20(_usdtToken).balanceOf(
        //     SOME_ADDRESS
        // );
        // console.log("some_address_usdtToken -> %s", some_address_usdtToken);
        // vm.stopPrank();
    }
}
