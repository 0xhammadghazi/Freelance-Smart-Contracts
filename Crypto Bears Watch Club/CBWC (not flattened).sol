// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @author Hammad Ghazi
contract CryptoBearWatchClub is ERC721, Ownable, ReentrancyGuard {
    using MerkleProof for bytes32[];

    enum SALE_STATUS {
        OFF,
        PRIVATE_SALE,
        PRESALE,
        AUCTION
    }

    SALE_STATUS public saleStatus;

    string baseTokenURI;

    // To store total number of CBWC NFTs minted
    uint256 private mintCount;

    uint256 public constant MAX_CBWC = 10000;
    uint256 public constant PRESALE_PRICE = 500000000000000000; // 0.5 Ether

    // Dutch auction related
    uint256 public auctionStartAt; // Auction timer for public mint
    uint256 public constant PRICE_DEDUCTION_PERCENTAGE = 100000000000000000; // 0.1 Ether
    uint256 public constant STARTING_PRICE = 2000000000000000000; // 2 Ether

    bytes32 public merkleRoot;

    // To store CBWC address has minted in presale
    mapping(address => uint256) public preSaleMintCount;

    // To store how many NFTs address can mint in private sale
    mapping(address => uint256) public privateSaleMintCount;

    // To store last mint block of an address, it will prevent smart contracts to mint more than 20 in one go
    mapping(address => uint256) public lastMintBlock;

    event Minted(uint256 totalMinted);

    constructor(string memory baseURI)
        ERC721("Crypto Bear Watch Club", "CBWC")
    {
        setBaseURI(baseURI);
    }

    modifier onlyIfNotSoldOut(uint256 _count) {
        require(
            totalSupply() + _count <= MAX_CBWC,
            "Transaction will exceed maximum supply of CBWC"
        );
        _;
    }

    // Admin only functions

    // To update sale status
    function setSaleStatus(SALE_STATUS _status) external onlyOwner {
        saleStatus = _status;
    }

    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        sendValue(address1, (balance * 34) / 100);
        sendValue(address2, (balance * 33) / 100);
        sendValue(address3, (balance * 33) / 100);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // Set auction timer
    function startAuction() external onlyOwner {
        require(
            saleStatus == SALE_STATUS.AUCTION,
            "Sale status is not set to auction"
        );
        auctionStartAt = block.timestamp;
    }

    // Set some Crypto Bears aside
    function reserveBears(uint256 _count)
        external
        onlyOwner
        onlyIfNotSoldOut(_count)
    {
        uint256 supply = totalSupply();
        mintCount += _count;
        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    // To whitelist users to mint during private sale
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
            require(_whitelistAddresses[i] != address(0), "Zero Address");
            privateSaleMintCount[_whitelistAddresses[i]] = _allowedCount[i];
        }
    }

    // Getter functions

    // Returns current price of dutch auction
    function dutchAuction() public view returns (uint256 price) {
        if (auctionStartAt == 0) {
            return STARTING_PRICE;
        } else {
            uint256 timeElapsed = block.timestamp - auctionStartAt;
            uint256 timeElapsedMultiplier = timeElapsed / 300;
            uint256 priceDeduction = PRICE_DEDUCTION_PERCENTAGE *
                timeElapsedMultiplier;

            // If deduction price is more than 1.5 ether than return 0.5 ether as floor price is 0.5 ether
            price = 1500000000000000000 >= priceDeduction
                ? (STARTING_PRICE - priceDeduction)
                : 500000000000000000;
        }
    }

    // Returns circulating supply of CBWC
    function totalSupply() public view returns (uint256) {
        return mintCount;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    //Mint functions

    function privateSaleMint(uint256 _count) external onlyIfNotSoldOut(_count) {
        require(
            privateSaleMintCount[msg.sender] > 0,
            "Address not eligible for private sale mint"
        );
        require(_count > 0, "Zero mint count");
        require(
            _count <= privateSaleMintCount[msg.sender],
            "Transaction will exceed maximum NFTs allowed to mint in private sale"
        );
        require(
            saleStatus == SALE_STATUS.PRIVATE_SALE,
            "Private sale is not started"
        );

        uint256 supply = totalSupply();
        mintCount += _count;
        privateSaleMintCount[msg.sender] -= _count;

        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
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
    ) external payable onlyIfNotSoldOut(_count) {
        require(
            merkleRoot != 0,
            "No address is eligible for presale minting yet"
        );
        require(
            saleStatus == SALE_STATUS.PRESALE,
            "Presale sale is not started"
        );
        require(
            MerkleProof.verify(
                _proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender, _allowedCount))
            ),
            "Address not eligible for presale mint"
        );

        require(_count > 0 && _count <= _allowedCount, "Invalid mint count");
        require(
            _allowedCount >= preSaleMintCount[msg.sender] + _count,
            "Transaction will exceed maximum NFTs allowed to mint in presale"
        );
        require(
            msg.value >= PRESALE_PRICE * _count,
            "Incorrect ether sent with this transaction"
        );

        uint256 supply = totalSupply();
        mintCount += _count;
        preSaleMintCount[msg.sender] += _count;

        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }
    }

    // Auction mint

    function auctionMint(uint256 _count)
        external
        payable
        nonReentrant
        onlyIfNotSoldOut(_count)
    {
        require(
            saleStatus == SALE_STATUS.AUCTION,
            "Auction mint is not started"
        );
        require(
            _count > 0 && _count < 21,
            "Minimum 0 & Maximum 20 CBWC can be minted per transaction"
        );
        require(
            lastMintBlock[msg.sender] != block.number,
            "Can only mint max 20 CBWC per block"
        );

        uint256 amountRequired = dutchAuction() * _count;
        require(
            msg.value >= amountRequired,
            "Incorrect ether sent with this transaction"
        );

        //to refund unused eth
        uint256 excess = msg.value - amountRequired;

        uint256 supply = totalSupply();
        mintCount += _count;
        lastMintBlock[msg.sender] = block.number;

        for (uint256 i = 0; i < _count; i++) {
            _mint(++supply);
        }

        //refunding excess eth to minter
        if (excess > 0) {
            sendValue(msg.sender, excess);
        }
    }

    function _mint(uint256 tokenId) private {
        _safeMint(msg.sender, tokenId);
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
}
