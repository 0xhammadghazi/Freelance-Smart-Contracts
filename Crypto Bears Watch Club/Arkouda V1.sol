// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICryptoBearWatchClub {
    function walletOfOwner(address _owner)
        external
        view
        returns (uint256[] memory);
}

/// @author Hammad Ghazi
contract Arkouda is ERC20, Ownable {
    ICryptoBearWatchClub public CryptoBearWatchClub;

    uint256 public constant BASE_REWARD = 10000000000000000000; //10 Arkouda
    uint256 public rewardGenerationStartTime;
    bool canClaimArkouda = false;

    mapping(address => uint256) public rewards; //to store user unclaimed rewards
    mapping(address => mapping(uint256 => uint256)) public lastUpdate;
    mapping(address => bool) public allowedAddresses; //to store addresses that can burn Arkouda

    //To store Arkouda, certain CBWC NFT  will generate after every 30 days.
    //0 means that it will generate base reward.
    mapping(uint256 => uint256) public tokenIdReward;

    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _cryptoBearWatchClub) ERC20("Arkouda", "$ark") {
        CryptoBearWatchClub = ICryptoBearWatchClub(_cryptoBearWatchClub);
    }

    // Admin only functions

    /** 
        Switch to allow or prevent claiming of Arkouda rewards.
        False = Arkouda claiming is not allowed.
        True = Arkouda claiming is allowed.
    */
    function flipArkoudaClaimStatus() external onlyOwner {
        canClaimArkouda = !canClaimArkouda;
    }

    // To set reward generation start block
    function startRewardGeneration() external onlyOwner {
        rewardGenerationStartTime = block.timestamp;
    }

    // To specify how many Arkouda a CBWC Nft will generate after 30 days
    // Sets reward in batches
    function setTokenIdReward(
        uint256[] calldata tokenIds,
        uint256 _tokenIdReward
    ) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenIdReward[tokenIds[i]] = _tokenIdReward;
        }
    }

    // To grant/revoke burn access
    function setAllowedAddresses(address _address, bool _access)
        external
        onlyOwner
    {
        allowedAddresses[_address] = _access;
    }

    // Reward related functions

    function updateReward(
        address from,
        address to,
        uint256 tokenId
    ) external {
        require(
            msg.sender == address(CryptoBearWatchClub),
            "Only CBWC is authorized"
        );

        // Prevent rewards generation until our start is hit.
        if (rewardGenerationStartTime != 0) {
            if (from != address(0)) {
                // Accumulate user rewards in previous rewards if he has held for 30 days or more
                rewards[from] += getPendingReward(from, tokenId);
            }
            if (to != address(0)) {
                // Update when the user has received a particular CBWC
                lastUpdate[to][tokenId] = block.timestamp;
            }
        }
    }

    // Pay out the holder their rewards
    function claimReward() external {
        require(canClaimArkouda, "Arkouda reward claiming is turned off");

        //Prevent rewards claiming until our start is hit.
        require(
            rewardGenerationStartTime != 0,
            "Reward generation is not activated yet"
        );

        // Make a local copy of the rewards.
        uint256 _rewards = rewards[msg.sender];

        // Gets the list of CBWC token Ids user currently holds
        uint256[] memory tokenIds = CryptoBearWatchClub.walletOfOwner(
            msg.sender
        );

        // To store pending reward of a specific CBWC Nft
        uint256 pendingTokenIdReward;

        // To store accumulated pending rewards + any previous rewards
        uint256 totalRewards;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Calculates if the user has any pending reward of any token Id
            pendingTokenIdReward = getPendingReward(msg.sender, tokenIds[i]);

            // Reset block of the CBWC Nft if it has generated some Arkouda
            if (pendingTokenIdReward > 0) {
                lastUpdate[msg.sender][tokenIds[i]] = block.timestamp;
            }
            totalRewards += pendingTokenIdReward;
        }

        // reset user rewards
        rewards[msg.sender] = 0;

        // Accumulates pending reward of all token Ids user currently holds,
        // with the rewards of previous token Ids user has held
        totalRewards += _rewards;

        // mint the user their tokens
        if (totalRewards > 0) {
            _mint(msg.sender, totalRewards);
        }

        emit RewardPaid(msg.sender, totalRewards);
    }

    // To get total Arkouda user can claim
    function getTotalClaimable(address user) external view returns (uint256) {
        // Prevent rewards until our start is hit.
        if (rewardGenerationStartTime == 0) {
            return 0;
        } else {
            uint256 totalClaimableReward;

            // Gets the list of CBWC token Ids user currently holds
            uint256[] memory tokenIds = CryptoBearWatchClub.walletOfOwner(user);

            // Calculates if the user has any pending reward of any token Id
            for (uint256 i = 0; i < tokenIds.length; i++) {
                totalClaimableReward += getPendingReward(user, tokenIds[i]);
            }

            // Accumulates pending reward of all token Ids user currently holds,
            // with the rewards of previous token Ids user has held
            totalClaimableReward += rewards[user];
            return totalClaimableReward;
        }
    }

    function getPendingReward(address user, uint256 tokenId)
        private
        view
        returns (uint256)
    {
        uint256 daysHeld = (block.timestamp -
            (
                lastUpdate[user][tokenId] >= rewardGenerationStartTime
                    ? lastUpdate[user][tokenId]
                    : rewardGenerationStartTime
            )) / 86400;
        uint256 multiplier = daysHeld / 30;
        return
            (
                tokenIdReward[tokenId] == 0
                    ? BASE_REWARD
                    : tokenIdReward[tokenId]
            ) * multiplier;
    }

    function burn(address from, uint256 amount) external {
        require(
            allowedAddresses[msg.sender],
            "Address does not have permission to burn"
        );
        _burn(from, amount);
    }
}
