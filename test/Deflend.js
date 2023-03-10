const {expect} = require('chai');
const {ethers} = require('hardhat');

describe('DefLend', () => {
  let dethereumCon, dusdCon, deftokenCon, deflenderNFTCon, defborrowerNFTCon, deflendCon
  let deployer, user, user2, user3
  beforeEach(async() => {
    [deployer, user, user2, user3] = await ethers.getSigners()

    const DethereumCon = await ethers.getContractFactory('Dethereum', deployer)
    dethereumCon = await DethereumCon.deploy()

    const DusdCon = await ethers.getContractFactory('Dusd', deployer)
    dusdCon = await DusdCon.deploy()

    const DefTokenCon = await ethers.getContractFactory('DefToken', deployer)
    deftokenCon = await DefTokenCon.deploy()

    const DeflenderNFTCon = await ethers.getContractFactory('DeflenderNFT', deployer)
    deflenderNFTCon = await DeflenderNFTCon.deploy()

    const DefborrowerNFTCon = await ethers.getContractFactory('DefborrowerNFT', deployer)
    defborrowerNFTCon = await DefborrowerNFTCon.deploy()

    let DefLendCon = await ethers.getContractFactory('DefLend', deployer)
    deflendCon = await DefLendCon.deploy(
        dethereumCon.address, dusdCon.address, deftokenCon.address,
        deflenderNFTCon.address, defborrowerNFTCon.address
    )

    await dusdCon.transfer(deflendCon.address, ethers.utils.parseEther('1000000'))
    await deftokenCon.transfer(deflendCon.address, ethers.utils.parseEther('1000000'))
  })

  describe('Token Contracts are deployed', () => {

    it('Lender: deposits dusd, lends, check balances, and withdraws', async() => {
      const value = ethers.utils.parseEther('10000')
      await dusdCon.transfer(user.address, value)
      expect(await dusdCon.balanceOf(user.address)).to.eq(value)

      // Approve dusd from user
      await dusdCon.connect(user).approve(deflendCon.address, value)
      expect(await dusdCon.allowance(user.address, deflendCon.address)).to.eq(value)

      // Lend some dusd tokens to user
      const userLendAmount = ethers.utils.parseEther('5304')
      await deflendCon.connect(user).lend(userLendAmount)
      const userFirstNFT = await deflendCon.displayLenderData(user.address)
      await deflendCon.connect(user).lend(ethers.utils.parseEther('696'))
      const userSecondNFT = await deflendCon.displayLenderData(user.address)
      expect(userFirstNFT).not.eq(userSecondNFT)

      expect(await deflenderNFTCon.balanceOf(user.address)).to.eq(1)
      expect(await deflendCon.amountDeposited(user.address)).to.eq(ethers.utils.parseEther('6000'))

      // Withdraw Interest accrued
      await deflendCon.connect(user).withdrawInterest()
      const userInterest = await deftokenCon.balanceOf(user.address)
      expect(userInterest).to.gt(0)
      console.log(await deflendCon.displayLenderData(user.address))

      // Withdraw both the Capital(dusd) and Interest(deftoken)
      const percentage = ethers.utils.parseEther('50')
      await deflendCon.connect(user).withdraw(percentage)
      expect(await deftokenCon.balanceOf(user.address)).to.gt(userInterest)
      expect(await dusdCon.balanceOf(user.address)).to.equal(value)
      //Should pass because lender NFT has withdrawn 100%
      expect(await deflenderNFTCon.balanceOf(user.address)).to.equal(0)
    })

    it('Borrows: deposits collateral, borrows, check balances, pays back', async() => {
      const value = ethers.utils.parseEther('10000')
      await dethereumCon.transfer(user2.address, value)
      await dusdCon.transfer(user2.address, value)
      expect(await dethereumCon.balanceOf(user2.address)).to.eq(value)

      // Approve dethereum from user2
      await dethereumCon.connect(user2).approve(deflendCon.address, value)
      expect(await dethereumCon.allowance(user2.address, deflendCon.address)).to.eq(value)

      // Deposit collateral
      const userDepositAmount = ethers.utils.parseEther('6700')
      await deflendCon.connect(user2).depositCollateral(userDepositAmount)
      await deflendCon.connect(user2).depositCollateral(ethers.utils.parseEther('300'))

      expect(await deflendCon.collateralDeposited(user2.address)).to.eq(ethers.utils.parseEther('7000'))

      // Withdraw Collateral
      await deflendCon.connect(user2).withdrawCollateral(ethers.utils.parseEther('1000'))
      const userDeposit = await deflendCon.collateralDeposited(user2.address)
      expect(userDeposit).to.eq(ethers.utils.parseEther('6000'))
      
      // Borrow
      const borrowAmount = ethers.utils.parseEther('2000')
      await deflendCon.connect(user2).borrow(borrowAmount)
      const borrowerFirstNFT = await deflendCon.displayBorrowerData(user2.address)
      await deflendCon.connect(user2).borrow(ethers.utils.parseEther('1000'))
      const borrowerSecondNFT = await deflendCon.displayBorrowerData(user2.address)
      expect(borrowerFirstNFT).not.eq(borrowerSecondNFT)

      // Repay dusd
      await dusdCon.connect(user2).approve(deflendCon.address, ethers.utils.parseEther('1000000'))
      await deflendCon.connect(user2).paybackAll()
      expect(await dusdCon.balanceOf(user2.address)).to.lt(value)
      const user2DethereumBalance = await dethereumCon.balanceOf(user2.address)

      /*await deflendCon.connect(user2).borrow(ethers.utils.parseEther('4000'))
      const borrowerThirdNFT = await deflendCon.displayBorrowerData(user2.address)
      console.log(borrowerThirdNFT)*/

      // Withdraw some collateral after paying
      await deflendCon.connect(user2).withdrawCollateral(ethers.utils.parseEther('5900'))
      expect(await dethereumCon.balanceOf(user2.address)).to.gt(user2DethereumBalance)
    })

  })
})