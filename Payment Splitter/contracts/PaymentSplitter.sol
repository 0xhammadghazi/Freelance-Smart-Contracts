//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";

/// @title A Gas Efficient 2 Wallets Payment Splitter
/// @author Rtility (https://github.com/Rtility/)
contract PaymentSplitter is ReentrancyGuard {
    event Received(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);
    event WithdrawERC20(IERC20 indexed token, address to, uint256 amount);

    error PaymentFailed();
    error WrongShares();
    error WrongAddress();
    error NoBalance();
    error NotValidSender();

    // compiler will packed them
    struct Addresses {
        address addr1;
        address addr2;
    }

    Addresses public addrs;

    uint256 public immutable share1;
    uint256 public immutable share2;

    /**
     * @dev Initializes the contract by setting addresses and shares.
     * @dev Shares must be based on percentages (0-100)
     *
     * Requires:
     * - `addr1_` and `addr2_` not be zero address
     * - `share1_` and `share2_` must be greater than zero
     * - `share1_` + `share2_` must be 100
     *
     * @param addr1_ The address of the first wallet.
     * @param addr2_ The address of the second wallet.
     * @param share1_ The share of the first wallet.
     * @param share2_ The share of the second wallet.
     */
    constructor(
        address addr1_,
        address addr2_,
        uint256 share1_,
        uint256 share2_
    ) {
        if (addr1_ == address(0) || addr2_ == address(0)) revert WrongAddress();
        if (share1_ + share2_ != 100) revert WrongShares();
        if (share1_ == 0 || share2_ == 0) revert WrongShares();

        addrs.addr1 = addr1_;
        addrs.addr2 = addr2_;
        share1 = share1_;
        share2 = share2_;
    }

    /**
     * @dev The Ether received will be logged with {Received} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev Triggers Ether transfer from contract to both wallets, according to their percentage of the
     * total shares.
     *
     * Requires:
     * - balance of the contract must be greater than zero
     */
    function withdraw() external nonReentrant {
        uint256 balance = address(this).balance;

        if (balance == 0) revert NoBalance();

        address addr1 = addrs.addr1;
        address addr2 = addrs.addr2;

        uint256 addr1Amount = (balance * share1) / 100;
        uint256 addr2Amount = (balance * share2) / 100;

        (bool success1, ) = addr1.call{value: addr1Amount}("");
        (bool success2, ) = addr2.call{value: addr2Amount}("");

        if (!success1 || !success2) revert PaymentFailed();

        emit Withdraw(addr1, addr1Amount);
        emit Withdraw(addr2, addr2Amount);
    }

    /**
     * @dev Triggers a transfer to both wallets of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares. `token` must be the address of an IERC20 contract.
     *
     * Requires:
     * - `token` must be an IERC20 contract.
     * - balance of the contract must be greater than zero
     *
     * @param token The address of the ERC20 contract.
     */
    function withdrawERC20(IERC20 token) external nonReentrant {
        uint256 balance = token.balanceOf(address(this));

        if (balance == 0) revert NoBalance();

        address addr1 = addrs.addr1;
        address addr2 = addrs.addr2;

        uint256 addr1Amount = (balance * share1) / 100;
        uint256 addr2Amount = (balance * share2) / 100;

        SafeERC20.safeTransfer(token, addr1, addr1Amount);
        SafeERC20.safeTransfer(token, addr2, addr2Amount);

        emit WithdrawERC20(token, addr1, addr1Amount);
        emit WithdrawERC20(token, addr2, addr2Amount);
    }

    /**
     * @dev Change the first wallet address.
     *
     * Requires:
     * - `newAddr_` not be zero address
     * - `msg.sender` must be the old address
     *
     * @param newAddr_ The new address of the wallet.
     */
    function changeAddr1(address newAddr_) external {
        if (newAddr_ == address(0)) revert WrongAddress();
        if (msg.sender != addrs.addr1) revert NotValidSender();

        addrs.addr1 = newAddr_;
    }

    /**
     * @dev Change the second wallet address.
     *
     * Requires:
     * - `newAddr_` not be zero address
     * - `msg.sender` must be the old address
     *
     * @param newAddr_ The new address of the wallet.
     */
    function changeAddr2(address newAddr_) external {
        if (newAddr_ == address(0)) revert WrongAddress();
        if (msg.sender != addrs.addr2) revert NotValidSender();

        addrs.addr2 = newAddr_;
    }
}
