// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

pragma solidity ^0.8.0;

/**
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

contract Staking is Ownable {
    IBEP20 token;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) lastClaim;
    mapping(address => uint256) userRewardClaimed;
    uint256 public totalPoolRewardPaid;
    uint256 public totalStakedAmount;
    uint256 remainingStakedAmount;
    uint256 lastChecked;
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    event Stake(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Withdraw(uint256 amount);
    event Claim(address indexed user, uint256 amount);

    constructor(address _token) {
        token = IBEP20(_token);
    }

    receive() external payable {}

    function currentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function userNGTBalance(address _addr) external view returns (uint256) {
        return token.balanceOf(_addr);
    }

    function rewardClaimed(address _user) external view returns (uint256) {
        return userRewardClaimed[_user];
    }

    function userStakedBalance(address _user) external view returns (uint256) {
        return stakedBalance[_user];
    }

    function widthdrawAll() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0");
        //require(getDayOfWeek(block.timestamp)==1,"Can only stake on Monday");
        address user = msg.sender;
        require(
            token.allowance(user, address(this)) >= _amount,
            "Insufficent allowance"
        );
        stakedBalance[user] += _amount;
        totalStakedAmount += _amount;
        remainingStakedAmount = totalStakedAmount;
        token.transferFrom(user, address(this), _amount);
        emit Stake(user, _amount);
    }

    function unstake() external {
        address user = msg.sender;
        uint256 _stakedBalance = stakedBalance[user];
        require(_stakedBalance > 0, "Account does not have a balance staked");
        stakedBalance[user] = 0;
        totalStakedAmount -= _stakedBalance;
        remainingStakedAmount = totalStakedAmount;
        token.transfer(user, _stakedBalance);
        emit Unstaked(user, _stakedBalance);
    }

    function claimReward() external {
        remainingStakedAmount = totalStakedAmount;
        address user = msg.sender;
        require(
            stakedBalance[user] > 0,
            "Account does not have a balance staked"
        );
        //require(getDayOfWeek(block.timestamp)==7,"Reward can only be claimed on Sunday");
        if (block.timestamp >= lastChecked + 5 days) {
            lastChecked = block.timestamp;
            remainingStakedAmount = totalStakedAmount;
        }
        require(getPoolReward() > 0, "Contract doesn't have BNB to reward");
        require(
            block.timestamp >= lastClaim[user] + 5 days,
            "You have already claimed your reward of this week!"
        );
        require(remainingStakedAmount > 0, "Insufficent staked tokens");
        uint256 userReward = unclaimedReward(user);
        require(userReward > 0, "No reward");
        remainingStakedAmount -= stakedBalance[user];
        lastClaim[user] = block.timestamp;
        userRewardClaimed[user] += userReward;
        totalPoolRewardPaid += userReward;
        (bool success, ) = user.call{value: userReward}("");
        require(success, "Transfer failed.");
        emit Claim(user, userReward);
    }

    function unclaimedReward(address _addr) public view returns (uint256) {
        if (remainingStakedAmount > 0) {
            return
                (getPoolReward() * stakedBalance[_addr]) /
                remainingStakedAmount;
        } else return 0;
    }

    // 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint256 timestamp)
        public
        pure
        returns (uint256 dayOfWeek)
    {
        uint256 _days = timestamp / SECONDS_PER_DAY;
        dayOfWeek = ((_days + 3) % 7) + 1;
    }

    function getPoolReward() public view returns (uint256) {
        return address(this).balance;
    }
}
