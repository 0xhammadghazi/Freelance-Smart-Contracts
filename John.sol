// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title Contract for receiving ether
contract John {
    event Received(address from, uint256 amount);

    /// @dev The Ether received will be logged with {Received} events.
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
