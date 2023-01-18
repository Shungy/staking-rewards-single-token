// test/SunshineAndRainbows.js
// Load dependencies
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const ONE_DAY = BigNumber.from("86400");
const SUPPLY = ethers.utils.parseUnits("10000000", 18);
const ZERO_ADDRESS = ethers.constants.AddressZero;
const FUNDER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("FUNDER"));
const PRECISION = BigNumber.from("2").pow("256");
const UINT256_MAX = ethers.constants.MaxUint256;

function getRewards(duration) {
  return SUPPLY.div(ONE_DAY.mul("100")).mul(duration);
}

function updateRewardVariables(rewards, stakingDuration, sinceInit) {
  var idealPosition = rewards
    .mul(sinceInit)
    .mul(PRECISION.div(stakingDuration));
  var rewardsPerStakingDuration = rewards.mul(PRECISION.div(stakingDuration));

  return [idealPosition, rewardsPerStakingDuration];
}

describe("StakingRewards.sol", function () {
  before(async function () {
    // Get all signers
    this.signers = await ethers.getSigners();
    this.admin = this.signers[0];
    this.unauthorized = this.signers[1];

    // get contract factories
    this.TestToken = await ethers.getContractFactory("TestToken");
    this.StakingRewards = await ethers.getContractFactory("StakingRewards");
  });

  beforeEach(async function () {
    this.token = await this.TestToken.deploy();
    await this.token.deployed();

    this.staking = await this.StakingRewards.deploy(this.token.address, this.admin.address);
    await this.staking.deployed();

    await this.token.approve(this.staking.address, ethers.constants.MaxUint256);
    await this.token.mint(this.admin.address, SUPPLY);

    await this.staking.setPeriodDuration(ONE_DAY.mul(30));
    await this.staking.addReward(SUPPLY);

    var blockNumber = await ethers.provider.getBlockNumber();
    this.notifyRewardTime = (
      await ethers.provider.getBlock(blockNumber)
    ).timestamp;
  });

  describe("stake", function () {
    it("stakes thrice", async function () {
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
    });
  });

  describe("withdraw", function () {
    it("withdraw", async function () {
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.withdraw(SUPPLY.div("3"))).to.emit(this.staking, "Withdrawn");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.withdraw(SUPPLY.div("3"))).to.emit(this.staking, "Withdrawn");


      var balance = (await this.staking.users(this.admin.address)).balance;

      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.withdraw(balance)).to.emit(this.staking, "Withdrawn");
    });
  });

  describe("harvest", function () {
    it("harvest", async function () {
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.withdraw(0)).to.emit(this.staking, "Withdrawn");
    });
  });

  describe("compound", function () {
    it("compound", async function () {
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(0)).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(0)).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(0)).to.emit(this.staking, "Staked");
    });
  });

  describe("addReward", function () {
    it("addReward", async function () {
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.stake(SUPPLY.div("3"))).to.emit(this.staking, "Staked");

      await this.token.mint(this.admin.address, SUPPLY);

      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
      await ethers.provider.send("evm_increaseTime", [ONE_DAY.toNumber()]);
      await expect(this.staking.addReward(SUPPLY.div(10))).to.emit(this.staking, "RewardAdded");
    });
  });
});
