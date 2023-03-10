
const { ethers } = require('hardhat');

const Contracts = require('./deployedContracts.js')

const dethereumAddress = '0xbD1721068BF5Be865af37aa89cd86B4be397f317'
const dusdContractAddress = '0xf591297fA547374CD9dFE4C0F21E44be220f8c45'
const deftokenAddress = '0x5FB1bDc3f24fdBf85273b4Db244B47820882e470'
const deflenderNFTAddress = '0xb96049deF42fc6B868E737edFb67F75eAbF5E8bd'
const defborrowerNFTAddress = '0x2Ed0420f5e51B6d26E0FE97C13e8fC7A9a581Ca3'

const defLend = '0x97836e35D6BDE6307606fAf6669383EB371152DC' //old contract '0x8F2baA4cd16d67ea4E8142D150980Df5D77FF947'

let deployDefLendApp = {
    loadContracts: async function deployDusdToken () {
        const dusdAddress = (await Contracts.DeployedContracts.dusdToken()).address
        const dethereumAddress = (await Contracts.DeployedContracts.dethereumToken()).address
        const deftokenAddress = (await Contracts.DeployedContracts.defToken()).address
        const deflenderNFTAddress = (await Contracts.DeployedContracts.deflenderNFTToken()).address
        const defborrowerNFTAddress = (await Contracts.DeployedContracts.defborrowerNFTToken()).address

        console.log(dusdAddress)
        console.log(dethereumAddress)
        console.log(deftokenAddress)
        console.log(deflenderNFTAddress)
        console.log(defborrowerNFTAddress)
    },

    defLendContract: async function deployDusdToken () {
        let [deployer] = await ethers.getSigners()
        const DefLend = await ethers.getContractFactory('DefLend', deployer)
        const defLend = await DefLend.deploy(
            dethereumAddress, dusdContractAddress, deftokenAddress,
            deflenderNFTAddress, defborrowerNFTAddress
        )
        await defLend.deployed()
        console.log(defLend)
        console.log(defLend.address)
        return defLend
    },
}

Main = async() => {
    //await deployDefLendApp.loadContracts()
    
    //await deployDefLendApp.defLendContract()
}
Main()