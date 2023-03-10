const { ethers } = require('hardhat');

const dethereumAddress = '0xbD1721068BF5Be865af37aa89cd86B4be397f317'
const dusdAddress = '0xf591297fA547374CD9dFE4C0F21E44be220f8c45'
const deftokenAddress = '0x5FB1bDc3f24fdBf85273b4Db244B47820882e470'
const deflenderNFTAddress = '0xb96049deF42fc6B868E737edFb67F75eAbF5E8bd'
const defborrowerNFTAddress = '0x2Ed0420f5e51B6d26E0FE97C13e8fC7A9a581Ca3'

const defLendAddress = '0x97836e35D6BDE6307606fAf6669383EB371152DC' //old contract'0x8F2baA4cd16d67ea4E8142D150980Df5D77FF947'
const deployerAddress = '0xCF7869798aa5132Ef4A245fAE10aC79aB7e62375'
const lenderAddress = '0x3c96Eaa2e4ec538b5115D03294AEab385c980965'
const borrowerAddress = '0xAA7B5037A4d9451233a746d96F96E3Fb04b70E1D'

let DefLendApp = {
    dethereum: async function funcDethereum() {
        let Dethereum = await ethers.getContractFactory('Dethereum')
        return Dethereum.attach(dethereumAddress)
    },

    dusd: async function funcDusd() {
        let Dusd = await ethers.getContractFactory('Dusd')
        return Dusd.attach(dusdAddress)
    },

    deftoken: async function funcDeftoken() {
        let DefToken = await ethers.getContractFactory('DefToken')
        return DefToken.attach(deftokenAddress)
    },

    defLend: async function funcDefLend() {
        let DefLend = await ethers.getContractFactory('DefLend')
        return DefLend.attach(defLendAddress)
    },

    deflenderNFT: async function funcDeflenderNFT() {
        let DeflenderNFT = await ethers.getContractFactory('DeflenderNFT')
        return DeflenderNFT.attach(deflenderNFTAddress)
    },

    transferToDefLend: async function funcTransferToDefLend() {
        let dethereum = await this.dethereum()
        let dusd = await this.dusd()
        let deftoken = await this.deftoken()

        await dethereum.transfer(defLendAddress, ethers.utils.parseEther('1000000'))
        await dusd.transfer(defLendAddress, ethers.utils.parseEther('1000000'))
        await deftoken.transfer(defLendAddress, ethers.utils.parseEther('1000000'))
    },

    transferToLenderAndBorrower: async function funcTransferToLenderAndBorrower() {
        let dethereum = await this.dethereum()
        let dusd = await this.dusd()

        // Transfer dusd tokens to the lender
        await dusd.transfer(lenderAddress, ethers.utils.parseEther('100000'))

        // Transfer dethereum and some dusd(to pay for debts) tokens to the borrower
        await dusd.transfer(borrowerAddress, ethers.utils.parseEther('10000'))
        await dethereum.transfer(borrowerAddress, ethers.utils.parseEther('100000'))
    }
}

