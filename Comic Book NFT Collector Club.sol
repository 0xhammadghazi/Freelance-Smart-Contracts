// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error ExceedsMaximumSupply();

contract ComicBookNFTCollectorClub is ERC721AQueryable, Ownable {

    string private baseTokenURI;

    uint256 public constant MAX_SUPPLY = 2000;

    constructor(string memory baseURI)
        ERC721A("Comic Book NFT Collector Club", "CBNCC")
    {
        baseTokenURI = baseURI;
    }

    modifier soldOut(uint256 _count) {
        if (_totalMinted() + _count > MAX_SUPPLY)
            revert ExceedsMaximumSupply();
        _;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        baseTokenURI = baseURI;
    }

    function mint(uint256 _count)
        external
        onlyOwner
        soldOut(_count)
    {
        _mint(msg.sender, _count, "", false);
    }


    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _startTokenId() internal pure virtual override returns (uint256) {
        return 1;
    }

}
