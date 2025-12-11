// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TreasureHunt.sol";

contract TreasureHuntsTest is Test{

    TreasureHunt treasureHunt;
    address owner = address(1);
    address player1 = address(2);
    address player2 = address(3);

    uint256 joinFee = 1 ether;

    function setUp() public{
        treasureHunt = new TreasureHunt{value: 1 ether}(joinFee);
    }

    function testJoinGame() public{
        vm.deal(player1, 5 ether);

        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        (uint8 row, uint8 col) = treasureHunt.playerPos(player1);
        assert(row >= 0 && row < 10);
        assert(col >= 0 && col < 10);
    }

    function testMove() public{
        vm.deal(player1, 5 ether);
        
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        (uint8 row, uint8 col) = treasureHunt.playerPos(player1);

        uint8 nextRow = row+1 < 10 ? row+1 : row-1;
        uint8 nextCol = col;

        vm.prank(player1);
        treasureHunt.move(nextRow, nextCol);

        // Verify the player moved correctly
        (uint8 newRow, uint8 newCol) = treasureHunt.playerPos(player1);
        assertEq(newRow, nextRow);
        assertEq(newCol, nextCol);
    }

    function testMoveTreasure() public {
        vm.deal(player1, 5 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        (uint8 row, uint8 col) = treasureHunt.playerPos(player1);

        uint8 nextRow = row+1 < 10 ? row+1 : row-1;
        uint8 nextCol = col;

        vm.prank(player1);
        treasureHunt.move(nextRow, nextCol);

        
    }
}