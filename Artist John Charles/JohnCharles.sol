// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OperatorFilterer} from "closedsea/src/OperatorFilterer.sol";

error ZeroInput();
error ZeroAddress();
/// If the transaction will exceed maximum supply
error ExceedsMaximumSupply(uint256);
/// If token id to burn doesn't exists
error InvalidTokenID(uint256);

/// @notice The image within the NFT and artwork are the sole property and copyright of Artist John Charles and are legally protected by international copyright laws.
// Under no circumstance may you reproduce, publish or distribute elsewhere, in any medium, this image for commercial purposes, without proper and prior written permission from John Charles or his legal advisers.
// Unauthorised duplication or usage for commercial purposes is prohibited by the Copyright law and will be prosecuted.
// Artist John Charles retains all of the copyrights to all artwork , regardless of whether or not the original image/NFT have been sold. Should you wish to use an image for commercial purposes please contact johncharles@artistjohncharles.com
contract ArtistJohnCharles is OperatorFilterer, Ownable, ERC2981, ERC721 {
    uint120 public maxSupply;
    uint120 public currentSupply;
    bool public operatorFilteringEnabled = true;

    string private baseURI;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint120 maxSupply_,
        address royaltyReceiverAddress,
        uint96 royaltyPercentage
    ) ERC721(name_, symbol_) {
        if (royaltyReceiverAddress == address(0)) {
            revert ZeroAddress();
        }

        baseURI = baseURI_;

        // 0 means collection can have tokens upto the maximum number uint120 can hold
        if (maxSupply_ > 0) {
            maxSupply = maxSupply_;
        } else {
            maxSupply = type(uint120).max;
        }

        // Subscribing to the default OpenSea curated block list
        _registerForOperatorFiltering();

        // Set initial default royalty
        _setDefaultRoyalty(royaltyReceiverAddress, royaltyPercentage);
    }

    // =========================================================================
    //                              Token Logic
    // =========================================================================

    /// @notice Function to set the metadata uri.
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    /**
     * @notice Mint NFTs to the recipient address.
     * @param recipient address to the mint the NFTs at.
     * @param quantity total NFTs to mint.
     * @dev Only callable by Owner.
     */
    function mint(address recipient, uint120 quantity) external onlyOwner {
        if (quantity == 0) {
            revert ZeroInput();
        }

        uint256 supply = totalSupply();

        if (supply + quantity > maxSupply) {
            revert ExceedsMaximumSupply(supply + quantity);
        }

        currentSupply += quantity;

        for (uint256 i; i < quantity; ) {
            _safeMint(recipient, ++supply);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Burns the NFT first and then mints it to some address.
     * @param mintTo address to the mint the burnt NFT at.
     * @param tokenId tokenId to burn.
     * @dev Only callable by Owner.
     */
    function burnAndMint(address mintTo, uint256 tokenId) external onlyOwner {
        if (!_exists(tokenId)) {
            revert InvalidTokenID(tokenId);
        }

        _burn(tokenId);

        if (mintTo == address(0)) {
            revert ZeroAddress();
        }
        _safeMint(mintTo, tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return currentSupply;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // =========================================================================
    //                           Operator filtering
    // =========================================================================

    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function setOperatorFilteringEnabled(bool value) external onlyOwner {
        operatorFilteringEnabled = value;
    }

    function _operatorFilteringEnabled() internal view override returns (bool) {
        return operatorFilteringEnabled;
    }

    // =========================================================================
    //                                 ERC2891
    // =========================================================================

    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyOwner
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    // =========================================================================
    //                                  ERC165
    // =========================================================================

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
