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
    event Received(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);

    error NoBalance();
    error PaymentFailed();
    error ZeroAddress();

    /**
     * @dev Constructor function.
     * @param owner_ address of the owner of the contract.
     *
     * Requires:
     * - owner_ should not be a null address.
     */
    constructor() {
        owner = owner_;
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
    function withdraw(address recipient) external {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;

        if (balance == 0) revert NoBalance();

        (bool success1, ) = recipient.call{value: balance}("");

        if (!success1) revert PaymentFailed();

        emit Withdraw(recipient, balance);
    }
}
