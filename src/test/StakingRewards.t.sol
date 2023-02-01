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

    function testStake(uint256 amount) public {
        if (amount > type(uint96).max) {
            vm.expectRevert(
                abi.encodeWithSelector(StakingRewards.InvalidStakeAmount.selector, amount)
            );
            stakingRewards.stake(amount);
        } else {
            uint160 rewardPerTokenStored = stakingRewards.rewardPerTokenStored();

            stakingRewards.stake(amount);

            (uint160 rewardPerTokenPaid, uint96 balance) = stakingRewards.users(address(this));
            assertEq(rewardPerTokenStored, rewardPerTokenPaid);
            assertEq(amount, balance);
            assertEq(IERC20(rewardsToken).balanceOf(address(this)), type(uint256).max - amount);
            assertEq(stakingRewards.totalStaked(), amount);
        }
    }

    function testWithdraw(uint96 stakeAmount, uint96 withdrawAmount) public {
        testStake(stakeAmount);

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
