// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBabyApesRescue.sol";

/// @author Hammad Ghazi
contract BananaBar is ERC20, Ownable {
    IBabyApesRescue public babyApesRescue;

    // The starting block.
    uint256 public rewardGenerationStartTime;

    // Reward for holding the OG on ethereum mainnet.
    uint256 public constant OG_HOLDING_REWARAD = 30 ether;

    // Reward rate and interval.
    uint256 public constant INTERVAL = 86400;
    uint256 public constant RATE = 3 ether;
    uint256 public constant CLONE_RATE = 1.5 ether;

    // Claim steal chance for monsters
    uint256 public constant STEAL_PERCENTAGE = 20;

    // Loss on a trade.
    uint256 public constant TRADE_LOSS = 50;

    // The rewards for the user.
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public cloneRewards;
    mapping(address => uint256) public monsterRewards;

    // The last time they were paid out.
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public lastUpdateClone;

    // Whitelisted addresses that can burn bar
    mapping(address => bool) public allowedAddresses;

    // false = not allow
    // true = allow
    bool public rewardClaimAllow = false;

    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _babyApesRescue) ERC20("Banana Bar", "$BAR") {
        babyApesRescue = IBabyApesRescue(_babyApesRescue);
        allowedAddresses[_babyApesRescue] = true;
    }

    // To set reward generation start block
    function startRewardGeneration() external onlyOwner {
        rewardGenerationStartTime = block.timestamp;
    }

    // Pay out the holder.
    function claimReward() external {
        require(rewardClaimAllow, "Rewards claiming is paused");

        //Prevent rewards claiming until our start is hit.
        require(
            rewardGenerationStartTime != 0,
            "Reward generation is not activated yet"
        );

        // Local copy to save gas
        address caller = msg.sender;

        // Make a local copy of the rewards.
        uint256 _ogRewards = rewards[caller];
        uint256 _cloneRewards = cloneRewards[caller];

        // Get the rewards.
        uint256 pendingOGRewards = getPendingOGReward(caller);
        uint256 pendingCloneRewards = getPendingCloneRewards(caller);

        // Reset the rewards.
        rewards[caller] = 0;
        cloneRewards[caller] = 0;

        // Reset the block.
        lastUpdate[caller] = block.timestamp;
        lastUpdateClone[caller] = block.timestamp;

        // Add up the totals.
        uint256 totalRewardsWithoutMonster = _ogRewards +
            _cloneRewards +
            pendingOGRewards +
            pendingCloneRewards;

        uint256 percent;
        if (totalRewardsWithoutMonster > 0) {
            // How much is one percent worth.
            percent = totalRewardsWithoutMonster / 100;

            // Handle stealing.
            address[] memory monsterOwnersList;

            monsterOwnersList = babyApesRescue.getMonsterOwners();

            // Cut the total amount stolen into shares for each monster.
            uint256 rewardPerMonster = (percent * STEAL_PERCENTAGE) /
                monsterOwnersList.length;

            // Give each Baby Ape Monster a cut into their stolen.
            for (uint256 i = 0; i < monsterOwnersList.length; i++) {
                monsterRewards[monsterOwnersList[i]] += rewardPerMonster;
            }
        }

        // The final result after it was stolen from by those Baby Ape Monsters :(
        uint256 totalRewards = (percent * (100 - STEAL_PERCENTAGE)) +
            monsterRewards[caller];

        // Reset monster rewards.
        monsterRewards[caller] = 0;

        // Mint the user their tokens.
        _mint(caller, totalRewards);

        emit RewardPaid(caller, totalRewards);
    }

    /*
        User Utilities.
    */
    function updateReward(address _from, address _to) external {
        require(
            msg.sender == address(babyApesRescue),
            "Caller is not authorized"
        );

        // Prevent rewards generation until our start is hit.
        if (rewardGenerationStartTime != 0) {
            if (_from != address(0)) {
                rewards[_from] +=
                    (getPendingOGReward(_from) * (100 - TRADE_LOSS)) /
                    100;
                cloneRewards[_from] +=
                    (getPendingCloneRewards(_from) * (100 - TRADE_LOSS)) /
                    100;
                lastUpdate[_from] = block.timestamp;
                lastUpdateClone[_from] = block.timestamp;
            }

            if (_to != address(0)) {
                rewards[_to] += getPendingOGReward(_to);
                cloneRewards[_to] += getPendingCloneRewards(_to);
                lastUpdate[_to] = block.timestamp;
                lastUpdateClone[_to] = block.timestamp;
            }
        }
    }

    function updateRewardOnMint(address _user) external {
        require(
            msg.sender == address(babyApesRescue),
            "Caller is not authorized"
        );

        // Prevent rewards generation until our start is hit.
        if (rewardGenerationStartTime != 0) {
            rewards[_user] += getPendingOGReward(_user);
            cloneRewards[_user] += getPendingCloneRewards(_user);
            lastUpdate[_user] = block.timestamp;
            lastUpdateClone[_user] = block.timestamp;
        }
    }

    function rewardOnMint(address _to) external {
        require(
            msg.sender == address(babyApesRescue),
            "Caller is not authorized"
        );
        _mint(_to, OG_HOLDING_REWARAD);
    }

    function mintBar(address user, uint256 amount) external {
        require(
            allowedAddresses[msg.sender],
            "Address does not have permission to burn"
        );
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        require(
            allowedAddresses[msg.sender],
            "Address does not have permission to burn"
        );
        _burn(user, amount);
    }

    function _tipBabyApeHolder(
        address from,
        address to,
        uint256 amount
    ) external {
        require(
            msg.sender == address(babyApesRescue),
            "Caller is not authorized"
        );
        require(
            allowance(from, msg.sender) >= amount,
            "Insufficient banana bar allowance"
        );
        transferFrom(from, to, amount);
    }

    function setAllowedAddresses(address _address, bool _access)
        public
        onlyOwner
    {
        allowedAddresses[_address] = _access;
    }

    function toggleReward() external onlyOwner {
        rewardClaimAllow = !rewardClaimAllow;
    }

    // Total banana bar user can claim
    function getTotalClaimable(address user) external view returns (uint256) {
        return
            getTotalOGClaimable(user) +
            getTotalCloneClaimable(user) +
            getTotalStolenClaimable(user);
    }

    function getTotalOGClaimable(address user) public view returns (uint256) {
        // Prevent rewards until our start is hit or if claiming is off.
        if (rewardGenerationStartTime == 0 || !rewardClaimAllow) {
            return 0;
        } else {
            return rewards[user] + getPendingOGReward(user);
        }
    }

    function getTotalCloneClaimable(address user)
        public
        view
        returns (uint256)
    {
        if (rewardGenerationStartTime == 0 || !rewardClaimAllow) {
            return 0;
        } else {
            return cloneRewards[user] + getPendingCloneRewards(user);
        }
    }

    function getTotalStolenClaimable(address user)
        public
        view
        returns (uint256)
    {
        if (rewardGenerationStartTime == 0 || !rewardClaimAllow) {
            return 0;
        } else {
            return monsterRewards[user];
        }
    }

    function getPendingOGReward(address user) private view returns (uint256) {
        return
            (babyApesRescue.ogBalance(user) *
                RATE *
                (block.timestamp -
                    (
                        lastUpdate[user] >= rewardGenerationStartTime
                            ? lastUpdate[user]
                            : rewardGenerationStartTime
                    ))) / INTERVAL;
    }

    function getPendingCloneRewards(address user)
        private
        view
        returns (uint256)
    {
        return
            (babyApesRescue.cloneBalance(user) *
                CLONE_RATE *
                (block.timestamp -
                    (
                        lastUpdateClone[user] >= rewardGenerationStartTime
                            ? lastUpdateClone[user]
                            : rewardGenerationStartTime
                    ))) / INTERVAL;
    }
}
