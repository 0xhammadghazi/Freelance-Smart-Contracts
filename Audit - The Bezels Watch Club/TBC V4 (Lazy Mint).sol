// SPDX-License-Identifier: MIT
//
//
//   ________            ____                  __   ________      __  
//  /_  __/ /_  ___     / __ )___  ____  ___  / /  / ____/ /_  __/ /_ 
//   / / / __ \/ _ \   / __  / _ \/_  / / _ \/ /  / /   / / / / / __ \
//  / / / / / /  __/  / /_/ /  __/ / /_/  __/ /  / /___/ / /_/ / /_/ /
// /_/ /_/ /_/\___/  /_____/\___/ /___/\___/_/   \____/_/\__,_/_.___/ 
//                                                                 

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

error OverMintLimit(uint256 quantity);
error CrossedMaxSupply();


contract TheBezelClub is Ownable, ERC721AQueryable, EIP712 {

  uint256 private immutable maxBatchSize;
  uint256 private immutable collectionSize;
  string private _baseTokenURI;
  address public minter;

  //use ECDS library to verify signature
    struct LazyMintData {
        address seller;
        address buyer;
        string currency;
        uint256 price;
        bytes signature;
    }

  constructor(
    uint256 maxBatchSize_,
    uint256 collectionSize_,
    string memory name_,
    string memory version_,
    address minter_
  ) ERC721A("The Bezel Club", "TBC") EIP712(name_, version_) {
    maxBatchSize = maxBatchSize_;
    collectionSize = collectionSize_;
    minter = minter_;
  }


  function adminMint(uint256 quantity, address wallet)
    external
    onlyOwner
  {
    if(_totalMinted() + quantity > collectionSize) {
        revert CrossedMaxSupply();
    }
    if (quantity > maxBatchSize) {
        revert OverMintLimit({
                quantity: quantity
            });
    } 
    _safeMint(wallet, quantity);
  }

      // function to find the signer public address from signature
  function _verifyExternalNFTLazyMint(LazyMintData calldata lazyData_)
    internal
    view
    returns (address)
  {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("LazyMintData(address seller,address buyer,string currency,uint256 price)"),
            lazyData_.seller,
            lazyData_.buyer,
            keccak256(abi.encodePacked(lazyData_.currency)),
            lazyData_.price
        )));
        address signer = ECDSA.recover(digest, lazyData_.signature);
        return signer;
  }

  function lazyMint(LazyMintData calldata _lazyData)
        external returns (uint256 tokenId_)
    {
        require(
            _lazyData.seller != _lazyData.buyer,
            "seller and buyer is same"
        );
        // verifying the signature by comparing the public address
        address signer = _verifyExternalNFTLazyMint(
            _lazyData
        );
        // require(_lazyData.seller == signer, "signature not verified");
        require(signer == minter, "signature not verified");
        
        _safeMint( _lazyData.buyer, 1);
        tokenId_ = _totalMinted() - 1;
    }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function numberMinted(address userWallet) external view returns (uint256) {
    return _numberMinted(userWallet);
  }

}