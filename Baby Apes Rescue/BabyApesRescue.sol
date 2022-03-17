// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./ERC721Namable.sol";
import "./interfaces/IBananaBar.sol";
import "./interfaces/IRandom.sol";

contract BabyApesRescue is ERC721Namable, Ownable {
    IBananaBar public bananaBar;
    IRandom public Random;

    bool public mintOpen;
    bool public maticMintOpen;
    bool public wlMintOpen;

    address public constant burn =
        address(0x0000000000000000000000000000000000000000);

    uint256 public constant MAX_SUPPLY = 25000;

    // Track max token id that has been minted so far, starting from 2500 cause OG token id ends at 2500
    uint256 public maxTokenIdMinted = 2500;

    // Mint steal chance for monsters
    uint256 public stealPercentage = 10;

    // Track all monster token ids that have been minted.
    uint256[] public monsterList;

    // Track Ids of airdropped Baby Apes OG
    uint256[] public ogList;

    // Track stolen count
    uint256 public monsterStolenCount;
    uint256 public cloneStolenCount;
    uint256 public madScientistStolenCount;

    // Minting fee
    uint256 public barMintFeeBase = 30 ether;
    uint256 public maticMintFee = 100 ether;

    // NFTs minted using matic
    uint256 public maticMintCount;

    uint256 public revealFee = 30 ether;
    uint256 public discountTxLimit = 1;
    uint256 discount = 10; //10% discount

    string baseTokenURI;

    // Tracks the amount of NFTs an address holds
    mapping(address => uint256) public ogBalance;
    mapping(address => uint256) public cloneBalance;
    mapping(address => uint256) public monsterBalance;

    mapping(uint256 => bool) public alreadyAirdropped;

    mapping(address => uint256) public discountAvailTxCount;

    mapping(address => bool) public isWhitelisted;

    // To store different tier prices
    mapping(uint8 => uint256) public price;

    event BabyApesRescueMinted(
        uint256 totalMinted,
        address indexed minter,
        address indexed mintedAt,
        bool isSteal
    );
    event OGAirdropped(address indexed to, uint256 tokenId);
    event Revealed(uint256 tokenId);
    event Tipped(address indexed tipper, address indexed to, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI
    ) ERC721Namable(_name, _symbol) {
        setBaseURI(baseURI);
        price[1] = 30 ether; //Tier 1 --> 30 Bar
        price[2] = 45 ether; //Tier 2 --> 45 Bar
        price[3] = 60 ether; //Tier 3 --> 60 Bar
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function withdrawAll() external onlyOwner {
        (bool success, ) = payable(_msgSender()).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed.");
    }

    function setBananaBar(address _bananaBarAddress) external onlyOwner {
        bananaBar = IBananaBar(_bananaBarAddress);
    }

    function setRandom(address _randomAddress) external onlyOwner {
        Random = IRandom(_randomAddress);
    }

    function changeTierPrice(uint8 _tier, uint256 _newTierPrice)
        external
        onlyOwner
    {
        require(_tier > 0 && _tier <= 3, "Invalid Tier");
        price[_tier] = _newTierPrice;
    }

    function changeMaticMintFree(uint256 _newMaticMintFee) external onlyOwner {
        maticMintFee = _newMaticMintFee;
    }

    function changeDiscountTxLimit(uint256 _newTxLimit) external onlyOwner {
        discountTxLimit = _newTxLimit;
    }

    function changeRevealFee(uint256 _newRevealFee) external onlyOwner {
        revealFee = _newRevealFee;
    }

    function changeNamePrice(uint256 _price) external onlyOwner {
        nameChangePrice = _price;
    }

    function changeBioPrice(uint256 _price) external onlyOwner {
        bioChangePrice = _price;
    }

    function changeBirthdatePrice(uint256 _price) external onlyOwner {
        birthdateChangePrice = _price;
    }

    function changeName(uint256 tokenId, string memory newName)
        public
        override
    {
        bananaBar.burn(_msgSender(), nameChangePrice);
        super.changeName(tokenId, newName);
    }

    function changeBio(uint256 tokenId, string memory _bio) public override {
        bananaBar.burn(_msgSender(), bioChangePrice);
        super.changeBio(tokenId, _bio);
    }

    function changeBirthdate(uint256 tokenId, uint256 _birthdate)
        public
        override
    {
        bananaBar.burn(_msgSender(), birthdateChangePrice);
        super.changeBirthdate(tokenId, _birthdate);
    }

    // Note: Not storing revealed NFTs id in contract, if instant revealed is purchased of already revealed NFT then
    // your BananaBar will be burnt for nothing
    function instantReveal(uint256 id) external {
        require(id > 2500 && id <= maxTokenIdMinted, "Invalid token id");
        require(ownerOf(id) == _msgSender(), "Caller is not the owner");
        bananaBar.burn(_msgSender(), revealFee);
        emit Revealed(id);
    }

    function flipMintState() external onlyOwner {
        mintOpen = !mintOpen;
    }

    function flipMaticMintState() external onlyOwner {
        maticMintOpen = !maticMintOpen;
    }

    function flipWlMintState() external onlyOwner {
        wlMintOpen = !wlMintOpen;
    }

    function setStolenCount(uint256 _id) private {
        if (_id <= 10000) {
            if (isMonster(_id)) {
                monsterStolenCount++;
            } else {
                cloneStolenCount++;
            }
        } else {
            if (isMonster(_id)) {
                monsterStolenCount++;
            } else if (_id % 4 == 0 && _id % 5 != 0) {
                cloneStolenCount++;
            } else {
                madScientistStolenCount++;
            }
        }
    }

    function whitelistAddress(address[] calldata users, bool status)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < users.length; i++) {
            isWhitelisted[users[i]] = status;
        }
    }

    // Getter functions

    //Get token Ids of all tokens owned by _owner
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    // Returns the addresses of the owners of monster token ids
    function getMonsterOwners() external view returns (address[] memory) {
        address[] memory result = new address[](monsterList.length);

        for (uint256 i = 0; i < monsterList.length; i++) {
            result[i] = ownerOf(monsterList[i]);
        }

        return result;
    }

    // Takes total number of NFT you want to mint in a single tx
    // Returns total Bar user will need to burn in order to mint desired NFTs
    function getBarBurnAmount(uint256 _count) public view returns (uint256) {
        uint256 payableBurnAmount;
        for (uint256 i = 0; i < _count; i++) {
            payableBurnAmount += _getBarBurnAmount(i + 1);
        }
        return payableBurnAmount;
    }

    function _getBarBurnAmount(uint256 index) internal view returns (uint256) {
        uint256 currentSupply = maxTokenIdMinted + index;

        if (currentSupply > 20000) {
            return price[3]; // 20001 - 250000
        } else if (currentSupply > 10000) {
            return price[2]; // 10001 - 20000
        } else {
            return price[1]; // 1 - 10000
        }
    }

    function getDiscountEligibility(address user) public view returns (bool) {
        uint256[] memory tokenIds = walletOfOwner(user);
        if (tokenIds.length > 0) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                if (tokenIds[i] <= 2500) {
                    return true;
                }
            }
        }
        return false;
    }

    function isMonster(uint256 _id) public view returns (bool) {
        if (_id <= 2500 || _id > maxTokenIdMinted) {
            return false;
        } else return (_id % 5 == 0 ? true : false);
    }

    function getTypeCounts()
        external
        view
        returns (
            uint256 ogCount,
            uint256 cloneCount,
            uint256 madScientistCount,
            uint256 monsterCount
        )
    {
        uint256 supply = maxTokenIdMinted;
        for (uint256 i = 2501; i <= supply; i++) {
            if (i <= 10000) {
                if (isMonster(i)) {
                    monsterCount++;
                } else {
                    cloneCount++;
                }
            } else {
                if (isMonster(i)) {
                    monsterCount++;
                } else if (i % 4 == 0 && i % 5 != 0) {
                    cloneCount++;
                } else {
                    madScientistCount++;
                }
            }
        }
        ogCount = ogList.length;
    }

    function airdropOG(
        address[] calldata _ogHolders,
        uint256[] calldata _tokenIds
    ) external onlyOwner {
        require(_ogHolders.length == _tokenIds.length, "Input length mismatch");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                _tokenIds[i] > 0 && _tokenIds[i] <= 2500,
                "Invalid token id"
            );
            require(
                !alreadyAirdropped[_tokenIds[i]],
                "Token Id has already been airdropped"
            );
            require(_ogHolders[i] != address(0), "Airdrop to Null address");

            alreadyAirdropped[_tokenIds[i]] = true;

            bananaBar.updateRewardOnMint(_ogHolders[i]);

            ogBalance[_ogHolders[i]]++;
            ogList.push(_tokenIds[i]);

            _safeMint(_ogHolders[i], _tokenIds[i]);

            // Reward banana bar for holding OG
            bananaBar.rewardOnMint(_ogHolders[i]);
            emit OGAirdropped(_ogHolders[i], _tokenIds[i]);
        }
    }

    // Mint functions

    //mint with bar
    function mint(uint256 _count) external {
        require(_msgSender() == tx.origin, "No contract minting allowed!");
        require(
            maxTokenIdMinted + _count <= MAX_SUPPLY,
            "Transaction will exceed maximum supply"
        );

        if (_msgSender() != owner()) {
            require(mintOpen, "Mint is closed");
            require(
                _count > 0 && _count <= 10,
                "Can't mint 0 or more than 10 in a single transaction"
            );

            // Without discount
            uint256 totalBarBurnAmount = getBarBurnAmount(_count);

            bool canAvailDiscount = getDiscountEligibility(_msgSender());

            // Calculate discount if minter is eligible
            if (canAvailDiscount) {
                // Only calculate if the user has availed discount in less than the allowed discount transaction limit
                if (discountAvailTxCount[_msgSender()] < discountTxLimit) {
                    discountAvailTxCount[_msgSender()]++;
                    // With discount
                    totalBarBurnAmount =
                        totalBarBurnAmount -
                        (totalBarBurnAmount / discount);
                }
            }

            bananaBar.burn(_msgSender(), totalBarBurnAmount);
        }

        bananaBar.updateRewardOnMint(_msgSender());

        for (uint256 i = 0; i < _count; i++) {
            cloneMint(_msgSender(), _count);
        }
    }

    function mintMatic(uint256 _count) external payable {
        require(_msgSender() == tx.origin, "No contract minting allowed!");
        require(
            maxTokenIdMinted + _count <= MAX_SUPPLY,
            "Transaction will exceed maximum supply"
        );

        if (_msgSender() != owner()) {
            require(maticMintOpen, "Minting will matic is not allowed");
            if (wlMintOpen) {
                require(
                    isWhitelisted[_msgSender()],
                    "Matic mint only open for WL users"
                );
            }
            require(
                _count > 0 && _count <= 10,
                "Can't mint 0 or more than 10 in a single transaction"
            );
            require(
                msg.value >= _count * maticMintFee,
                "Matic send are less than required"
            );
        }

        maticMintCount += _count;

        bananaBar.updateRewardOnMint(_msgSender());

        for (uint256 i = 0; i < _count; i++) {
            handleMint(_msgSender(), false);
        }
    }

    function cloneMint(address _to, uint256 _count) private {
        bool isSteal;

        // Determine if it was stolen, give it to the monster owner.
        if (Random.canSteal(_count, stealPercentage)) {
            uint256 monsterId = Random.getMonsterId(
                monsterList,
                stealPercentage,
                _count
            );

            if (monsterId != type(uint256).max) {
                isSteal = true;
                // Robber address
                _to = ownerOf(monsterId);
            }
        }

        handleMint(_to, isSteal);
    }

    function handleMint(address _to, bool isSteal) private {
        if (_to != _msgSender()) {
            bananaBar.updateRewardOnMint(_msgSender());
        }

        maxTokenIdMinted++;
        if (isSteal) {
            setStolenCount(maxTokenIdMinted);
        }

        if (isMonster(maxTokenIdMinted)) {
            monsterList.push(maxTokenIdMinted);
            monsterBalance[_to]++;
        } else {
            cloneBalance[_to]++;
        }
        _safeMint(_to, maxTokenIdMinted);
        emit BabyApesRescueMinted(maxTokenIdMinted, _msgSender(), _to, isSteal);
    }

    // Tip a baby ape
    // Note: Tipper must approve atleast _amount to this contract
    function tipBabyApeHolder(uint256 _tokenId, uint256 _amount) external {
        require(_exists(_tokenId), "Invalid token id");
        address _to = ownerOf(_tokenId);
        require(_to != _msgSender(), "Can not tip own address");
        bananaBar._tipBabyApeHolder(_msgSender(), _to, _amount);
        emit Tipped(_msgSender(), _to, _amount);
    }

    // Transfer functions

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        if (address(bananaBar) != address(0) && !isMonster(tokenId)) {
            bananaBar.updateReward(from, to);
        }
        if (tokenId <= 2500) {
            ogBalance[from]--;
            ogBalance[to]++;
        } else if (isMonster(tokenId)) {
            monsterBalance[from]--;
            monsterBalance[to]++;
        } else {
            cloneBalance[from]--;
            cloneBalance[to]++;
        }
        ERC721.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        if (address(bananaBar) != address(0) && !isMonster(tokenId)) {
            bananaBar.updateReward(from, to);
        }
        if (tokenId <= 2500) {
            ogBalance[from]--;
            ogBalance[to]++;
        } else if (isMonster(tokenId)) {
            monsterBalance[from]--;
            monsterBalance[to]++;
        } else {
            cloneBalance[from]--;
            cloneBalance[to]++;
        }
        ERC721.safeTransferFrom(from, to, tokenId, _data);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
}
