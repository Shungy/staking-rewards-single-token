// SPDX-License-Identifier: GPLv3
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library SafeCast160 {
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }
}

/**
 * @title Staking Rewards Single Token
 * @notice A contract that distributes rewards to stakers. It requires that the staking token is
 * the same as the reward token. This is much more efficient than Synthetix' version.
 * @dev For funding the contract, use `addReward()`. DO NOT DIRECTLY SEND TOKENS TO THE CONTRACT!
 * @dev This contract can only distribute `2**96-1` tokens in total. And a user can have staked
 * balance of maximum `2**96-1`. Therefore do not use tokens with ridiculous supplies. User funds
 * would not get locked, but staking and reward funding would be effected.
 * @author shung
 */
contract StakingRewards is AccessControl {
    using SafeCast for uint256;
    using SafeCast160 for uint256;
    using SafeERC20 for IERC20;

    struct User {
        uint160 rewardPerTokenPaid;
        uint96 balance;
    }
    mapping(address => User) public users;

    uint160 public rewardPerTokenStored;
    uint96 public lastUpdate;

    uint96 public rewardRate;
    uint64 public periodFinish;
    uint96 private _totalRewardAdded;

    uint256 public totalStaked;
    uint256 public periodDuration = 1 days;

    uint256 private constant PRECISION = 2**64;
    uint256 private constant MAX_PERIOD = 2**32;

    bytes32 private constant FUNDER_ROLE = keccak256("FUNDER_ROLE");
    bytes32 private constant DURATION_ROLE = keccak256("DURATION_ROLE");

    IERC20 public immutable rewardToken;

    event Staked(address indexed user, uint256 amount, uint256 rewards);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event Harvested(address indexed user, uint256 reward);
    event Compounded(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event PeriodDurationUpdated(uint256 newDuration);

    modifier updateRewardPerTokenStored() {
        if (totalStaked != 0) {
            rewardPerTokenStored += ((_pendingRewards() * PRECISION) / totalStaked).toUint160();
        }
        lastUpdate = uint96(block.timestamp);
        _;
    }

    constructor(address newRewardToken, address newAdmin) {
        require(newRewardToken != address(0), "zero address");
        require(newAdmin != address(0), "zero address");
        rewardToken = IERC20(newRewardToken);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _grantRole(FUNDER_ROLE, newAdmin);
        _grantRole(DURATION_ROLE, newAdmin);
    }

    function stake(uint256 amount) external updateRewardPerTokenStored {
        require(amount != 0, "zero amount");
        User storage user = users[msg.sender];
        uint256 rewardPerToken = rewardPerTokenStored;
        uint256 reward = (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        uint256 totalAmount = amount + reward;
        totalStaked += totalAmount;
        user.balance += totalAmount.toUint96();
        user.rewardPerTokenPaid = uint160(rewardPerToken);
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, reward);
    }

    function harvest() external updateRewardPerTokenStored {
        User storage user = users[msg.sender];
        uint256 rewardPerToken = rewardPerTokenStored;
        uint256 reward = (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        require(reward != 0, "no rewards");
        user.rewardPerTokenPaid = uint160(rewardPerToken);
        rewardToken.safeTransfer(msg.sender, reward);
        emit Harvested(msg.sender, reward);
    }

    function withdraw(uint256 amount) external updateRewardPerTokenStored {
        require(amount > 0, "zero amount");
        User storage user = users[msg.sender];
        require(user.balance >= amount, "insufficient balance");
        uint256 rewardPerToken = rewardPerTokenStored;
        uint256 reward = (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        unchecked {
            totalStaked -= amount;
            user.balance -= uint96(amount);
        }
        user.rewardPerTokenPaid = uint160(rewardPerToken);
        rewardToken.safeTransfer(msg.sender, amount + reward);
        emit Withdrawn(msg.sender, amount, reward);
    }

    function compound() external updateRewardPerTokenStored {
        User storage user = users[msg.sender];
        uint256 rewardPerToken = rewardPerTokenStored;
        uint256 reward = (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        require(reward != 0, "no rewards");
        totalStaked += reward;
        user.balance += reward.toUint96();
        user.rewardPerTokenPaid = uint160(rewardPerToken);
        emit Compounded(msg.sender, reward);
    }

    function addReward(uint256 amount) external onlyRole(FUNDER_ROLE) updateRewardPerTokenStored {
        require(amount != 0, "zero amount");
        _totalRewardAdded += amount.toUint96(); // ensure rewards distributed fits 96 bits
        uint256 tmpPeriodDuration = periodDuration;
        if (block.timestamp >= periodFinish) {
            rewardRate = uint96(amount / tmpPeriodDuration);
        } else {
            uint256 leftover;
            unchecked {
                leftover = (periodFinish - block.timestamp) * rewardRate;
            }
            rewardRate = uint96((amount + leftover) / tmpPeriodDuration);
        }
        periodFinish = uint64(block.timestamp + tmpPeriodDuration);
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardAdded(amount);
    }

    function setPeriodDuration(uint256 newDuration) external onlyRole(DURATION_ROLE) {
        require(block.timestamp > periodFinish, "ongoing period");
        require(newDuration != 0, "invalid duration");
        require(newDuration <= MAX_PERIOD, "invalid duration");
        periodDuration = newDuration;
        emit PeriodDurationUpdated(newDuration);
    }

    function earned(address account) external view returns (uint256) {
        User memory user = users[account];
        uint256 rewardPerToken = totalStaked == 0
            ? rewardPerTokenStored
            : rewardPerTokenStored + (_pendingRewards() * PRECISION) / totalStaked;
        return (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
    }

    function _pendingRewards() private view returns (uint256) {
        unchecked {
            uint256 tmpPeriodFinish = periodFinish;
            uint256 lastTimeRewardApplicable = tmpPeriodFinish < block.timestamp
                ? tmpPeriodFinish
                : block.timestamp;
            uint256 tmpLastUpdate = lastUpdate;
            uint256 duration = lastTimeRewardApplicable > tmpLastUpdate
                ? lastTimeRewardApplicable - tmpLastUpdate
                : 0;
            return duration * rewardRate;
        }
    }
}
