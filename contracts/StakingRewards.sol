// SPDX-License-Identifier: GPLv3
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Staking Rewards Single Token
 * @notice A contract that distributes rewards to stakers. It requires that the staking token is
 * the same as the reward token. This is much more efficient than Synthetix' version.
 * @dev For funding the contract, use `addReward()`. DO NOT DIRECTLY SEND TOKENS TO THE CONTRACT!
 * @dev Limitations (checked through input sanitization):
 *        1) The sum of all tokens added through `addReward()` cannot exceed `2**96-1`,
 *        2) A user's staked balance cannot exceed `2**96-1`.
 * @dev Assumptions (not checked, assumed to be always true):
 *        1) `block.timestamp < 2**64 - 2**32`,
 *        2) rewardToken returns false or reverts on failing transfers,
 *        3) Number of users does not exceed `(2**256-1)/(2**96-1)`.
 * @author shung
 */
contract StakingRewards is AccessControl {
    struct User {
        uint160 rewardPerTokenPaid;
        uint96 balance;
    }

    mapping(address => User) public users;

    uint160 public rewardPerTokenStored;
    uint96 public lastUpdate;

    uint96 public rewardRate;
    uint64 public periodFinish;
    uint96 private totalRewardAdded;

    uint256 public totalStaked;
    uint256 public periodDuration = 1 days;

    uint256 private constant PRECISION = type(uint64).max;
    uint256 private constant MAX_ADDED = type(uint96).max;
    uint256 private constant MAX_PERIOD = type(uint32).max;
    uint256 private constant MAX_BALANCE = type(uint96).max;

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
        unchecked {
            if (totalStaked != 0) {
                rewardPerTokenStored = uint160(
                    rewardPerTokenStored + ((_pendingRewards() * PRECISION) / totalStaked)
                );
            }
            lastUpdate = uint96(block.timestamp);
        }
        _;
    }

    constructor(address newRewardToken, address newAdmin) {
        unchecked {
            require(newRewardToken != address(0), "zero address");
            require(newAdmin != address(0), "zero address");
            rewardToken = IERC20(newRewardToken);
            _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
            _grantRole(FUNDER_ROLE, newAdmin);
            _grantRole(DURATION_ROLE, newAdmin);
        }
    }

    function stake(uint256 amount) external updateRewardPerTokenStored {
        unchecked {
            User storage user = users[msg.sender];
            uint256 tmpBalance = user.balance;
            require(
                amount != 0 && amount <= MAX_BALANCE && tmpBalance + amount <= MAX_BALANCE,
                "invalid amount"
            );
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 reward = (tmpBalance * (uint256(rewardPerToken) - user.rewardPerTokenPaid)) /
                PRECISION;
            uint256 totalAmount = amount + reward;
            require(tmpBalance + totalAmount <= MAX_BALANCE, "harvest first then stake");
            totalStaked += totalAmount;
            user.balance = uint96(tmpBalance + totalAmount);
            user.rewardPerTokenPaid = uint160(rewardPerToken);
            require(
                rewardToken.transferFrom(msg.sender, address(this), amount),
                "transfer failed"
            );
            emit Staked(msg.sender, amount, reward);
        }
    }

    function harvest() external updateRewardPerTokenStored {
        unchecked {
            User storage user = users[msg.sender];
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 reward = (user.balance * (uint256(rewardPerToken) - user.rewardPerTokenPaid)) /
                PRECISION;
            require(reward != 0, "no rewards");
            user.rewardPerTokenPaid = rewardPerToken;
            require(rewardToken.transfer(msg.sender, reward), "transfer failed");
            emit Harvested(msg.sender, reward);
        }
    }

    function withdraw(uint256 amount) external updateRewardPerTokenStored {
        unchecked {
            require(amount != 0, "zero amount");
            User storage user = users[msg.sender];
            uint256 tmpBalance = user.balance;
            require(tmpBalance >= amount, "insufficient balance");
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 reward = (tmpBalance * (uint256(rewardPerToken) - user.rewardPerTokenPaid)) /
                PRECISION;
            totalStaked -= amount;
            user.balance = uint96(tmpBalance - amount);
            user.rewardPerTokenPaid = rewardPerToken;
            require(rewardToken.transfer(msg.sender, amount + reward), "transfer failed");
            emit Withdrawn(msg.sender, amount, reward);
        }
    }

    function compound() external updateRewardPerTokenStored {
        unchecked {
            User storage user = users[msg.sender];
            uint256 tmpBalance = user.balance;
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 reward = (tmpBalance * (uint256(rewardPerToken) - user.rewardPerTokenPaid)) /
                PRECISION;
            require(reward != 0, "no rewards");
            require(tmpBalance + reward <= MAX_BALANCE, "balance does not fit 96 bits");
            totalStaked += reward;
            user.balance = uint96(tmpBalance + reward);
            user.rewardPerTokenPaid = rewardPerToken;
            emit Compounded(msg.sender, reward);
        }
    }

    function addReward(uint256 amount) external onlyRole(FUNDER_ROLE) updateRewardPerTokenStored {
        unchecked {
            uint256 tmpTotalRewardAdded = totalRewardAdded;
            uint256 tmpPeriodFinish = periodFinish;
            uint256 tmpPeriodDuration = periodDuration;
            require(
                amount != 0 && amount <= MAX_ADDED && tmpTotalRewardAdded + amount <= MAX_ADDED,
                "invalid amount"
            );
            totalRewardAdded = uint96(tmpTotalRewardAdded + amount);
            if (block.timestamp >= tmpPeriodFinish) {
                rewardRate = uint96(amount / tmpPeriodDuration);
            } else {
                uint256 leftover = (tmpPeriodFinish - block.timestamp) * rewardRate;
                rewardRate = uint96((amount + leftover) / tmpPeriodDuration);
            }
            periodFinish = uint64(block.timestamp + tmpPeriodDuration);
            require(
                rewardToken.transferFrom(msg.sender, address(this), amount),
                "transfer failed"
            );
            emit RewardAdded(amount);
        }
    }

    function setPeriodDuration(uint256 newDuration) external onlyRole(DURATION_ROLE) {
        unchecked {
            require(block.timestamp > periodFinish, "ongoing period");
            require(newDuration != 0 && newDuration <= MAX_PERIOD, "invalid duration");
            periodDuration = newDuration;
            emit PeriodDurationUpdated(newDuration);
        }
    }

    function earned(address account) external view returns (uint256) {
        unchecked {
            User memory user = users[account];
            uint256 rewardPerToken = totalStaked == 0
                ? rewardPerTokenStored
                : rewardPerTokenStored + (_pendingRewards() * PRECISION) / totalStaked;
            return (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        }
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
