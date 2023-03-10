require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config()

const polygon_mumbai = process.env.ALCHEMY_POLYGON_MUMBAI_API_KEY
const polygon_mainnet = process.env.ALCHEMY_POLYGON_MAINNET_API_KEY
const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY
const user1PrivateKey = process.env.USER1_PRIVATE_KEY
const user2PrivateKey = process.env.USER2_PRIVATE_KEY

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "maticmum",
  networks: {
    hardhat: {},
    polygon: {
      url: polygon_mainnet,
      accounts: [deployerPrivateKey]
    },
    maticmum: {
      url: polygon_mumbai,
      accounts: [deployerPrivateKey, user1PrivateKey, user2PrivateKey]
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}