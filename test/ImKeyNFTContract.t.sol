// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MockUSDT.sol";
import "../src/contract/ImKeyNFTContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract TestImKeyNFTContractt is Test {
    address constant SENDER_ADDRESS =
        0x3De70dA882f101b4b3d5f3393c7f90e00E64edB9;

    address constant SOME_ADDRESS = 0xC0f068774D46ba26013677b179934Efd7bdefA3F;

    address constant OWNER_ADDRESS = 0xC565FC29F6df239Fe3848dB82656F2502286E97d;
    address constant SINGER_ADDRESS =
        0xC565FC29F6df239Fe3848dB82656F2502286E97d;

    address constant usdtToken = 0xED85184DC4BECf731358B2C63DE971856623e056;
    uint256 constant mintPrice = 60 * 10 ** 6;
    MockUSDT _usdtToken;

    address private proxy;
    ImKeyNFTContract private instance;

    function setUp() public {
        console.log("=======setUp============");

        _usdtToken = new MockUSDT();
        emit log_address(address(_usdtToken));
        console.log("_usdtToken address -> %s", address(_usdtToken));
        _usdtToken.transfer(SENDER_ADDRESS, mintPrice);

        proxy = Upgrades.deployUUPSProxy(
            "ImKeyNFTContract.sol",
            abi.encodeCall(
                ImKeyNFTContract.initialize,
                (OWNER_ADDRESS, address(_usdtToken), mintPrice)
            )
        );

        console.log("uups proxy -> %s", proxy);

        instance = ImKeyNFTContract(proxy);
        assertEq(instance.owner(), OWNER_ADDRESS);

        address implAddressV1 = Upgrades.getImplementationAddress(proxy);

        console.log("impl proxy -> %s", implAddressV1);
    }

    function testMint() public {
        console.log("testMint");
        // vm.prank(OWNER_ADDRESS);

        vm.startPrank(OWNER_ADDRESS);
        uint256 ownerBalance1 = IERC20(_usdtToken).balanceOf(OWNER_ADDRESS);
        console.log("OWNER_ADDRESS _usdtToken -> %s", ownerBalance1);

        assertEq(instance.mintPrice(), mintPrice);

        console.log("updatePrivilegeIds");
        instance.updatePrivilegeIds(1, true);

        console.log("addWhiteList");
        address[] memory params = new address[](2);
        params[0] = SENDER_ADDRESS;
        params[1] = SOME_ADDRESS;
        instance.addWhiteList(params);

        vm.stopPrank();

        vm.startPrank(SENDER_ADDRESS);
        console.log("balanceOf");
        uint256 senderBalance = IERC20(_usdtToken).balanceOf(SENDER_ADDRESS);
        assertEq(senderBalance, mintPrice, "Balance should be 60 USDT");
        console.log("SENDER_ADDRESS _usdtToken -> %s", senderBalance);

        console.log("approve");
        IERC20(_usdtToken).approve(address(instance), mintPrice);

        console.log("mint");
        instance.mint();
        uint256 user1TokenId = instance.balanceOf(SENDER_ADDRESS);
        assertEq(user1TokenId, 1, "nuf number 1");

        console.log("isExercisable");
        assertEq(instance.isExercisable(SENDER_ADDRESS, 1, 1), true);
        assertEq(instance.isExercised(SENDER_ADDRESS, 1, 1), false);
        console.log("exercisePrivilege");
        instance.exercisePrivilege(SENDER_ADDRESS, 1, 1, "");

        console.log("isExercisable");
        assertEq(instance.isExercisable(SENDER_ADDRESS, 1, 1), false);
        assertEq(instance.isExercised(SENDER_ADDRESS, 1, 1), true);

        uint256[] memory privilegeIds = instance.getPrivilegeIds(1);
        for (uint i = 0; i < privilegeIds.length; i++) {
            emit log_uint(privilegeIds[i]);
        }
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);

        uint256 ownerBalance2 = IERC20(_usdtToken).balanceOf(OWNER_ADDRESS);
        console.log("OWNER_ADDRESS 2 _usdtToken -> %s", ownerBalance2);

        instance.withdrawUSDT();

        uint256 ownerBalance3 = IERC20(_usdtToken).balanceOf(OWNER_ADDRESS);
        console.log("OWNER_ADDRESS 3 _usdtToken -> %s", ownerBalance3);
        vm.stopPrank();
    }
}
