# DefLendAppMumbaiTestnet
# DEFI Lending and Borrowing DApp

Code is contained in the master branch.

This project is a simple DEFI lending and borrowing Dapp deployed to the MATIC mumbai testnet. There are 3 ERC-20 Tokens- Dethereum (which is the collateral token a borrower must possess and provide as collateral), Dusd (this is the borrowed stable coin asset, a lender must also lend in dusd tokens), DefToken (this is the governance/ native token of the Deflend contract and is paid to the lenders as interest and in some cases, the liquidator's fee). There are 2 ERC-721 tokens- DeflenderNFT (it is a non-transferable NFT issued to the lender, and, is burned when the lender withdraws all his/her dusd lent), DefborrowerNFT (it is a non-transferable NFT issued to the borrower, and, is burned when the borrower repays all his/her dusd borrowed).

Note: For simplicity sake, the value of all ERC-20 tokens are taken as 1. That is 1 dethereum is valued as 1 dusd, and 1 dusd is valued as 1 Deftoken. Borrower is required to have atleast 125% of total amount borrowed or wants to borrow deposited as dethereum collateral in the DefLend Smart contract i.e., if one wants to borrow 80000 dusd, he/she is required to deposit atleast 100000 dethereum into the DefLend Smart contract (demonstrating value of dethereum is equal to the value of dusd here).

The Main loan App Smart Contract is: 'DefLend.sol'.
Script for deploying used contracts is: 'deployedContracts.js'.
Script for deploying main loan smart contract is: 'deploy.js'.
Script for performing functions in the Loan App (such as lending and borrowing) is: 'defLend.js'.

Basic tests are done: './test/Deflend.js'.
