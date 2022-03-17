// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

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
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
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
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function minterOf(uint256 tokenId) external view returns (address);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external payable;
}

contract MarketV2 is Ownable {
    struct Listing {
        address owner;
        uint256 price;
        uint256 lastSold;
        uint245 listedAt;
    }
    
    address public nftAddress;
    IERC721 NFT;

    bool public marketActive;
    bool public emergency;
    uint256 public marketplaceVolume;
    uint256 public minterFee;
    uint256 public stakingFee;
    address public stakingAddress;
    uint256 public treasuryFee;
    address public treasuryAddress;
    
    mapping (uint256 => Listing) public Marketplace;
    mapping (address => uint256[]) public ownerTokens;
    
    event BoughtListing(uint256 tokenId, uint256 value);
    event SetListing(uint256 id, uint256 price);
    event CanceledListing(uint256 tokenId);
    
    constructor(
        address _nftAddress,
        address _stakingAddress,
        address _treasuryAddress,
        uint256 _minterFee,
        uint256 _stakingFee,
        uint256 _treasuryFee
    ) {
        nftAddress = _nftAddress;
        NFT = IERC721(nftAddress);

        stakingAddress = _stakingAddress;
        treasuryAddress = _treasuryAddress;
        minterFee = _minterFee;
        stakingFee = _stakingFee;
        treasuryFee = _treasuryFee;
        marketActive = true;
    }

    function setAddresses(address newStakingAddress, address newTreasuryAddress) external onlyOwner {
        stakingAddress = newStakingAddress;
        treasuryAddress = newTreasuryAddress;
    }

    function setEmergency(bool newEmergency) external onlyOwner {
        emergency = newEmergency;
    }

    function setFees(uint256 newMinterFee, uint256 newStakingFee, uint256 newTreasuryFee) external onlyOwner {
        require(newMinterFee >= 0, "newMinterFee must be >= 0");
        require(newStakingFee >= 0, "newStakingFee must be >= 0");
        require(newTreasuryFee >= 0, "newTreasuryFee must be >= 0");
        require(newMinterFee + newStakingFee + newTreasuryFee < 100, "Total percents must be < 100");

        minterFee = newMinterFee;
        stakingFee = newStakingFee;
        treasuryFee = newTreasuryFee;
    }

    function setMarketActive(bool newMarketActive) external onlyOwner {
        marketActive = newMarketActive;
    }
    
    // MARKET
    function buyListing(uint256 tokenId, uint256 listingIndex) external payable {
        require(marketActive, "Market inactive");
        require(msg.value == Marketplace[tokenId].price, "Incorrect amount");

        uint256 stakingShare = royaltyOf(msg.value, stakingFee);
        uint256 minterShare = royaltyOf(msg.value, minterFee);
        uint256 treasuryShare = royaltyOf(msg.value, treasuryFee);
        uint256 afterFees = msg.value - stakingShare - minterShare - treasuryShare;

        address minter = NFT.minterOf(tokenId);
        address staking = stakingAddress;
        address seller = Marketplace[tokenId].owner;

        uint256 lastIndex = ownerTokens[seller].length - 1;
        ownerTokens[seller][listingIndex] = ownerTokens[seller][lastIndex];
        ownerTokens[seller].pop();

        // CANCEL LISTING
        delete Marketplace[tokenId].owner;
        delete Marketplace[tokenId].price;
        Marketplace[tokenId].lastSold = msg.value;
        marketplaceVolume += msg.value;

        NFT.transferFrom(address(this), _msgSender(), tokenId);

        (bool transferMinter,) = minter.call{ value: minterShare }("");
        require(transferMinter, "transferMinter failed");
        
        (bool transferStaking,) = staking.call{ value: stakingShare }("");
        require(transferStaking, "transferStaking failed");

        (bool transferSeller,) = seller.call{ value: afterFees }("");
        require(transferSeller, "transferSeller failed");

        emit BoughtListing(tokenId, msg.value);
    }

    function cancelListing(uint256 tokenId, uint256 listingIndex) external {
        require(_msgSender() == Marketplace[tokenId].owner, "Not token owner");
        require(ownerTokens[_msgSender()][listingIndex] == tokenId, "Invalid listingIndex");

        uint256 lastIndex = ownerTokens[_msgSender()].length - 1;
        ownerTokens[_msgSender()][listingIndex] = ownerTokens[_msgSender()][lastIndex];
        ownerTokens[_msgSender()].pop();

        delete Marketplace[tokenId].owner;
        delete Marketplace[tokenId].price;

        NFT.transferFrom(address(this), _msgSender(), tokenId);
        
        emit CanceledListing(tokenId);
    }

    function emergencyCancelListing(uint256 tokenId) external {
        require(emergency, "Not emergency");

        NFT.transferFrom(address(this), Marketplace[tokenId].owner, tokenId);
    }

    function setListing(uint256 tokenId, uint256 price) external {
        require(marketActive, "Market inactive");
        require(price > 0, "Price required");

        if (NFT.ownerOf(tokenId) == _msgSender()) {
            NFT.transferFrom(_msgSender(), address(this), tokenId);
            Marketplace[tokenId].owner = _msgSender();
            ownerTokens[_msgSender()].push(tokenId);
        } else {
            require(_msgSender() == Marketplace[tokenId].owner, "Not token owner");
        }
        
        Marketplace[tokenId].price = price;
        Marketplace[tokenId].listedAt = block.timestamp;

        emit SetListing(tokenId, price);
    }

    function getListingIndex(address account, uint256 tokenId) external view returns (uint256) {
        for (uint256 i = 0; i < ownerTokens[account].length; i++) {
            if (ownerTokens[account][i] == tokenId) {
                return i;
            }
        }
    }
    
    function getListings(uint256 cursor, uint256 limit) external view returns (uint256[2][] memory) {
        if (!marketActive) {
            return new uint[2][](0);
        }
        
        address marketAddress = address(this);
        uint256 maxCursor = NFT.balanceOf(marketAddress);

        if (cursor + limit < maxCursor) {
            maxCursor = cursor + limit;
        }

        uint[2][] memory listings = new uint[2][](maxCursor - cursor);
        
        uint256 listingIndex = 0;
        while (cursor < maxCursor) {
            uint256 tokenId = NFT.tokenOfOwnerByIndex(marketAddress, cursor);
            listings[listingIndex] = [tokenId, Marketplace[tokenId].price];
            
            listingIndex++;
            cursor++;
        }
        
        return listings;
    }

    function tokensOfOwner(address account) external view returns (uint256[] memory) {
        uint256 tokenCount = ownerTokens[account].length;

        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 index = 0; index < tokenCount; index++) {
            tokens[index] = ownerTokens[account][index];
        }
        
        return tokens;
    }

    function tokensOfOwnerCursor(address account, uint256 cursor, uint256 limit) external view returns (uint256[] memory) {
        uint256 maxCursor = ownerTokens[account].length;

        if (cursor + limit < maxCursor) {
            maxCursor = cursor + limit;
        }

        uint256[] memory tokens = new uint256[](maxCursor - cursor);
        for (uint256 index = 0; index < maxCursor; index++) {
            tokens[index] = ownerTokens[account][index];
        }

        return tokens;
    }

    function totalListings() public view returns (uint256) {
        if (!marketActive) {
            return 0;
        }
        
        address marketAddress = address(this);
        return NFT.balanceOf(marketAddress);
    }

    function withdrawTreasury() external {
        (bool transferTreasury,) = treasuryAddress.call{ value: address(this).balance }("");
        require(transferTreasury, "transferTreasury failed");
    }
    
    function royaltyOf(uint256 amount, uint256 fee) internal pure returns (uint256) {
        return (amount * fee) / 100;
    }
}