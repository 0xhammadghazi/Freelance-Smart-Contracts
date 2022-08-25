// // SPDX-License-Identifier: MIT
// //
// //
// //   ________            ____                  __   ________      __  
// //  /_  __/ /_  ___     / __ )___  ____  ___  / /  / ____/ /_  __/ /_ 
// //   / / / __ \/ _ \   / __  / _ \/_  / / _ \/ /  / /   / / / / / __ \
// //  / / / / / /  __/  / /_/ /  __/ / /_/  __/ /  / /___/ / /_/ / /_/ /
// // /_/ /_/ /_/\___/  /_____/\___/ /___/\___/_/   \____/_/\__,_/_.___/ 
// //                                                                 

// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ERC721A.sol";

// contract TheBezelClub is Ownable, ERC721A {
//   uint256 public immutable maxSizePerMint;


//   mapping(address => uint256) public allowlist;

//   constructor(
//     uint256 maxBatchSize_,
//     uint256 collectionSize_
//   ) ERC721A("The Bezel Club", "TBC", maxBatchSize_, collectionSize_) {
//     maxSizePerMint = maxBatchSize_;
//   }


//   function adminMint(uint256 quantity, address wallet)
//     external
//     onlyOwner
//   {
//     require(totalSupply() + quantity <= collectionSize, "reached max supply");
//     require(
//       quantity <= maxSizePerMint,
//       "can not mint this many"
//     );
//     _safeMint(wallet, quantity);
//   }

//   // // metadata URI
//   string private _baseTokenURI;

//   function _baseURI() internal view virtual override returns (string memory) {
//     return _baseTokenURI;
//   }

//   function setBaseURI(string calldata baseURI) external onlyOwner {
//     _baseTokenURI = baseURI;
//   }

//   function withdrawMoney() external onlyOwner {
//     (bool success, ) = msg.sender.call{value: address(this).balance}("");
//     require(success, "Transfer failed.");
//   }

//   function setOwnersExplicit(uint256 quantity) external onlyOwner {
//     _setOwnersExplicit(quantity);
//   }

//   function numberMinted(address _user) public view returns (uint256) {
//     return _numberMinted(_user);
//   }

//   function getOwnershipData(uint256 tokenId)
//     external
//     view
//     returns (TokenOwnership memory)
//   {
//     return ownershipOf(tokenId);
//   }
// }