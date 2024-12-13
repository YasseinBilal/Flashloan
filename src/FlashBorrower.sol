// SPDX-License-Identifier: MIT
pragma solidity =0.8.27;

import "./interfaces/IERC3156FlashLender.sol";
import "./interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashBorrower is IERC3156FlashBorrower, ReentrancyGuard, Ownable {
    bytes32 public constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC3156FlashLender lender;

    constructor(IERC3156FlashLender lender_) Ownable(msg.sender) {
        lender = lender_;
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: External loan initiator"
        );

        address borrower = abi.decode(data, (address));
        // Do something with loan here

        return CALLBACK_SUCCESS;
    }

    function flashBorrow(
        address token,
        uint256 amount
    ) public nonReentrant onlyOwner {
        approveRepayment(token, amount);
        lender.flashloan(this, token, amount, abi.encode(msg.sender));
    }

    function approveRepayment(address token, uint256 amount) public {
        uint256 _allowance = IERC20(token).allowance(
            address(this),
            address(lender)
        );
        uint256 _fee = lender.flashFee(token, amount);
        uint256 _repayment = amount + _fee;
        IERC20(token).approve(address(lender), _allowance + _repayment);
    }
}
