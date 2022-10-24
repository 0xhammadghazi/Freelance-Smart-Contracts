// SPDX-License-Identifier: MIT
//
//
//   ________            ____                  __   ________      __  
//  /_  __/ /_  ___     / __ )___  ____  ___  / /  / ____/ /_  __/ /_ 
//   / / / __ \/ _ \   / __  / _ \/_  / / _ \/ /  / /   / / / / / __ \
//  / / / / / /  __/  / /_/ /  __/ / /_/  __/ /  / /___/ / /_/ / /_/ /
// /_/ /_/ /_/\___/  /_____/\___/ /___/\___/_/   \____/_/\__,_/_.___/ 
//                                                                 

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./ERC721AQueryable.sol";

error OverMintLimit(uint256 quantity);
error CrossedMaxSupply();
error BuyerSameAsSeller();
error InvalidSignature();
error VoucherAlreadyClaimed();


contract TheBezelClub is Ownable, ERC721AQueryable, EIP712 {

  uint256 private immutable maxBatchSize;
  uint256 private immutable collectionSize;
  string private _baseTokenURI;
  address public immutable minter;

  //use ECDS library to verify signature
  struct LazyMintExternalNftData {
      address seller;
      address buyer;
      string currency;
      uint256 price;
      string uid;
      bytes signature;
  }
  // mapping digest to keep track of claimed vouchers
  mapping(bytes32 => bool) isVoucherClaimed; 

  constructor(
    uint32 maxBatchSize_,
    uint32 collectionSize_,
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
    function _verifyExternalNFTLazyMint(LazyMintExternalNftData calldata lazyData_)
        internal
        view
        returns (address,bytes32)
    {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("LazyMintExternalNftData(address seller,address buyer,string currency,uint256 price,string uid)"),
            lazyData_.seller,
            lazyData_.buyer,
            keccak256(bytes(lazyData_.currency)),
            lazyData_.price,
            keccak256(bytes(lazyData_.uid))
        )));
        address signer = ECDSA.recover(digest, lazyData_.signature);
        return (signer,digest);
    }

    function lazyMint(LazyMintExternalNftData calldata _lazyData)
        external
        returns (uint256)
    {
        if( _lazyData.seller == _lazyData.buyer) {
          revert BuyerSameAsSeller();
        }

        if(_totalMinted() >= collectionSize) {
        revert CrossedMaxSupply();
        }
        uint256 tokenId_ = _totalMinted();
        // verifying the signature by comparing the public address
        address signer;
        bytes32 digest;
        (signer,digest) = _verifyExternalNFTLazyMint(
            _lazyData
        );
        // require(_lazyData.seller == signer, "signature not verified");
        if(signer != minter) {
          revert InvalidSignature();
        }
        
        if(isVoucherClaimed[digest] == true) {
          revert VoucherAlreadyClaimed();
        }

        isVoucherClaimed[digest] = true;
        
        _safeMint( _lazyData.buyer, 1);
        return tokenId_;
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