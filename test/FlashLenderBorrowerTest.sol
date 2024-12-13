// SPDX-License-Identifier: MIT
pragma solidity =0.8.27;

import "forge-std/Test.sol";
import "../src/FlashLender.sol";
import "../src/FlashBorrower.sol";
import "../src/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FlashLoanToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract FlashLenderBorrowerTest is Test {
    FlashLender lender;
    FlashBorrower borrower;
    FlashLoanToken token;

    address deployer = address(0x123);
    address user = address(0x456);
    uint256 initialSupply = 1_000_000 ether;
    uint256 loanAmount = 10_000 ether;
    uint256 feeRate = 1e16; // 0.01%

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy the ERC20 token and provide initial supply to the deployer
        token = new FlashLoanToken("FlashToken", "FLT", initialSupply);

        // Deploy the FlashLender contract
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(token);
        lender = new FlashLender(supportedTokens, feeRate);

        // Transfer some tokens to the lender contract
        token.transfer(address(lender), initialSupply / 2);

        // Deploy the FlashBorrower contract
        borrower = new FlashBorrower(IERC3156FlashLender(address(lender)));

        // Transfer token fee to borrower
        token.transfer(address(borrower), 100 ether);

        vm.stopPrank();
    }

    function testFlashLoanSuccess() public {
        vm.startPrank(deployer);

        // Ensure lender has enough tokens for the loan
        uint256 lenderInitialBalance = token.balanceOf(address(lender));
        uint256 borrowerInitialBalance = token.balanceOf(address(borrower));

        assertEq(
            lenderInitialBalance,
            initialSupply / 2,
            "Lender does not have enough tokens"
        );

        // Calculate repayment amount
        uint256 expectedFee = lender.flashFee(address(token), loanAmount);
        uint256 repaymentAmount = loanAmount + expectedFee;

        // Transfer tokens to the user for repayment
        token.transfer(user, repaymentAmount);

        // Perform the flash loan
        borrower.flashBorrow(address(token), loanAmount);

        // Verify lender has been repaid with the fee
        uint256 expectedLenderBalance = lenderInitialBalance + expectedFee;
        assertEq(
            token.balanceOf(address(lender)),
            expectedLenderBalance,
            "Lender balance mismatch after repayment"
        );

        // Verify borrower does not retain the loan amount
        uint256 borrowerBalance = token.balanceOf(address(borrower));
        assertEq(
            borrowerBalance,
            borrowerInitialBalance - expectedFee,
            "Borrower should not retain loan tokens"
        );

        vm.stopPrank();
    }

    function testFlashLoanUnsupportedToken() public {
        vm.startPrank(user);

        // Attempt to borrow with an unsupported token
        vm.expectRevert();
        borrower.flashBorrow(address(0xdead), loanAmount);

        vm.stopPrank();
    }

    function testFlashLoanFeeCalculation() public view {
        uint256 calculatedFee = lender.flashFee(address(token), loanAmount);
        uint256 expectedFee = (loanAmount * feeRate) / 1e18;
        assertEq(calculatedFee, expectedFee, "Fee calculation mismatch");
    }

    function testMaxFlashLoan() public view {
        uint256 maxLoan = lender.maxFlashLoan(address(token));
        uint256 lenderBalance = token.balanceOf(address(lender));
        assertEq(maxLoan, lenderBalance, "Max flash loan amount mismatch");
    }
}
