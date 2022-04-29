# Staking Rewards Single Token

Synthetix' StakingRewards rewritten for maximum efficiency when the staking token is the same as the reward token.

## Donate

Any EVM chain: 0xa8101F6Ec7080dE84233f1eE4fc1D6A2C1568327

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
* No safeTransfer (use a proper token)

DO NOT DIRECTLY TRANSFER TOKENS TO THE CONTRACT!
Only fund through the `addReward()` function.
This model is similar to MiniChef, and incompatible
with `notifyRewardAmount()` method of original StakingRewards.
So, DO NOT DIRECTLY TRANSFER TOKENS TO THE CONTRACT!

## Limitations

1. The sum of all tokens added through `addReward()` cannot exceed `2**96-1`,
2. A user's staked balance cannot exceed `2**96-1`.

## Assumptions

1. `block.timestamp < 2**64 - 2**32`,
2. rewardToken returns false or reverts on failing transfers,
3. Number of users does not exceed `(2**256-1)/(2**96-1)`.

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
`stake`           | 65k-79k   | `getReward+stake`             | ~175k
                  |           | `stake`                       | ~100k
`withdraw` (full amount)| 53k | `exit`                        | 95k
`withdraw`        | 53k-58k   | `getReward+withdraw`          | 150k-155k
                  |           | `withdraw`                    | 75k-80k
`compound`        | 41k       | `getReward+stake`             | ~175k
`harvest`         | 54k       | `getReward`                   | 75k

## Disclaimer

Contract yet to be properly tested. Use at your own risk.
I am also using unchecked math. That is considered a risky practice. However I plan to verify the logic.
