# Staking Rewards Single Token

Synthetix' StakingRewards rewritten for maximum efficiency when the staking token is the same as the reward token.

## Donate

Any EVM: 0xa8101F6Ec7080dE84233f1eE4fc1D6A2C1568327

## Features

* Very low gas cost on all operations
* Role based permission control allowing non-admin funders
* `compound()` function for staking the rewards
* `stake()` function also compounds the rewards
* `withdraw()` function also claims the rewards
* `addReward()` function for transferring and funding the contract

## Non-features

* No ERC20 token recovery function
* No funding using the account balance
* No pointless reenterancy guards

DO NOT DIRECTLY TRANSFER TOKENS TO THE CONTRACT!
Only fund through the `addReward()` function.
This model is similar to MiniChef, and incompatible
with `notifyRewardAmount()` method of original StakingRewards.
So, DO NOT DIRECTLY TRANSFER TOKENS TO THE CONTRACT!

## Fixed Vulnerability

Original StakingRewards has a serious vulnerability when the StakingToken is the same as the RewardsToken.
The contract owner can fund the rewards using the staked balance.
This allows users to claim rewards from each others' staked balance, effectively ruining the state.
To prevent this there are to options. The first options is keeping track of the reserves
and updating a variable whenever tokens move to or from the contract.
The second options is combining transferring tokens and funding the rewards into one function.
I opted for the second for gas efficiency. Therefore, use the appropriate function for funding
rewards and DO NOT DIRECTLY TRANSFER TOKENS TO THE CONTRACT!

## Gas Comparison

My StakingRewards | Costs     | Original StakingRewards       | Costs
----------------- | --------- | ----------------------------- | -----
`addReward`       | 65k       | `transfer+notifyRewardAmount` | ~120k
`stake`           | 68k-82k   | `stake`                       | ~100k
`withdraw`        | 55k-60k   | `exit`                        | 95k
`withdraw`        | 55k-60k   | `withdraw`                    | 75k-80k
`compound`        | 43k       | `harvest+stake`               | ~175k
`harvest`         | 56k       | `getReward`                   | 75k

## Disclaimer

Contract yet to be properly tested. Use at your own risk.
