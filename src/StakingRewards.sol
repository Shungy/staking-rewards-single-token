// SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.4;

import "./StakingRewardsFunding.sol";

/**
 * @title Staking Rewards Single Token
 * @notice A contract that distributes rewards to stakers. It requires that the staking token is
 * the same as the reward token. This is much more efficient than Synthetix' version.
 * @dev For funding the contract, use `addReward()`. DO NOT DIRECTLY SEND TOKENS TO THE CONTRACT!
 * @dev Limitations (checked through input sanitization):
 *        1) The sum of all tokens added through `addReward()` cannot exceed `2**96-1`,
 *        2) Total staked balance cannot exceed `2**96-1`.
 * @dev Assumptions (not checked, assumed to be always true):
 *        1) `block.timestamp < 2**40`,
 *        2) rewardToken returns false or reverts on failing transfers.
 * @author shung
 */
contract StakingRewards is StakingRewardsFunding {
    struct User {
        uint160 rewardPerTokenPaid;
        uint96 balance;
    }

    mapping(address => User) public users;

    uint160 public rewardPerTokenStored;
    uint96 public totalStaked = 0;

    event Staked(address indexed user, uint256 indexed amount, uint256 rewards);
    event Withdrawn(address indexed user, uint256 indexed amount, uint256 reward);

    error InvalidWithdrawAmount(uint256 amountToWithdraw, uint256 existingBalance);
    error InvalidStakeAmount(uint256 amountToStake);

    constructor(address newRewardsToken, address newAdmin)
        StakingRewardsFunding(newRewardsToken, newAdmin)
    {}

    function stake(uint256 amount) external {
        unchecked {
            if (amount > MAX_TOKEN) revert InvalidStakeAmount(amount);
            User storage user = users[msg.sender];
            uint256 reward = _updateRewardPerTokenStored(user);
            uint256 totalAmount = amount + reward;
            uint256 newTotalStaked = totalStaked + totalAmount;
            if (newTotalStaked > MAX_TOKEN) revert InvalidStakeAmount(amount);
            totalStaked = uint96(newTotalStaked);
            user.balance += uint96(totalAmount);
            _transferFromCaller(amount);
            emit Staked(msg.sender, amount, reward);
        }
    }

    function withdraw(uint256 amount) external {
        unchecked {
            User storage user = users[msg.sender];
            uint256 reward = _updateRewardPerTokenStored(user);
            uint256 userOldBalance = user.balance;
            if (amount > userOldBalance) revert InvalidWithdrawAmount(amount, userOldBalance);
            totalStaked -= uint96(amount);
            user.balance = uint96(userOldBalance - amount);
            _transferToCaller(amount + reward);
            emit Withdrawn(msg.sender, amount, reward);
        }
    }

    function earned(address account) external view returns (uint256) {
        unchecked {
            User memory user = users[account];
            uint256 tmpTotalStaked = totalStaked;
            uint256 rewardPerToken = tmpTotalStaked == 0
                ? rewardPerTokenStored
                : rewardPerTokenStored + (_pendingRewards() * PRECISION) / tmpTotalStaked;
            return (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        }
    }

    function _updateRewardPerTokenStored(User storage user) private returns (uint256 reward) {
        unchecked {
            uint160 rewardPerToken = rewardPerTokenStored;
            if (totalStaked != 0) {
                rewardPerToken += uint160(_claim() * PRECISION / totalStaked);
                rewardPerTokenStored = rewardPerToken;
            }
            user.rewardPerTokenPaid = rewardPerToken;
            uint256 rewardPerTokenPayable = rewardPerToken - user.rewardPerTokenPaid;
            reward = uint160((user.balance * rewardPerTokenPayable) / PRECISION);
        }
    }
}
