// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ProtocolBadge
/// @notice ERC-721 achievement badge for protocol contributors and LP program rewards.
contract ProtocolBadge is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId = 1;

    event BadgeMinted(address indexed recipient, uint256 indexed tokenId, string tokenURI_);

    constructor(address initialOwner) ERC721("DeFi Protocol Badge", "DPB") Ownable(initialOwner) {}

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function mintBadge(address recipient, string calldata tokenURI_) external onlyOwner returns (uint256 tokenId) {
        require(recipient != address(0), "Badge: zero recipient");

        tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        emit BadgeMinted(recipient, tokenId, tokenURI_);
    }
}
