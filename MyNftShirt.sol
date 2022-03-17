// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

///@author Hammad Ghazi
contract MyNftShirt {

    address public owner;

    event ShirtPurchased(
        address indexed buyer,
        uint256 indexed orderId,
        uint256 indexed amount
    );

    constructor() {
        owner = msg.sender;
    }

    function buy(uint256 _orderId) external payable {
        emit ShirtPurchased(msg.sender, _orderId, msg.value);
    }

    function getBalance() external view returns(uint256){
        return address(this).balance;
    }

    function withdrawETH() external {
        require(msg.sender == owner, "Caller not owner");
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed.");
    }
}
