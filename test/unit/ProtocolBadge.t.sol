// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/ProtocolBadge.sol";

contract ProtocolBadgeTest is Test {
    ProtocolBadge badge;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    function setUp() public {
        vm.prank(owner);
        badge = new ProtocolBadge(owner);
    }

    function test_MintBadge() public {
        vm.prank(owner);
        uint256 tokenId = badge.mintBadge(alice, "ipfs://badge-1");

        assertEq(tokenId, 1);
        assertEq(badge.ownerOf(tokenId), alice);
        assertEq(badge.tokenURI(tokenId), "ipfs://badge-1");
        assertEq(badge.nextTokenId(), 2);
    }

    function test_MintBadge_NonOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        badge.mintBadge(alice, "ipfs://badge-1");
    }

    function test_MintBadge_ZeroRecipient_Reverts() public {
        vm.prank(owner);
        vm.expectRevert("Badge: zero recipient");
        badge.mintBadge(address(0), "ipfs://badge-1");
    }

    function test_NameAndSymbol() public view {
        assertEq(badge.name(), "DeFi Protocol Badge");
        assertEq(badge.symbol(), "DPB");
    }
}
