// SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.4;

import "openzeppelin/access/AccessControlEnumerable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";

/**
 * @title Staking Rewards Funding
 * @author Shung for Pangolin
 * @notice A contract that is only the rewards part of `StakingRewards`.
 * @dev The inheriting contract must call `_claim()` to check its reward since the last time the
 *      same call was made. Then, based on the reward amount, the inheriting contract shall
 *      determine the distribution to stakers. The purpose of this architecture is to separate the
 *      logic of funding from the staking and reward distribution.
 */
abstract contract StakingRewardsFunding is AccessControlEnumerable {
    uint80 private _rewardRate;
    uint40 public lastUpdate;
    uint40 public periodFinish;
    uint96 public totalRewardAdded;
    uint256 public periodDuration = 1 days;
    IERC20 public immutable rewardsToken;
    bytes32 public constant FUNDER_ROLE = keccak256("FUNDER_ROLE");
    uint256 internal constant PRECISION = type(uint64).max;
    uint256 internal constant MAX_TOKEN = type(uint96).max;
    uint256 internal constant MIN_PERIOD_DURATION = 2 ** 16 + 1;
    uint256 internal constant MAX_PERIOD_DURATION = type(uint32).max;

    event PeriodManuallyEnded(uint256 originalEndTime);
    event RewardAdded(uint256 reward);
    event PeriodDurationUpdated(uint256 newDuration);

    error InvalidNewAdmin(address newAdmin);
    error InvalidRewardsToken(address newRewardsToken);
    error ShortPeriodDuration(uint256 newDuration);
    error LongPeriodDuration(uint256 newDuration);
    error OngoingPeriod(uint256 currentPeriodFinish);
    error FinishedPeriod(uint256 lastPeriodFinish);
    error InvalidRewardAmount(uint256 addedReward);
    error InvalidRewardRate(uint256 newRewardRate);
    error FailedTransferTo(address recipient, uint256 amount);
    error FailedTransferFrom(address sender, uint256 amount);

    constructor(address newRewardsToken, address newAdmin) {
        if (newAdmin == address(0)) revert InvalidNewAdmin(newAdmin);
        if (newRewardsToken.code.length == 0) revert InvalidRewardsToken(newRewardsToken);
        rewardsToken = IERC20(newRewardsToken);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _grantRole(FUNDER_ROLE, newAdmin);
    }

    function setPeriodDuration(uint256 newDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tmpPeriodFinish = periodFinish;
        if (tmpPeriodFinish > block.timestamp) revert OngoingPeriod(tmpPeriodFinish);
        if (newDuration < MIN_PERIOD_DURATION) revert ShortPeriodDuration(newDuration);
        if (newDuration > MAX_PERIOD_DURATION) revert LongPeriodDuration(newDuration);
        periodDuration = newDuration;
        emit PeriodDurationUpdated(newDuration);
    }

    function endPeriod() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tmpPeriodFinish = periodFinish;
        if (block.timestamp >= tmpPeriodFinish) revert FinishedPeriod(tmpPeriodFinish);
        unchecked {
            uint256 leftover = (tmpPeriodFinish - block.timestamp) * _rewardRate;
            totalRewardAdded -= uint96(leftover);
            periodFinish = uint40(block.timestamp);
            _transferToCaller(leftover);
            emit PeriodManuallyEnded(tmpPeriodFinish);
        }
    }

    function addReward(uint256 amount) external onlyRole(FUNDER_ROLE) {
        uint256 tmpPeriodDuration = periodDuration;
        if (amount > MAX_TOKEN) revert InvalidRewardAmount(amount);
        totalRewardAdded += uint96(amount);
        // Update the _rewardRate, ensuring leftover rewards from the ongoing period are included.
        // Note that we are using `lastUpdate` instead of `block.timestamp`, otherwise we would
        // have to “stash” the rewards from `lastUpdate` to `block.timestamp` in storage. We
        // do not want to stash the rewards to keep the cost low. However, using this method means
        // that `_pendingRewards()` will change, hence a user might “lose” rewards earned since
        // `lastUpdate`. It is not a very big deal as the `lastUpdate` is likely to be updated
        // frequently, but just something to acknowledge.
        uint256 newRewardRate;
        if (lastUpdate >= periodFinish) {
            assembly {
                newRewardRate := div(amount, tmpPeriodDuration)
            }
        } else {
            unchecked {
                uint256 leftover = (periodFinish - lastUpdate) * _rewardRate;
                assembly {
                    newRewardRate := div(add(amount, leftover), tmpPeriodDuration)
                }
            }
        }
        if (newRewardRate == 0) revert InvalidRewardRate(newRewardRate);
        _rewardRate = uint80(newRewardRate);
        unchecked {
            lastUpdate = uint40(block.timestamp);
            periodFinish = uint40(block.timestamp + tmpPeriodDuration);
        }
        _transferFromCaller(amount);
        emit RewardAdded(amount);
    }

    function rewardRate() public view returns (uint256) {
        return periodFinish < block.timestamp ? 0 : _rewardRate;
    }

    function _claim() internal returns (uint256 reward) {
        reward = _pendingRewards();
        lastUpdate = uint40(block.timestamp);
    }

    function _transferToCaller(uint256 amount) internal {
        if (!rewardsToken.transfer(msg.sender, amount)) {
            revert FailedTransferTo(msg.sender, amount);
        }
    }

    function _transferFromCaller(uint256 amount) internal {
        if (!rewardsToken.transferFrom(msg.sender, address(this), amount)) {
            revert FailedTransferFrom(msg.sender, amount);
        }
    }

    function _pendingRewards() internal view returns (uint256 rewards) {
        uint256 tmpPeriodFinish = periodFinish;
        uint256 lastTimeRewardApplicable =
            tmpPeriodFinish < block.timestamp ? tmpPeriodFinish : block.timestamp;
        uint256 tmpLastUpdate = lastUpdate;
        if (lastTimeRewardApplicable > tmpLastUpdate) {
            unchecked {
                rewards = (lastTimeRewardApplicable - tmpLastUpdate) * _rewardRate;
            }
        }
    }
}
