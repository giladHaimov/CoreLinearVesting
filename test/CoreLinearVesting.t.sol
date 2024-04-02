// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CoreLinearVesting} from "../src/CoreLinearVesting.sol";

contract CoreLinearVestingTest is Test {
    CoreLinearVesting private vesting;
    address private sam = makeAddr("sam");
    address private dave = makeAddr("dave");
    address private sue = makeAddr("sue");

    uint private vestingIntervalInBlocks = 6500;    

    address[] private addrArr;
    uint[] private amountInSliceArr;
    uint[] private numSlicesArr;

    function setUp() public {
        delete addrArr;
        addrArr.push(sam);
        addrArr.push(dave);
        addrArr.push(sue);
        
        delete amountInSliceArr;
        amountInSliceArr.push(uint(100));
        amountInSliceArr.push(uint(200));
        amountInSliceArr.push(uint(300));
        
        delete numSlicesArr;
        numSlicesArr.push(uint(10));
        numSlicesArr.push(uint(20));
        numSlicesArr.push(uint(30));
        
        vesting = new CoreLinearVesting(vestingIntervalInBlocks, addrArr, amountInSliceArr, numSlicesArr);

        assertTrue(vesting.VESTING_INTERVAL_IN_BLOCKS() == vestingIntervalInBlocks, "vestingIntervalInBlocks");

        _verifyVestingRecord(sam, 100, 10);        
        _verifyVestingRecord(dave, 200, 20);
        _verifyVestingRecord(sue, 300, 30);
    }

    function _verifyVestingRecord(address addr, uint amountInSlice, uint numSlices) private view {
        (uint _totalNumSlices, uint _amountInSlice, uint _paidSofar, uint _paidUntilBlock, bool _isPaused) = vesting.s_vestings(addr);
        assertTrue(_amountInSlice == amountInSlice, "amountInSlice");
        assertTrue(_totalNumSlices == numSlices, "totalNumSlices");
        assertTrue(_paidSofar == 0, "paidSofar");
        assertTrue(_isPaused == false, "isPaused");
        (_paidUntilBlock);
    }

    function test_nonVestedAddrFails() public {
        hoax(makeAddr("badAddr"), 2 ether);
        vm.expectRevert(abi.encodePacked("not a vested address"));
        vesting.claim();
    }

    function test_vestedAddrFailsIfBeforeTime() public {
        hoax(sam, 2 ether);
        vm.expectRevert(abi.encodePacked("claim made too early"));
        vesting.claim();
    }


    function test_vestedAddrSucceedsIfInDueTime() public {
        _passFundsToContract(uint(100)); // sam's slice size
        hoax(sam, 1 ether);
        _promotBlockNumberBy(vestingIntervalInBlocks+1);
        vesting.claim();
    }

    function test_vestedAddrFailsIfNotEnoughFundsInContract() public {
        _passFundsToContract(uint(100)); // sam's slice size
        hoax(sam, 1 ether);
        vm.expectRevert(abi.encodePacked("insufficient balance in contract"));
        _promotBlockNumberBy(2*vestingIntervalInBlocks + 1); // i.e. now two vesting slices
        vesting.claim();
    }

    function test_multiSliceClaim() public {
        uint NUM_SLICES = 4;
        _passFundsToContract(uint(NUM_SLICES*100)); // sam's slice size
        hoax(sam, 1 ether);
        _promotBlockNumberBy(NUM_SLICES*vestingIntervalInBlocks + 1); // i.e. now two vesting slices        
        vesting.claim();
    }

    function test_chainOfClaims() public {
        // success, success, success, fail
        uint samSliceSize = uint(100);
        _runStep(samSliceSize);
        _runStep(samSliceSize);
        _runStep(samSliceSize);
        _runFailedStep(samSliceSize);
    }

    function test_allTheWayToCompletion() public {
        // success, success, success, fail
        uint samSliceSize = uint(100);
        uint samNumSlices = uint(10);
        for (uint i = 0; i < samNumSlices; i++) {
            _runStep(samSliceSize);
        }
        // verify cannot claim anymore
        vm.expectRevert(abi.encodePacked("all was paid"));
        _runStep(samSliceSize);
    }

    function _runStep(uint fundsToClaim) private {
        _passFundsToContract(fundsToClaim); 
        hoax(sam, 1 ether);
        _promotBlockNumberBy(vestingIntervalInBlocks);
        vesting.claim();
    }

    function _runFailedStep(uint fundsToClaim) private {
        _passFundsToContract(fundsToClaim/2); // i.e. not enough funds
        hoax(sam, 1 ether);
        _promotBlockNumberBy(vestingIntervalInBlocks);
        vm.expectRevert(abi.encodePacked("insufficient balance in contract"));
        vesting.claim();
    }

    function _passFundsToContract(uint amount) private {
        deal(address(vesting), amount);
    }

    function _promotBlockNumberBy(uint rollBy) private {
        uint height = vm.getBlockNumber();        
        uint newHeight = height+rollBy;
        vm.roll(newHeight);
        height = vm.getBlockNumber();
        assertEq(height, newHeight);
        assertEq(height, block.number);
    }
}
