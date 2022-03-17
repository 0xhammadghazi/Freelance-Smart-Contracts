// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/utils/Context.sol

pragma solidity ^0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IKverse {
    function totalSupply() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

pragma solidity 0.8.11;

contract RoyaltyDistribution is Ownable {
    IKverse public Kverse;
    bool public canClaimRoyalty = true;

    // Tracks royalty of the address
    mapping(address => uint256) public royaltyCollected;

    constructor(IKverse _address) {
        Kverse = _address;
    }

    receive() external payable {
        revert();
    }

    function flipClaimRoyaltyStatus() external onlyOwner {
        canClaimRoyalty = !canClaimRoyalty;
    }

    function distributeRoyalty() external payable onlyOwner {
        require(msg.value > 7777, "Insufficient BNB sent");
        uint256 shareAmount = msg.value / Kverse.totalSupply();

        for (uint256 i = 1; i <= Kverse.totalSupply(); i++) {
            royaltyCollected[Kverse.ownerOf(i)] += shareAmount;
        }
    }

    function claimRoyalty() external {
        require(canClaimRoyalty, "Royalty claiming is paused");
        require(royaltyCollected[msg.sender] > 0, "No royalty amount to claim");
        uint256 royaltyAmount = royaltyCollected[msg.sender];
        royaltyCollected[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: royaltyAmount}("");
        require(success, "Transfer failed.");
    }

    function emergencyWithdraw() external onlyOwner {
        for (uint256 i = 1; i <= Kverse.totalSupply(); i++) {
            royaltyCollected[Kverse.ownerOf(i)] = 0;
        }

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed.");
    }
}