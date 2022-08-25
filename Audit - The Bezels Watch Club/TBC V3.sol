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

import "./Ownable.sol";
import "./ERC721AQueryable.sol";

error OverMintLimit(uint256 quantity);
error CrossedMaxSupply();

contract TheBezelClub is Ownable, ERC721AQueryable {
    uint256 private immutable maxBatchSize;
    uint256 private immutable collectionSize;
    string private _baseTokenURI;

    constructor(uint256 maxBatchSize_, uint256 collectionSize_)
        ERC721A("The Bezel Club", "TBC")
    {
        maxBatchSize = maxBatchSize_;
        collectionSize = collectionSize_;
    }

    function adminMint(uint256 quantity, address wallet) external onlyOwner {
        if (_totalMinted() + quantity > collectionSize) {
            revert CrossedMaxSupply();
        }
        if (quantity > maxBatchSize) {
            revert OverMintLimit({quantity: quantity});
        }
        _safeMint(wallet, quantity);
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

    receive() external payable {
        revert();
    }
}
