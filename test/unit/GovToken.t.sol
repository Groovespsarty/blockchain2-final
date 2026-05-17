// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GovToken.sol";

contract GovTokenTest is Test {
    GovToken token;
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.prank(owner);
        token = new GovToken(owner);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10 ** 18);
    }

    function test_OwnerReceivesSupply() public view {
        assertEq(token.balanceOf(owner), 1_000_000 * 10 ** 18);
    }

    function test_MintByOwner() public {
        vm.prank(owner);
        token.mint(alice, 1000e18);
        assertEq(token.balanceOf(alice), 1000e18);
    }

    function test_MintByNonOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1000e18);
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(alice, 500e18);
        assertEq(token.balanceOf(alice), 500e18);
    }

    function test_Delegate() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(alice);

        assertEq(token.getVotes(alice), 100e18);
    }

    function test_VotingPowerAfterTransfer() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(alice);

        vm.prank(alice);
        token.transfer(bob, 40e18);

        assertEq(token.getVotes(alice), 60e18);
    }

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);

        vm.prank(owner);
        token.transfer(signer, 100e18);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    signer, bob, 50e18, token.nonces(signer), deadline
                ))
            ))
        );

        token.permit(signer, bob, 50e18, deadline, v, r, s);
        assertEq(token.allowance(signer, bob), 50e18);
    }

    function test_NameAndSymbol() public view {
        assertEq(token.name(), "DeFi Gov Token");
        assertEq(token.symbol(), "DGT");
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }
}