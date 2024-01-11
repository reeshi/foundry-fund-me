// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { FundMe } from "../../src/FundMe.sol";
import { DeployFundMe } from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; // 100000000000000000
    uint256 constant STARTING_BALANCE = 10 ether;

    // testing contract start from setUp function
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        // fund the USER
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // this will fail because the owner is not msg.sender but the contract itself
        // becoz we are calling this contract to deploy the FundMe contract so the real owner is the contract itself
        // assertEq(fundMe.i_owner(), msg.sender);

        // this will pass because we are comparing the owner with the contract address
        // assertEq(fundMe.i_owner(), address(this));

        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // the next line should revert
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // The next Tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArray() public {
        vm.prank(USER); // The next Tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded {
        vm.prank(USER); // The next Tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER); // The next Tx will be sent by USER
        vm.expectRevert(); // the next line should revert
        fundMe.withdraw(); // Now the USER try to withdraw but it should revert because only owner can withdraw the real owner is the Deploy contract
    }

    function testWithDrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner()); // The next Tx will be sent by the owner because only the owner can withdraw
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingContractBalance = address(fundMe).balance;
        assertEq(endingContractBalance, 0);
        assertEq(startingOwnerBalance + startingContractBalance, endingOwnerBalance);
    }

    function testWithDrawFromMultipleFunders() public funded {
        // Arrange 
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank to send transaction from new address
            // vm.deal to fund the new address
            // we can create new address by using address(0 or 1 or 2)
            hoax(address(i), SEND_VALUE); // this will create new address and fund it with SEND_VALUE and also prank it
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner()); // The next Tx will be sent by the owner because only the owner can withdraw
        fundMe.withdraw();
        vm.stopPrank(); // stop prank

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingContractBalance = address(fundMe).balance;
        assertEq(endingContractBalance, 0);
        assertEq(startingOwnerBalance + startingContractBalance, endingOwnerBalance);
    }
}