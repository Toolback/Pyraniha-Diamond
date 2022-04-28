
/* global ethers task */
require('@nomiclabs/hardhat-waffle')
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

module.exports = {
  etherscan: {
    apiKey: process.env.POLYGON_API_KEY,
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: process.env.MATIC_URL,
        timeout: 12000000,
        // blockNumber: 12552123
        // blockNumber: 20024371,
      },
      blockGasLimit: 20000000,
      timeout: 120000,
      gas: "auto",
    },
    localhost: {
      timeout: 16000000,
    },
    matic: {
      url: process.env.MATIC_URL,
      // url: 'https://rpc-mainnet.maticvigil.com/',
      accounts: [process.env.SECRET_KEY],
      // blockGasLimit: 20000000,
      // gasPrice: 1000000000,
      timeout: 90000,
      gas: "auto",
    },
    rinkeby: {
      url: process.env.RINKEBY_URL,
      accounts: [process.env.SECRET_KEY],
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.7.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ],
    // overrides: {
    //   "contracts/BalancerPool.sol": {
    //     version: "0.7.0",
    //     settings: {}
    //   }
    // }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
}