require("@nomiclabs/hardhat-waffle");
require('hardhat-gas-reporter');
require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000
          }
        }
      }
    ]
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false
  }
};
