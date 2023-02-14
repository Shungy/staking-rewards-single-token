pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../StakingRewards.sol";
import "../mocks/TestToken.sol";

contract StakingRewardsTests is Test {
    address rewardsToken;
    StakingRewards stakingRewards;

    function setUp() public {
        rewardsToken = address(new TestToken());
        stakingRewards = new StakingRewards(rewardsToken, address(this));
        TestToken(rewardsToken).mint(address(this), type(uint256).max);
        IERC20(rewardsToken).approve(address(stakingRewards), type(uint256).max);
    }

    function test_RevertWhen_AddRewardOverflow(uint256 amount) public {
        amount = bound(amount, uint256(type(uint96).max) + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(StakingRewardsFunding.InvalidRewardAmount.selector, amount)
        );
        stakingRewards.addReward(amount);
    }

    function test_RevertWhen_AddRewardZeroRewardRate(uint256 amount) public {
        uint256 minRewardAmount = stakingRewards.periodDuration();
        amount = bound(amount, 0, minRewardAmount - 1);
        vm.expectRevert(
            abi.encodeWithSelector(StakingRewardsFunding.InvalidRewardRate.selector, 0)
        );
        stakingRewards.addReward(amount);
    }

    function test_AddRewardTwice(uint256 amount) public {
        uint256 minRewardAmount = stakingRewards.periodDuration();
        amount = bound(amount, minRewardAmount, type(uint96).max / 2);
        test_AddReward(amount);
        test_AddReward(amount);
    }

    function test_AddReward(uint256 amount) public {
        uint256 minRewardAmount = stakingRewards.periodDuration();
        amount = bound(amount, minRewardAmount, type(uint96).max);

        uint256 rewardRate = stakingRewards.rewardRate();

        stakingRewards.addReward(amount);

        assertEq(stakingRewards.rewardRate(), rewardRate + amount / stakingRewards.periodDuration());
    }

    function test_RevertWhen_StakeOverflow(uint256 amount) public {
        amount = bound(amount, uint256(type(uint96).max) + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(StakingRewards.InvalidStakeAmount.selector, amount)
        );
        stakingRewards.stake(amount);
    }

    function test_Stake(uint256 amount) public {
        amount = bound(amount, 0, type(uint96).max);

        uint160 rewardPerTokenStored = stakingRewards.rewardPerTokenStored();

        stakingRewards.stake(amount);

        (uint160 rewardPerTokenPaid, uint96 balance) = stakingRewards.users(address(this));
        assertEq(rewardPerTokenStored, rewardPerTokenPaid);
        assertEq(amount, balance);
        assertEq(IERC20(rewardsToken).balanceOf(address(this)), type(uint256).max - amount);
        assertEq(stakingRewards.totalStaked(), amount);
    }

    function test_Withdraw(uint96 stakeAmount, uint96 withdrawAmount) public {
        test_Stake(stakeAmount);

        if (stakeAmount < withdrawAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StakingRewards.InvalidWithdrawAmount.selector, withdrawAmount, stakeAmount
                )
            );
            stakingRewards.withdraw(withdrawAmount);
        } else {
            uint160 rewardPerTokenStored = stakingRewards.rewardPerTokenStored();

            stakingRewards.withdraw(withdrawAmount);

            (uint160 rewardPerTokenPaid, uint96 balance) = stakingRewards.users(address(this));
            assertEq(rewardPerTokenStored, rewardPerTokenPaid);
            assertEq(stakeAmount - withdrawAmount, balance);
            assertEq(
                IERC20(rewardsToken).balanceOf(address(this)),
                type(uint256).max - stakeAmount + withdrawAmount
            );
            assertEq(stakingRewards.totalStaked(), stakeAmount - withdrawAmount);
        }
    }
}
