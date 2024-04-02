// SPDX-License-Identifier: Apache2.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract CoreLinearVesting is Ownable, ReentrancyGuard { 

  uint[64] private __gap; // allow future statefull base contracts

  uint constant public MIN_VESTING_INTERVAL_IN_BLOCKS = 6400; // ~= 1 day, assuming average block time of 13.5s 

  uint immutable public START_BLOCK;
  uint immutable public VESTING_INTERVAL_IN_BLOCKS;

  mapping(address => VestingRecord) public s_vestings;
  mapping(address => bool) private tmp_addresses;
  address[] public s_allVestedAddresses;

  event TokenTransfer(address indexed to, uint amount);
  event PauseVesting(address indexed addressToPause, bool isPaused);
  event Claim(address indexed claimer, uint indexed amount);
  event AttemptingClaimWhenPaused(address indexed claimer);
  event IncomingTokens(address indexed sender, uint value);


  struct VestingRecord {
    uint totalNumSlices;
    uint amountInSlice;
    uint paidSofar;
    uint paidUntilBlock;
    bool isPaused;
  }

  modifier onlyIfVested(address addr) {
    require(_isVested(addr), "not a vested address");
    _;
  }

  receive() external payable {
    emit IncomingTokens(msg.sender, msg.value);
  } 

  constructor(uint vestingIntervalInBlocks, address[] memory addrArr, uint[] memory amountInSliceArr, uint[] memory numSlicesArr) 
              Ownable(msg.sender) {
    require(addrArr.length == amountInSliceArr.length && amountInSliceArr.length == numSlicesArr.length, "bad data");
    require(vestingIntervalInBlocks > MIN_VESTING_INTERVAL_IN_BLOCKS, "bad vesting interval");
    VESTING_INTERVAL_IN_BLOCKS = vestingIntervalInBlocks;
    START_BLOCK = block.number;  
    for (uint i = 0; i < addrArr.length; i++) {
      address addr = addrArr[i];
      s_vestings[addr] = createVestingRecord(addr, amountInSliceArr[i], numSlicesArr[i]);
    } 
  }

  function createVestingRecord(address addr, uint amountInSlice, uint numSlices) private returns(VestingRecord memory) {
    require(addr != address(0), "bad address");
    require(!tmp_addresses[addr], "duplicate address found");
    tmp_addresses[addr] = true;      
    s_allVestedAddresses.push(addr);
    require(amountInSlice > 0, "bad sum");
    require(numSlices > 0, "bad numSlices");
    return VestingRecord({totalNumSlices: numSlices, amountInSlice: amountInSlice, 
                paidSofar: 0, paidUntilBlock: block.number, isPaused: false});
  }    


  function claim() external onlyIfVested(msg.sender) nonReentrant {
    VestingRecord storage sref_record = s_vestings[msg.sender];
    require(block.number >= sref_record.paidUntilBlock + VESTING_INTERVAL_IN_BLOCKS, "claim made too early");
    uint totalVestedAmount = sref_record.amountInSlice * sref_record.totalNumSlices;
    require(sref_record.paidSofar < totalVestedAmount, "all was paid");    

    uint numSlicesToPayFor = (block.number - sref_record.paidUntilBlock) / VESTING_INTERVAL_IN_BLOCKS;    
    if (sref_record.isPaused) {
        emit AttemptingClaimWhenPaused(msg.sender); // will be embraced once unpaused
    } else {
        uint _amount = _handleClaim(numSlicesToPayFor, totalVestedAmount);
        emit Claim(msg.sender, _amount);
    }
  }

  
  function _handleClaim(uint numSlicesToPayFor, uint totalVestedAmount) private returns(uint) {
    if (numSlicesToPayFor == 0) {
      return 0;
    }
    VestingRecord storage sref_record = s_vestings[msg.sender];
    require(!sref_record.isPaused, "address is paused");
    uint amountToPay = numSlicesToPayFor * sref_record.amountInSlice;
    if (sref_record.paidSofar + amountToPay > totalVestedAmount) {
      amountToPay = totalVestedAmount - sref_record.paidSofar; // sanity check
    }
    sref_record.paidUntilBlock += numSlicesToPayFor * VESTING_INTERVAL_IN_BLOCKS;
    require(sref_record.paidUntilBlock <= block.number, "bad vesting period calculation");
    sref_record.paidSofar += amountToPay;
    _safeTransferTo(msg.sender, amountToPay);
    return amountToPay;
  }

  function pauseVesting(address addressToPause, bool _isPaused) external onlyOwner {
    require(_isVested(addressToPause), "invalid address");
    s_vestings[addressToPause].isPaused = _isPaused;
    emit PauseVesting(addressToPause, _isPaused);
  }  

  function extractTokens(address to, uint amount) external onlyOwner nonReentrant {
    // avoid core lock by allowing owner transfer 
    _safeTransferTo(to, amount);
  }  

  function _safeTransferTo(address to, uint amount) private {
    require(to != address(0), "bad to address");    
    require(address(this).balance >= amount, "insufficient balance in contract");
    Address.sendValue(payable(to), amount);
    emit TokenTransfer(to, amount);
  }

  function _isVested(address addr) private view returns (bool) {
    return s_vestings[addr].amountInSlice > 0; 
  }

  function renounceOwnership() public view override onlyOwner {
    revert("renouncing of ownership not allowed");
  }

}