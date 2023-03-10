// Deploy all the smart contracts

const { ethers } = require('hardhat');

let dethereum, dusd, defToken, deflenderNFT, defborrowerNFT, deployer
module.exports['DeployedContracts'] = {
  dusdToken: async function deployDusdToken () {
    [deployer] = await ethers.getSigners()
    const Dusd = await ethers.getContractFactory('Dusd', deployer)
    dusd = await Dusd.deploy()
    await dusd.deployed()
    return dusd
  },

  dethereumToken: async function deployDethereumToken () {
    [deployer] = await ethers.getSigners()
    const Dethereum = await ethers.getContractFactory('Dethereum', deployer)
    dethereum = await Dethereum.deploy()
    await dethereum.deployed()
    return dethereum
  },

  defToken: async function deployDefToken () {
    [deployer] = await ethers.getSigners()
    const DefToken = await ethers.getContractFactory('DefToken', deployer)
    defToken = await DefToken.deploy()
    await defToken.deployed()
    return defToken
  },

  deflenderNFTToken: async function deployDeflenderNFTToken () {
    [deployer] = await ethers.getSigners()
    const DeflenderNFT = await ethers.getContractFactory('DeflenderNFT', deployer)
    deflenderNFT = await DeflenderNFT.deploy()
    await deflenderNFT.deployed()
    return deflenderNFT
  },

  defborrowerNFTToken: async function deployDefborrowerNFTToken () {
    [deployer] = await ethers.getSigners()
    const DefborrowerNFT = await ethers.getContractFactory('DefborrowerNFT', deployer)
    defborrowerNFT = await DefborrowerNFT.deploy()
    await defborrowerNFT.deployed()
    return defborrowerNFT
  }
}