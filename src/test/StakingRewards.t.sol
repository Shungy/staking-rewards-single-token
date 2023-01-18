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
    }

    function testFailStakeMoreThan96Bits(uint256 amount) public {
        vm.assume(amount > type(uint96).max);
        TestToken(rewardsToken).mint(address(this), amount);
        IERC20(rewardsToken).approve(address(stakingRewards), amount);
        stakingRewards.stake(amount);
    }

    function testStake(uint96 amount) public {
        uint160 rewardPerTokenStored = stakingRewards.rewardPerTokenStored();

        TestToken(rewardsToken).mint(address(this), amount);
        IERC20(rewardsToken).approve(address(stakingRewards), amount);
        stakingRewards.stake(amount);

        (uint160 rewardPerTokenPaid, uint96 balance) = stakingRewards.users(address(this));

        assertEq(rewardPerTokenStored, rewardPerTokenPaid);
        assertEq(amount, balance);
    }

    function testWithdraw(uint96 amount) public {
        testStake(amount);

        uint160 rewardPerTokenStored = stakingRewards.rewardPerTokenStored();

        stakingRewards.withdraw(amount);

        (uint160 rewardPerTokenPaid, uint96 balance) = stakingRewards.users(address(this));

        assertEq(rewardPerTokenStored, rewardPerTokenPaid);
        assertEq(0, balance);
    }
}
