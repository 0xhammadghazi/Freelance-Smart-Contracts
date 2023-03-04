// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

pragma solidity 0.8.15;

/// @title Contract for receiving ether
contract John is Owned {
    // Events
    event Received(address indexed from, uint256 indexed amount);
    event Withdraw(address indexed to, uint256 indexed amount);

    // Custom Errors
    error NoBalance();
    error PaymentFailed();
    error ZeroAddress();

    /**
     * @dev Constructor function.
     * @param owner_ address of the smart contract owner.
     *
     * Requires:
     * - owner_ should not be a null address.
     */
    constructor(address owner_) Owned(owner_){
           if (owner_ == address(0)) revert ZeroAddress();
    }

    /// @dev The Ether received will be logged with {Received} events.
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev Triggers Ether transfer from contract to recipient wallet.
     * @param recipient address of the recipient.
     *
     * Requires:
     * - balance of the contract must be greater than zero.
     * - recipient should not be a null address.
     */
    function withdraw(address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;

        if (balance == 0) revert NoBalance();

        (bool success, ) = recipient.call{value: balance}("");

        if (!success) revert PaymentFailed();

        emit Withdraw(recipient, balance);
    }
}