let LenderApp = {
    lend: async function funcLend() {
        let dethereum = await DefLendApp.dethereum()
        let dusd = await DefLendApp.dusd()
        let deftoken = await DefLendApp.deftoken()
        let defLend = await DefLendApp.defLend()

        let [,lender,] = await ethers.getSigners()
        const lendAmount = ethers.utils.parseEther('10000')

        // Approve dusd spending allowance
        await dusd.connect(lender).functions.approve(defLend.address, ethers.utils.parseEther('100000'))

        // Lend
        await defLend.connect(lender).functions.lend(lendAmount, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
        console.log(await defLend.functions.displayLenderData(lender.address))
        console.log(`Deposited Fund by Lender: ${await defLend.functions.amountDeposited(lender.address)}`)
    },

    withdrawInterest: async function funcWithdrawInterest() {
        let deftoken = await DefLendApp.deftoken()
        let defLend = await DefLendApp.defLend()

        let [,lender,] = await ethers.getSigners()

        // Withdraw Interest only
        await defLend.connect(lender).functions.withdrawInterest({
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
        console.log(`DefToken Interest: ${await deftoken.functions.balanceOf(lender.address)}`)
        console.log(await defLend.functions.displayLenderData(lender.address))
        console.log(`Deposited Fund by Lender: ${await defLend.functions.amountDeposited(lender.address)}`)
    },

    withdraw: async function funcWithdraw() {
        let dusd = await DefLendApp.dusd()
        let deftoken = await DefLendApp.deftoken()
        let defLend = await DefLendApp.defLend()

        let [,lender,] = await ethers.getSigners()
        const withdrawPercentage = ethers.utils.parseEther('50')

        // Withdraw
        await defLend.connect(lender).functions.withdraw(withdrawPercentage, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
        console.log(`DefToken Interest: ${await deftoken.functions.balanceOf(lender.address)}`)
        console.log(`Dusd Balance: ${await dusd.functions.balanceOf(lender.address)}`)
        console.log(await defLend.functions.displayLenderData(lender.address))
        console.log(`Deposited Fund by Lender: ${await defLend.functions.amountDeposited(lender.address)}`)
    },

    burn: async function funcBurn() {
        let dusd = await DefLendApp.dusd()
        let deftoken = await DefLendApp.deftoken()
        let defLend = await DefLendApp.defLend()
        let deflenderNFT_ = await DefLendApp.deflenderNFT()

        let [,lender,] = await ethers.getSigners()
        const withdrawPercentage = ethers.utils.parseEther('100')

        // Withdraw
        await deflenderNFT_.connect(lender).functions.burn(3, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
    }
}

let BorrowerApp = {
    depositCollateral: async function funcDepositCollateral() {
        let dethereum = await DefLendApp.dethereum()
        let defLend = await DefLendApp.defLend()

        let [,,borrower] = await ethers.getSigners()
        const depositAmount = ethers.utils.parseEther('10000')

        // Approve dethereum spending allowance
        await dethereum.connect(borrower).functions.approve(
            defLend.address, ethers.utils.parseEther('100000')
        )

        // Deposit Dethereum Collateral
        await defLend.connect(borrower).functions.depositCollateral(depositAmount, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
        console.log(`Collateral deposited by Borrower: ${await defLend.functions.collateralDeposited(borrower.address)}`)
    },

    withdrawCollateral: async function funcWithdrawCollateral() {
        let defLend = await DefLendApp.defLend()

        let [,,borrower] = await ethers.getSigners()
        const withdrawAmount = ethers.utils.parseEther('10000')

        // Withdraw Collateral
        await defLend.connect(borrower).functions.withdrawCollateral(withdrawAmount, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
        console.log(`Collateral Deposited by Borrower: ${await defLend.functions.collateralDeposited(borrower.address)}`)
    },

    borrow: async function funcBorrow() {
        let dusd = await DefLendApp.dusd()
        let defLend = await DefLendApp.defLend()

        let [,,borrower] = await ethers.getSigners()
        const borrowAmount = ethers.utils.parseEther('1000')

        // Borrow
        await defLend.connect(borrower).functions.borrow(borrowAmount, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })

        console.log(`Dusd Balance: ${await dusd.functions.balanceOf(borrower.address)}`)
        console.log(await defLend.functions.displayBorrowerData(borrower.address))
    },

    paybackAll: async function funcPaybackAll() {
        let dusd = await DefLendApp.dusd()
        let defLend = await DefLendApp.defLend()

        let [,,borrower] = await ethers.getSigners()

        // Approve dusd spending allowance
        await dusd.connect(borrower).functions.approve(
            defLend.address, ethers.utils.parseEther('100000')
        )
        console.log(`Dusd balance of Borrower before payback: ${await dusd.balanceOf(borrower.address)}`)

        // Payback All the dusd debt (borrowed fund + accrued interest)
        await defLend.connect(borrower).functions.paybackAll({
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })
        console.log(`Collateral deposited by Borrower: ${await defLend.functions.collateralDeposited(borrower.address)}`)
        console.log(`Dusd balance of Borrower after payback: ${await dusd.balanceOf(borrower.address)}`)
    }
}

let LiquidateApp = {
    liquidate: async function funcLiquidate() {
        let dusd = await DefLendApp.dusd()
        let dethereum = await DefLendApp.dethereum()
        let defLend = await DefLendApp.defLend()

        let [deployer,,borrower] = await ethers.getSigners()

        // Balances before liquidation
        console.log(`Dusd balance of Borrower before liquidation: ${await dusd.balanceOf(borrower.address)}`)
        console.log(`Dethereum balance of Borrower before liquidation: ${await dethereum.balanceOf(borrower.address)}`)
        console.log(`Dethereum balance of Deployer before liquidation: ${await dethereum.balanceOf(deployer.address)}`)

        // Liquidate a borrower
        await defLend.connect(deployer).functions.liquidate(borrower, {
            gasLimit: 6700000, gasPrice: Number(await ethers.provider.getGasPrice())
        })

        // Balances after liquidation
        console.log(`Collateral deposited by Borrower: ${await defLend.functions.collateralDeposited(borrower.address)}`)
        console.log(`Dusd balance of Borrower after liquidation: ${await dusd.balanceOf(borrower.address)}`)
        console.log(`Dethereum balance of Borrower after liquidation: ${await dethereum.balanceOf(borrower.address)}`)
        console.log(`Dethereum balance of Deployer after liquidation: ${await dethereum.balanceOf(deployer.address)}`)
    }
}

Main = async() => {
    //await DefLendApp.transferToDefLend()
    //await DefLendApp.transferToLenderAndBorrower()

    //await LenderApp.lend()
    //await LenderApp.withdrawInterest()
    await LenderApp.withdraw()
    //await LenderApp.burn()

    //await BorrowerApp.depositCollateral()
    //await BorrowerApp.withdrawCollateral()
    //await BorrowerApp.borrow()
    //await BorrowerApp.paybackAll()

    //await LiquidateApp.liquidate()
}
Main()