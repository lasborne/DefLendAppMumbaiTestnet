// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './Dethereum.sol';
import './Dusd.sol';
import './DefToken.sol';
import './DeflenderNFT.sol';
import './DefborrowerNFT.sol';

contract DefLend is ReentrancyGuard{
    error BorrowerError(uint256 _amount);

    Dethereum public dethereum;
    Dusd public dusd;
    DefToken public deftoken;
    DeflenderNFT public deflenderNFT;
    DefborrowerNFT public defborrowerNFT;

    uint256[] borrowersId = [0];
    uint256[] lendersId = [0];
    uint256 lendersRate = ((10**18)/2500);
    uint256 borrowersRate = ((2*(10**18))/2500);
    uint256 lendersRatePerSec = (lendersRate/(3600));
    uint256 borrowersRatePerSec = (borrowersRate/(3600));

    mapping(address => bytes) private borrowerData;
    mapping(address => bytes) private lenderData;
    mapping(address => mapping(bool => uint256)) public getBorrowerId;
    mapping(address => mapping(bool => uint256)) public getLenderId;

    mapping(address => bool) private deposited;
    mapping(address => uint256) private lendTime;
    mapping(address => uint256) public amountDeposited;

    mapping(address => bool) private isCollateralDeposited;
    mapping(address => uint256) public collateralDeposited;

    mapping(address => uint256) private borrowTime;
    mapping(address => bool) private isBorrower;
    mapping(address => uint256) public borrowAmount;
    mapping(address => uint256) public totalInterest;
    mapping(address => uint256) public lastAmountBorrowed;

    constructor(
        Dethereum _dethereum, Dusd _dusd, DefToken _deftoken,
        DeflenderNFT _deflenderNFT, DefborrowerNFT _defborrowerNFT
    ) {
        dethereum = _dethereum;
        dusd = _dusd;
        deftoken = _deftoken;
        deflenderNFT = _deflenderNFT;
        defborrowerNFT = _defborrowerNFT;
    }

    event DepositCollateral(address indexed _depositor, uint256 _amount);
    event WithdrawCollateral(address indexed _withdrawer, uint256 _amount);
    event Borrow(address indexed _borrower, uint256 _amount, uint256 time);
    event PaybackAll(address indexed _borrower, uint256 _amount, uint256 time);
    event Lend(address indexed _lender, uint256 _amount, uint256 time);
    event WithdrawLenderInterest(address indexed _lender, uint256 _interest, uint256 time);
    event Liquidate(address indexed _liquidator, address indexed _borrower, uint256 _amount, uint256 time);

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), 'Zero address!');
        _;
    }

    /**
     * @dev Deposits Collateral, dethereum token into this smart contract by transferring from the user.
     * An approve from the user must be called to allow this smart contract spend the token.
     *
     * Requirements:
     *
     * - `_amount` can not be zero.
     * - Approval must be gotten from user to spend dethereum tokens.
     *
     * Emits a {DepositCollateral} event.
     */
    function depositCollateral(uint256 _amount) public payable {
        require(_amount > 0, "An amount more than zero must be sent");
        dethereum.transferFrom(msg.sender, address(this), _amount);
        isCollateralDeposited[msg.sender] = true;
        collateralDeposited[msg.sender] += _amount;
        emit DepositCollateral(msg.sender, _amount);
    }

    /**
     * @dev Withdraws Collateral, dethereum, from this smart contract, transferring back to user.
     * This is a public payable function to allow transfer of tokens and prevent Reentrancy attack.
     *
     * Requirements:
     *
     * - msg.sender must be a non-reentrant.
     * - `_amount` can not be zero.
     * - `_amount` must be equal to or less than collateral deposited by the user.
     * - If the sender has collateral deposited (i.e. if true):
     *      - If the sender is a borrower, require the withdraw amount not to exceed minimum loan collateral.
     *      - Else (i.e. sender is not a borrower), withdraw the amount requested.
     * - Else, revert with message `User has nothing to withdraw`.
     *
     * Emit a {WithdrawCollateral} event.
     */
    function withdrawCollateral(uint256 _amount) public payable nonReentrant{
        require(_amount > 0, "Zero amount");
        require(_amount < (collateralDeposited[msg.sender] + 1), "Amount is greater than deposit");
        if (isCollateralDeposited[msg.sender]) {
            if (isBorrower[msg.sender]) {
                totalInterest[msg.sender] += borrowInterest(lastAmountBorrowed[msg.sender], borrowTime[msg.sender]);
                uint256 totalPaybackAmount = borrowAmount[msg.sender] + totalInterest[msg.sender];
                uint256 minCollateral = (totalPaybackAmount * 5)/4;
                uint256 expectedCollatAfterWithdrawal = collateralDeposited[msg.sender] - _amount;
                require(
                    expectedCollatAfterWithdrawal > minCollateral, 
                    'Minimum debt-to-collateral ratio exceeded'
                );
                dethereum.transfer(msg.sender, _amount);
                collateralDeposited[msg.sender] -= _amount;
                emit WithdrawCollateral(msg.sender, _amount);

            } else{
                dethereum.transfer(msg.sender, _amount);
                collateralDeposited[msg.sender] -= _amount;
                emit WithdrawCollateral(msg.sender, _amount);
                if (collateralDeposited[msg.sender] == 0) {
                    isCollateralDeposited[msg.sender] = false;
                }
            }

        } else {
            revert('User has nothing to withdraw!');
        }
    }

    /**
     * @dev Borrows Token, dusd, from this smart contract, and transfers it to user.
     * This is a public payable function to allow borrowing of tokens and prevent Reentrancy attack.
     *
     * Maximum borrow amount is 80% of the user's deposited collateral.
     * Borrower's interest is 2% every 25 hours.
     *
     * Requirements:
     *
     * - msg.sender must be a non-reentrant.
     * - `isCollateralDeposited[msg.sender]` is equal to true, i.e. sender must have collateral deposited.
     * - `_amount` must be greater than zero.
     * - `_amount` must be equal to or less than collateral deposited by the user.
     * - totalAmount of borrowed tokens (previous + current amount) must be equal or less than 80% of value of deposited collateral.
     * - If the borrow amount exceeds maximum borrow limit, a custom `BorrowerError(_amount)` is thrown.
     *
     * When user successfully borrows, a unique borrower NFT is issued to the user using {_borrowerNFTInfo(borrowerId, true)}.
     * If an old borrower NFT exists, it is burned, and a new one is issued to the borrower.
     *
     * Emits a {Borrow} event.
     */
    function borrow(uint256 _amount) public payable nonReentrant{
        require(isCollateralDeposited[msg.sender] == true, "User has to deposit collateral to borrow");
        require(_amount > 0, "An amount more than zero must be sent");
        uint256 totalAmount = borrowAmount[msg.sender] + _amount;
        uint256 maxBorrowAmount = (collateralDeposited[msg.sender]*8)/10;
        uint256 borrowerId = borrowersId[(borrowersId.length - 1)] + 1;
        if (totalAmount == maxBorrowAmount || totalAmount < (maxBorrowAmount + 1)) {
            dusd.transfer(msg.sender, _amount);
            borrowAmount[msg.sender] += _amount;
            if (isBorrower[msg.sender]) {
                _burnBorrowerNFT(msg.sender);
                _borrowerNFTInfo(borrowerId, true);
            } else {
                _borrowerNFTInfo(borrowerId, true);
            }
            isBorrower[msg.sender] = true;
            if (borrowTime[msg.sender] == 0) {
                borrowTime[msg.sender] = block.timestamp;
            }
            totalInterest[msg.sender] += borrowInterest(lastAmountBorrowed[msg.sender], borrowTime[msg.sender]);
            borrowTime[msg.sender] = block.timestamp;
            lastAmountBorrowed[msg.sender] = _amount;
            emit Borrow(msg.sender, _amount, borrowTime[msg.sender]);
        } else {
            revert BorrowerError(_amount);
        }
    }

    /**
     * @dev Pays back all borrowed tokens + interest, in dusd, from the user to this contract.
     * This is a public payable function to allow payback of borrowed tokens.
     *
     * Requirements:
     *
     * - `isBorrower[msg.sender]` is equal to true, i.e. sender must be a borrower.
     * - Approval must be gotten to allow the smart contract spend user's dusd tokens.
     *
     * Borrower's NFT is burnt.
     *
     * Emits a {PaybackAll} event.
     */
    function paybackAll() public payable returns (bool) {
        require(isBorrower[msg.sender] == true, "User has no debt to repay!");
        totalInterest[msg.sender] += borrowInterest(lastAmountBorrowed[msg.sender], borrowTime[msg.sender]);
        uint256 totalPaybackAmount = borrowAmount[msg.sender] + totalInterest[msg.sender];
        dusd.transferFrom(msg.sender, address(this), totalPaybackAmount);
        _burnBorrowerNFT(msg.sender);
        borrowTime[msg.sender] = 0;
        borrowAmount[msg.sender] = 0;
        totalInterest[msg.sender] = 0;
        lastAmountBorrowed[msg.sender] = 0;
        emit PaybackAll(msg.sender, totalPaybackAmount, block.timestamp);
        isBorrower[msg.sender] = false;
        return true;
    }

    /**
     * @dev Lends token, in dusd, from the user to this contract.
     * This is a public payable function to allow lending of dusd tokens which serves as liquidity for borrowers.
     * Lender's interest is 1% every 25 hours.
     * Lender's interest is paid in native DefLend Token (i.e. deftoken).
     *
     * Requirements:
     *
     * - `_amount` must be greater than zero.
     * - Approval must be gotten to allow the smart contract spend user's dusd tokens.
     *
     * When user lends, a unique lender NFT is issued to the user using {_lenderNFTInfo(lenderId, true)}.
     * If an old lender NFT exists, it is burned, and a new one is issued to the lender.
     *
     * Emits a {Lend} event.
     */
    function lend(uint256 _amount) public payable {
        require(_amount > 0, "An amount more than zero must be sent");
        uint256 lenderId = lendersId[(lendersId.length - 1)] + 1;
        dusd.transferFrom(msg.sender, address(this), _amount);
        amountDeposited[msg.sender] += _amount;
        if (deposited[msg.sender]) {
            _burnLenderNFT();
            _lenderNFTInfo(lenderId, true);
        } else {
            _lenderNFTInfo(lenderId, true);
        }
        deposited[msg.sender] = true;
        emit Lend(msg.sender, _amount, block.timestamp);
        lendTime[msg.sender] = block.timestamp;
    }

    /**
     * @dev Withdraws Interest only, deftoken, from this smart contract, transferring back to user.
     * This is a public payable function to allow transfer of token and prevent Reentrancy attack.
     * Lender's interest is paid in native DefLend Token (i.e. deftoken).
     *
     * Requirements:
     *
     * - msg.sender must be a non-reentrant.
     * - user must have lent tokens i.e. `deposited[msg.sender] must be equal to true, else, revert.
     *
     * Emit a {WithdrawLenderInterest} event.
     */
    function withdrawInterest() public payable nonReentrant {
        if(deposited[msg.sender]) {
            uint256 dusdBalOfUser = amountDeposited[msg.sender];
            uint256 timeDifference = block.timestamp - lendTime[msg.sender];
            uint256 interest = ((dusdBalOfUser * timeDifference * lendersRatePerSec)/(10**18));
            deftoken.transfer(msg.sender, interest);
            emit WithdrawLenderInterest(msg.sender, interest, block.timestamp);
            lendTime[msg.sender] = block.timestamp;
        } else {
            revert('User has nothing to withdraw!');
        }
    }

    /**
     * @dev Withdraws user-defined percentage of lent tokens and Interest, from smart contract to the user.
     * This is a public payable function to allow transfer of tokens and prevent Reentrancy attack.
     * Lender's capital is paid in Dusd Token.
     * Lender's interest is paid in native DefLend Token (i.e. deftoken).
     *
     * Requirements:
     *
     * - msg.sender must be a non-reentrant.
     * - `_percentage` can not be over 100%, and must be above 0.
     * - user must have lent tokens i.e. `deposited[msg.sender] must be equal to true, else, revert.
     * - If percentage is equal to 0, transfer dusd and deftokens to user, and burn user's lenderNFT.
     * - Else, transfer only the percentage amount of lent fund (dusd) and the entire Interest accrued so far.
     *
     * Emit a {WithdrawCollateral} event (This event is co-shared by `withdrawCollateral` function above).
     */
    function withdraw(uint256 _percentage) public payable nonReentrant {
        uint72 percent_100 = (100 * (10**18)) + 1;
        require(_percentage > 0 && _percentage < percent_100, "Percentage out of range or zero");
        if(deposited[msg.sender]) {
            uint256 dusdBalOfUser = amountDeposited[msg.sender];
            uint256 timeDifference = block.timestamp - lendTime[msg.sender];
            uint256 interest = ((dusdBalOfUser * timeDifference * lendersRatePerSec)/(10**18));
            uint256 dusdUserBalanceInCon = amountDeposited[msg.sender];
            uint256 lenderId_ = lendersId[(lendersId.length - 1)] + 1;
            if (_percentage == (100*(10**18))) {
                dusd.transfer(msg.sender, dusdUserBalanceInCon);
                deftoken.transfer(msg.sender, interest);
                _burnLenderNFT();
                deposited[msg.sender] = false;
                lendTime[msg.sender] = block.timestamp;
                amountDeposited[msg.sender] = 0;
                emit WithdrawCollateral(msg.sender, dusdUserBalanceInCon);
            } else {
                uint256 amountToBeWithdrawn = ((dusdUserBalanceInCon * _percentage)/(100*(10**18)));
                dusd.transfer(msg.sender, amountToBeWithdrawn);
                deftoken.transfer(msg.sender, interest);
                lendTime[msg.sender] = block.timestamp;
                
                amountDeposited[msg.sender] -= amountToBeWithdrawn;
                _burnLenderNFT();
                _lenderNFTInfo(lenderId_, true);
                emit WithdrawCollateral(msg.sender, amountToBeWithdrawn);
                emit Lend(msg.sender, amountDeposited[msg.sender], block.timestamp);
                
            }
        } else {
            revert('User has nothing to withdraw!');
        }
    }

    /**
     * @dev Liquidates user, transfers remainder collateral (if any) from smart contract to the borrower.
     * Pays the liquidator a small fee to incentivize action.
     * This is a public payable function to liquidate borrower in danger-debt and prevents Reentrancy attack.
     * Minimum Debt-to-Collateral ratio is 90%.
     * Liquidator's fee is 2% of the total value of borrower's collateral deposited.
     * Protocol fee is 1% of the total value of borrower's collateral deposited.
     * Borrower can avoid the liquidator fee by liquidating themselves once debt-collateral ratio is crossed.
     *
     * Requirements:
     *
     * - msg.sender must be a non-reentrant.
     * - The address `_borrower` must not be a zero address i.e. address(0).
     * - The address `_borrower` must be a borrower i.e. `isBorrower[_borrower] must be equal to true, else, revert.
     * - Liquidator can only liquidate a borrower, if borrower's debt-to-collateral ratio is equal or greater than 90% and less than 99%(This is due to interest accruing over time).
     * - If the Liquidator is the borrower, the liquidator's fee is not deducted, and borrower NFT is burned.
     * - Else, the Liquidator receives a fee from the borrower's collateral before liquidation.
     * - If the borrower's debt-to-collateral ratio is equal to or greater than 99%, liquidation is done, but, the liquidator is paid in native deftoken.
     *
     * Emit a {Liquidate} event.
     */
    function liquidate (address _borrower) public nonZeroAddress(_borrower) nonReentrant payable returns(bool) {
        require(isBorrower[_borrower] == true, 'Address is not a borrower');
        totalInterest[_borrower] += borrowInterest(
            lastAmountBorrowed[_borrower], borrowTime[_borrower]
        );
        uint256 totalPaybackAmount = borrowAmount[_borrower] + totalInterest[_borrower];
        uint256 minCollatForLiquidation = (collateralDeposited[_borrower] * 9)/10;
        uint256 liquidatorFee = (collateralDeposited[_borrower] * 2)/100;
        uint256 protocolFee = (collateralDeposited[_borrower] * 1)/100;
        if (
            totalPaybackAmount > minCollatForLiquidation || 
            totalPaybackAmount == minCollatForLiquidation
        ) {
            if (msg.sender != _borrower) {
                collateralDeposited[_borrower] -= liquidatorFee;
                collateralDeposited[_borrower] -= protocolFee;
                collateralDeposited[_borrower] -= totalPaybackAmount;
                dethereum.transfer(msg.sender, liquidatorFee);
                dethereum.transfer(_borrower, collateralDeposited[_borrower]);
                emit Liquidate(msg.sender, _borrower, collateralDeposited[_borrower], block.timestamp);
                _burnBorrowerNFT(_borrower);
                _resetBorrower(_borrower);
            } else {
                collateralDeposited[_borrower] -= protocolFee;
                collateralDeposited[_borrower] -= totalPaybackAmount;
                dethereum.transfer(_borrower, collateralDeposited[_borrower]);
                emit Liquidate(msg.sender, msg.sender, collateralDeposited[_borrower], block.timestamp);
                _burnBorrowerNFT(msg.sender);
                _resetBorrower(msg.sender);
            }
            return true;
        }
        else if (
            totalPaybackAmount > ((collateralDeposited[_borrower]*99)/100) ||
            totalPaybackAmount == ((collateralDeposited[_borrower]*99)/100)
        ) {
            if (msg.sender != _borrower) {
                deftoken.transfer(msg.sender, ((collateralDeposited[_borrower]*5)/1000));
                emit Liquidate(msg.sender, _borrower, collateralDeposited[_borrower], block.timestamp);
                _burnBorrowerNFT(_borrower);
                _resetBorrower(_borrower);
            } else {
                emit Liquidate(msg.sender, _borrower, collateralDeposited[_borrower], block.timestamp);
                _burnBorrowerNFT(msg.sender);
                _resetBorrower(msg.sender);
            }
            return true;
        } else {
            revert('The borrower has not reached liquidation level');
        }
    }
    
    /**
     * @dev resets a borrower to default.
     * Internal function that resets borrower to nil/default.
     *
     */
    function _resetBorrower(address _borrower) internal virtual {
        collateralDeposited[_borrower] = 0;
        isCollateralDeposited[_borrower] = false;
        borrowTime[_borrower] = 0;
        isBorrower[_borrower] = false;
        borrowAmount[_borrower] = 0;
        totalInterest[_borrower] = 0;
        lastAmountBorrowed[_borrower] = 0;
    }
    
    /**
     * @dev Calculates borrower's Interest.
     * Internal function that calculates the borrower's interest given the amount to borrow and time of last borrow.
     * Returns borrower's interest.
     *
     */
    function borrowInterest(uint256 _amount, uint256 _timeBorrow) internal view returns (uint256) {
        uint256 timeDiff = block.timestamp - _timeBorrow;
        uint256 interestBorrower = ((borrowersRatePerSec * _amount * timeDiff)/(10**18));
        return interestBorrower;
    }

    /**
     * @dev Generates bytes data given inputs.
     * Private function that encodes an address _to, _tokenId, _timestamp, and _amount to bytes and stores in memory.
     * Returns data in bytes.
     *
     */
    function generateDataId(
        address _to, uint256 _tokenId, uint256 _timestamp, uint256 _amount
    ) private pure returns(bytes memory) {
        return abi.encode(_to, _tokenId, _timestamp, _amount);
    }
    
    /**
     * @dev Display the NFT data of a given borrower.
     * Public function available to anyone on the blockchain to access any borrower's NFT borrow data in bytes.
     * Returns data in bytes.
     *
     */
    function displayBorrowerData(address _holder) public view returns(bytes memory) {
        return borrowerData[_holder];
    }

    /**
     * @dev Mints a unique borrower ERC-721 token (NFT) that is non-transferrable and saves tokenId.
     * Private function for minting a borrower NFT and storing tokenId in `borrowersId` array.
     * Maps the sender to _isBorrower and stores the borrowerId there for public view.
     *
     */
    function _borrowerNFTInfo(uint256 _borrowerId, bool _isBorrower) private {
        borrowersId.push(_borrowerId);
        bytes memory data_ = bytes(generateDataId(
            msg.sender, _borrowerId, block.timestamp, borrowAmount[msg.sender]
        ));
        defborrowerNFT.mint(msg.sender, _borrowerId, data_);
        borrowerData[msg.sender] = data_;
        getBorrowerId[msg.sender][_isBorrower] = _borrowerId;
    }

    /**
     * @dev Transfers borrower's NFT to address(0).
     * 
     * Requirement:
     * - token `_borrowerId` must be owned by a non-zero address, i.e., it must have been minted before.
     */
    function _burnBorrowerNFT(address _borrower) private {
        uint256 _borrowerId = getBorrowerId[_borrower][true];
        require(defborrowerNFT.ownerOf(_borrowerId) != address(0), 'This token has not been minted');
        defborrowerNFT.burn(_borrowerId);
    }

    /**
     * @dev Display the NFT data of a given lender.
     * Public function available to anyone on the blockchain to access any lender's NFT lend data in bytes.
     * Returns data in bytes.
     *
     */
    function displayLenderData(address _holder) public view returns(bytes memory) {
        return lenderData[_holder];
    }

    /**
     * @dev Mints a unique lender ERC-721 token (NFT) that is non-transferrable and saves tokenId.
     * Private function for minting a lender NFT and storing tokenId in `lendersId` array.
     * Maps the sender to _isLender and stores the lenderId there for public view.
     *
     */
    function _lenderNFTInfo(uint256 _lenderId, bool _isLender) private {
        lendersId.push(_lenderId);
        console.log('Got here');
        console.log('LenderId: %s', _lenderId);
        bytes memory data_ = bytes(generateDataId(
            msg.sender, _lenderId, block.timestamp, amountDeposited[msg.sender]
        ));
        deflenderNFT.mint(msg.sender, _lenderId, data_);
        lenderData[msg.sender] = data_;
        getLenderId[msg.sender][_isLender] = _lenderId;
    }

    /**
     * @dev Transfers lender's NFT to address(0).
     * 
     * Requirement:
     * - token `_lenderId` must be owned by a non-zero address, i.e., it must have been minted before.
     */
    function _burnLenderNFT() private {
        uint256 _lenderId = getLenderId[msg.sender][true];
        require(deflenderNFT.ownerOf(_lenderId) != address(0), 'This token has not been minted');
        deflenderNFT.burn(_lenderId);
    }
}