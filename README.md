# CoreLinearVesting Smart Contract

## Overview

The `CoreLinearVesting` contract manages the linear and homogenous vesting of tokens to a predetermined list of addresses. It offers individualized vesting schedules within a unified framework based on time, distributing tokens in equal portions at regular intervals. A major design aspect of this vesting contract is its reliance on an external authority to provide the necessary Core for each step. This differ from other designs (which are no less common) where all of the required sums are injected into the contract as part of its initialization

## Features

- **Linear Vesting**: Core Tokens are distributed over a set period in equal portions at regular intervals.
- **Immutable Vesting Addresses**: The list of vested-addresses is set at deployment and cannot be altered.
- **Immutable Vesting Schedule**: The start date and interval of the vesting are set at deployment and cannot be altered.
- **Per-Address Configuration valueV**: Each address has its own num-slices and tokens-per-slice configuration values.
- **Non-Pausable Vesting Accumulation**: Accumulation of tokens for each address continues even if the vesting per the specific address is paused.
- **No vesting-address Limitations**: The vesting address may be an EOA, an abstract-account of a multi-sig.
- **pull-based claim functionality**: Claims may only be invoked by the vested address.
- **Owner Controls**: The contract owner can pause/resume vesting for any address and extract tokens from the contract to prevent locking.
- **Secure Design**: Utilizes OpenZeppelin's `ReentrancyGuard` for protection against re-entrant attacks, and `Ownable` for ownership management.

## Contract Initialization

### Constructor
```solidity
constructor(uint vestingIntervalInBlocks, address[] memory addrArr, uint[] memory amountInSliceArr, uint[] memory numSlicesArr)
```

Initializes vesting schedule for a set of addresses.
Parameters:
vestingIntervalInBlocks: Interval between vesting slices, in blocks.
addrArr: Array of addresses to be vested.
amountInSliceArr: Corresponding amounts per slice for each address.
numSlicesArr: Number of slices for each address.
Requirements:
Arrays addrArr, amountInSliceArr, and numSlicesArr must have equal length.
vestingIntervalInBlocks must be greater than a predefined minimum interval.

## Functionality

### Claiming Tokens
- **claim()**: Allows an address to claim their vested tokens as per the schedule. Emits either a Claim or a ClaimWhenPaused event if the address's vesting is paused.

### Administrative Functions
- **pauseVesting(address addressToPause, bool _isPaused)**: Permits the contract owner to pause or resume vesting for a specific address.
- **extractTokens(address to, uint amount)**: Enables the contract owner to transfer tokens out of the contract, preventing token locking.

### Events
- **TokenTransfer(address indexed to, uint amount)**:  Emitted after successful token transfer.
- **PauseVesting(address indexed addressToPause, bool isPaused)**: Indicates pausing or resuming of an address's vesting.
- **Claim(address indexed claimer, uint amount)**: Signifies a claim of vested tokens.
- **ClaimWhenPaused(address indexed claimer)**: Emitted for a claim made during a pause in vesting.
- **IncomingTokens(address indexed sender, uint value)**: Logs incoming tokens to the contract.

### Security Features
- Inherits ReentrancyGuard for re-entrancy attack protection.
- Inherits Ownable for ownership management, with a no renouncing ownership restriction.

### Additional Considerations
- There is no mechanism for adding new vesting addresses post-deployment.
- Vesting is based on block numbers, which may vary in timing due to network conditions.
