// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IArkouda {
    function updateReward(address _to, uint256 _tokenId) external;

    function updateRewardOnMint(address from, uint256 tokenId) external;
}

/// @author Hammad Ghazi
contract CryptoBearWatchClub is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using MerkleProof for bytes32[];
    Counters.Counter private _tokenId;

    IArkouda public Arkouda;

    uint256 public constant MAX_CBWC = 10000;
    uint256 public constant PRESALE_PRICE = 500000000000000000; //0.5 ether

    // Dutch auction related
    uint256 public auctionStartAt; //auction timer for public mint
    uint256 public constant PRICE_DEDUCTION_PERCENTAGE = 100000000000000000; //0.1
    uint256 public constant STARTING_PRICE = 2000000000000000000; //2 Ether

    bytes32 public merkleRoot;

    // To store CBWC address has minted in presale
    mapping(address => uint256) public preSaleMintCount;

    // To store how many NFTs address can mint more in private sale
    mapping(address => uint256) public privateSaleMintCount;

    string baseTokenURI;

    bool public saleOpen = false;
    bool public presaleOpen = false;

    event Minted(uint256 totalMinted);

    constructor(string memory baseURI)
        ERC721("Crypto Bear Watch Club", "CBWC")
    {
        setBaseURI(baseURI);
    }

    //admin only functions

    //Close sale if open, open sale if closed
    function flipSaleState() external onlyOwner {
        saleOpen = !saleOpen;
    }

    //Close presale if open, open presale if closed
    function flipPresaleState() external onlyOwner {
        presaleOpen = !presaleOpen;
    }

    function withdrawAll() external onlyOwner {
        sendValue(msg.sender, address(this).balance);
    }

    //to set Arkoude token contract address
    function setArkouda(address _arkouda) external onlyOwner {
        Arkouda = IArkouda(_arkouda);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function privateSaleWhiteList(
        address[] calldata _whitelistAddresses,
        uint256[] calldata _allowedCount
    ) external onlyOwner {
        require(
            _whitelistAddresses.length == _allowedCount.length,
            "Input length mismatch"
        );
        for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
            require(_allowedCount[i] > 0, "Invalid allowance amount");
            require(_whitelistAddresses[i] != address(0), "ZA");
            privateSaleMintCount[_whitelistAddresses[i]] = _allowedCount[i];
        }
    }

    // Set auction timer for public mint
    function startAuction() external onlyOwner {
        require(saleOpen, "Sale is not open");
        auctionStartAt = block.timestamp;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    //getter functions

    //Get token Ids of all tokens owned by user
    function walletOfOwner(address user)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(user);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(user, i);
        }

        return tokensId;
    }

    function dutchAuction() public view returns (uint256 price) {
        if (auctionStartAt == 0) {
            return STARTING_PRICE;
        } else {
            uint256 timeElapsed = block.timestamp - auctionStartAt;
            uint256 timeElapsedMultiplier = timeElapsed / 300;
            uint256 priceDeduction = PRICE_DEDUCTION_PERCENTAGE *
                timeElapsedMultiplier;

            // If deduction price is more than 2.5 ether than return 0.5 ether as floor price is 0.5 ether
            price = 2500000000000000000 >= priceDeduction
                ? (STARTING_PRICE - priceDeduction)
                : 500000000000000000;
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    //Mint functions

    function privateSaleMint(uint256 _count) external {
        require(
            totalSupply() + _count <= MAX_CBWC,
            "Exceeds maximum supply of CBWC"
        );
        require(
            privateSaleMintCount[msg.sender] > 0,
            "Address not eligible for private sale mint"
        );
        require(
            _count > 0 && _count <= privateSaleMintCount[msg.sender],
            "Invalid mint count"
        );
        require(!presaleOpen && !saleOpen, "Private sale is closed");

        privateSaleMintCount[msg.sender] -= _count;

        for (uint256 i = 0; i < _count; i++) {
            _mint();
        }
    }

    /**
     * @dev '_allowedCount' represents number of NFTs caller is allowed to mint in presale, and,
     * '_count' indiciates number of NFTs caller wants to mint in the transaction
     */
    function presaleMint(
        bytes32[] calldata _proof,
        uint256 _allowedCount,
        uint256 _count
    ) external payable nonReentrant {
        require(
            merkleRoot != 0,
            "No address is eligible for presale minting yet"
        );
        require(presaleOpen, "Presale is not open yet");
        require(!saleOpen, "Presale is closed");
        require(
            MerkleProof.verify(
                _proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender, _allowedCount))
            ),
            "Address not eligible for presale mint"
        );
        require(
            totalSupply() + _count <= MAX_CBWC,
            "Transaction will exceed maximum supply"
        );
        require(_count > 0 && _count <= _allowedCount, "Invalid mint count");
        require(
            _allowedCount >= preSaleMintCount[msg.sender] + _count,
            "Transaction will exceed maximum NFTs allowed to mint in presale"
        );

        require(msg.value >= PRESALE_PRICE * _count, "Incorrect ether sent");

        preSaleMintCount[msg.sender] += _count;

        for (uint256 i = 0; i < _count; i++) {
            _mint();
        }
    }

    //public mint
    function mint(uint256 _count) external payable nonReentrant {
        require(
            totalSupply() + _count <= MAX_CBWC,
            "Transaction will exceed maximum supply"
        );
        require(_count > 0, "Zero mint count");

        //to refund unused eth
        uint256 excess;
        if (msg.sender != owner()) {
            require(saleOpen, "Sale is close");
            require(_count <= 20, "Max 20 CBWC can be minted per transaction");
            uint256 amountRequired = dutchAuction() * _count;
            require(msg.value >= amountRequired, "Incorrect ether sent");
            excess = msg.value - amountRequired;
        }

        for (uint256 i = 0; i < _count; i++) {
            _mint();
        }

        //refunding excess eth to minter
        if (excess > 0) {
            sendValue(msg.sender, excess);
        }
    }

    function _mint() private {
        _tokenId.increment();
        uint256 tokenId = _tokenId.current();
        _safeMint(msg.sender, tokenId);
        Arkouda.updateRewardOnMint(msg.sender, tokenId);
        emit Minted(tokenId);
    }

    /**
     * @dev Called whenever eth is being transferred from the contract to the recipient.
     *
     * Called when owner wants to withdraw funds, and
     * to refund excess ether to the minter.
     */
    function sendValue(address recipient, uint256 amount) private {
        require(address(this).balance >= amount, "Insufficient Eth balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Unable to send value, recipient may have reverted");
    }

    //transfer functions

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        if (address(Arkouda) != address(0)) {
            Arkouda.updateReward(to, tokenId);
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
        bytes memory data
    ) public override {
        if (address(Arkouda) != address(0)) {
            Arkouda.updateReward(to, tokenId);
        }
        ERC721.safeTransferFrom(from, to, tokenId, data);
    }
}
