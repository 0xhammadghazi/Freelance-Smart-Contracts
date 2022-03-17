// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/ICryptoBearWatchClub.sol";

contract Arkouda is ERC20, Ownable, IERC721Receiver {
    ICryptoBearWatchClub public CryptoBearWatchClub;

    enum TX_TYPE {
        UNSTAKE,
        CLAIM
    }

    bool public stakingLive;

    uint256 public constant tier1Reward = 30 ether;
    uint256 public constant tier2Reward = 9 ether;
    uint256 public constant tier3Reward = 3 ether;

    // Stores tier of a CBWC NFT.
    // 0 represents tier 3
    mapping(uint256 => uint256) public tokenIdTier;

    // Stores token id staker address
    mapping(uint256 => address) public tokenOwner;

    // To store when was the last time user staked or claimed the reward of the token Id
    mapping(address => mapping(uint256 => uint256)) public lastUpdate;

    // To store addresses that can burn their Arkouda token
    mapping(address => bool) public allowedAddresses;

    event Staked(address indexed staker, uint256[] tokenIds, uint256 stakeTime);
    event Unstaked(address indexed unstaker, uint256[] tokenIds);
    event RewardsPaid(
        address indexed claimer,
        uint256[] tokenIds,
        uint256 _tier1Rewards,
        uint256 _tier2Rewards,
        uint256 _tier3Rewards
    );

    constructor(ICryptoBearWatchClub _cryptoBearWatchClub)
        ERC20("Arkouda", "$ark")
    {
        CryptoBearWatchClub = _cryptoBearWatchClub;
    }

    modifier isTokenOwner(uint256[] memory _tokenIds) {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                tokenOwner[_tokenIds[i]] == _msgSender(),
                "CALLER_IS_NOT_STAKER"
            );
        }
        _;
    }

    modifier isStakingLive() {
        require(stakingLive, "STAKING_IS_NOT_LIVE_YET");
        _;
    }

    modifier checkInputLength(uint256[] memory _tokenIds) {
        require(_tokenIds.length > 0, "INVALID_INPUT_LENGTH");
        _;
    }

    // To start staking/ reward generation
    function startStaking() external onlyOwner {
        require(!stakingLive, "STAKING_IS_ALREADY_LIVE");
        stakingLive = true;
    }

    // To grant/revoke burn access
    function setAllowedAddresses(address _address, bool _access)
        external
        onlyOwner
    {
        allowedAddresses[_address] = _access;
    }

    // Sets the tier of CBWC NFTs
    function setCBWCNFTTier(uint256[] calldata _tokenIds, uint256 _tier)
        external
        onlyOwner
    {
        require(_tier == 1 || _tier == 2, "INVALID_TIER");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(tokenIdTier[_tokenIds[i]] == 0, "TIER_ALREADY_SET");
            tokenIdTier[_tokenIds[i]] = _tier;
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function burn(uint256 amount) external {
        require(
            allowedAddresses[_msgSender()],
            "ADDRESS_DOES_NOT_HAVE_PERMISSION_TO_BURN"
        );
        _burn(_msgSender(), amount);
    }

    // Stakes CBWC NFTs
    function stakeCBWC(uint256[] calldata _tokenIds)
        external
        isStakingLive
        checkInputLength(_tokenIds)
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                CryptoBearWatchClub.ownerOf(_tokenIds[i]) == _msgSender(),
                "CBWC_NFT_IS_NOT_YOURS"
            );

            // Transferring NFT from staker to the contract
            CryptoBearWatchClub.safeTransferFrom(
                _msgSender(),
                address(this),
                _tokenIds[i]
            );

            // Keeping track of token id staker address
            tokenOwner[_tokenIds[i]] = _msgSender();

            lastUpdate[_msgSender()][_tokenIds[i]] = block.timestamp;
        }

        emit Staked(_msgSender(), _tokenIds, block.timestamp);
    }

    // Unstakes CBWC NFTs
    function unStakeCBWC(uint256[] calldata _tokenIds)
        external
        isStakingLive
        isTokenOwner(_tokenIds)
        checkInputLength(_tokenIds)
    {
        claimOrUnstake(_tokenIds, TX_TYPE.UNSTAKE);
        emit Unstaked(_msgSender(), _tokenIds);
    }

    // To claim reward for staking CBWC NFTs
    function claimRewards(uint256[] calldata _tokenIds)
        external
        isStakingLive
        isTokenOwner(_tokenIds)
        checkInputLength(_tokenIds)
    {
        claimOrUnstake(_tokenIds, TX_TYPE.CLAIM);
    }

    function claimOrUnstake(uint256[] memory _tokenIds, TX_TYPE txType)
        private
    {
        uint256 rewards;
        uint256 _tier1Rewards;
        uint256 _tier2Rewards;
        uint256 _tier3Rewards;
        uint256 tier;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            (rewards, tier) = getPendingRewardAndTier(_tokenIds[i]);
            if (tier == 1) {
                _tier1Rewards += rewards;
            } else if (tier == 2) {
                _tier2Rewards += rewards;
            } else {
                _tier3Rewards += rewards;
            }

            if (txType == TX_TYPE.UNSTAKE) {
                // Transferring NFT back to the staker
                CryptoBearWatchClub.safeTransferFrom(
                    address(this),
                    _msgSender(),
                    _tokenIds[i]
                );

                // Resetting token id staker address
                tokenOwner[_tokenIds[i]] = address(0);

                // Resetting last update timer of token id
                // Resetting it so that 'getPendingReward' function returns 0 if you check pending reward of unstaked NFT
                lastUpdate[_msgSender()][_tokenIds[i]] = 0;
            } else {
                // Updating last claim time
                lastUpdate[_msgSender()][_tokenIds[i]] = block.timestamp;
            }
        }
        _mint(_msgSender(), (_tier1Rewards + _tier2Rewards + _tier3Rewards));
        emit RewardsPaid(
            _msgSender(),
            _tokenIds,
            _tier1Rewards,
            _tier2Rewards,
            _tier3Rewards
        );
    }

    // Returns total pending rewards of all input token ids
    function getTotalClaimable(uint256[] memory _tokenIds)
        external
        view
        returns (uint256 totalRewards)
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            totalRewards += getPendingReward(_tokenIds[i]);
        }
    }

    // Returns pending accumulated reward of the token id
    function getPendingReward(uint256 _tokenId)
        public
        view
        returns (uint256 reward)
    {
        if (lastUpdate[_msgSender()][_tokenId] == 0) {
            return 0;
        }
        (reward, ) = getPendingRewardAndTier(_tokenId);
    }

    // Returns pending accumulated reward of the token id along with token id tier
    function getPendingRewardAndTier(uint256 _tokenId)
        private
        view
        returns (uint256 rewards, uint256 tier)
    {
        uint256 secondsHeld = block.timestamp -
            lastUpdate[_msgSender()][_tokenId];

        if (tokenIdTier[_tokenId] == 1) {
            return (((tier1Reward * secondsHeld) / 86400), 1);
        } else if (tokenIdTier[_tokenId] == 2) {
            return (((tier2Reward * secondsHeld) / 86400), 2);
        } else {
            return (((tier3Reward * secondsHeld) / 86400), 3);
        }
    }
}
