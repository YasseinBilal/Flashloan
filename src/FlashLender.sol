// SPDX-License-Identifier: MIT
pragma solidity =0.8.27;

import "./interfaces/IERC3156FlashLender.sol";
import "./interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FlashLender is IERC3156FlashLender, ReentrancyGuard {
    bytes32 public constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(address => bool) public supportedTokens;

    uint public immutable fee;

    constructor(address[] memory supportedTokens_, uint fee_) {
        for (uint i = 0; i < supportedTokens_.length; i++) {
            supportedTokens[supportedTokens_[i]] = true;
        }

        fee = fee_;
    }

    function flashloan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        require(supportedTokens[token], "FlashLender: unsupported token");

        uint256 _fee = flashFee(token, amount);

        require(
            IERC20(token).transfer(address(receiver), amount),
            "FlashLender: Transfer failed"
        );

        require(
            receiver.onFlashLoan(msg.sender, token, amount, _fee, data) ==
                CALLBACK_SUCCESS,
            "FlashLender: Callback failed"
        );

        require(
            IERC20(token).transferFrom(
                address(receiver),
                address(this),
                amount + _fee
            ),
            "FlashLender: Repay failed"
        );

        return true;
    }

    function flashFee(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        // could have diff fee for diff tokens but currently all tokens have same fee
        return (amount * fee) / 1e18;
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        return
            supportedTokens[token] ? IERC20(token).balanceOf(address(this)) : 0;
    }
}
