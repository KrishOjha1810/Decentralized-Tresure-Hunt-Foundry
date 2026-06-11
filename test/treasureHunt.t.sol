// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TreasureHunt.sol";

contract TreasureHuntsTest is Test {
    TreasureHunt treasureHunt;
    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");

    uint256 joinFee = 1 ether;

    // Owner is this test contract; withdraw() sends the balance back here.
    receive() external payable {}

    function setUp() public {
        treasureHunt = new TreasureHunt{value: 1 ether}(joinFee);
    }

    // ---- constructor ----------------------------------------------------

    function testConstructorRequiresEth() public {
        vm.expectRevert("Contract requires initial ETH");
        new TreasureHunt{value: 0}(joinFee);
    }

    function testConstructorRequiresJoinFee() public {
        vm.expectRevert("Join fee must be greater than 0");
        new TreasureHunt{value: 1 ether}(0);
    }

    function testTreasureStartsOnBoard() public view {
        (uint8 row, uint8 col) = treasureHunt.getTreasure();
        assertLt(row, 10);
        assertLt(col, 10);
    }

    // ---- joinGame -------------------------------------------------------

    function testJoinGame() public {
        vm.deal(player1, 5 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        (uint8 row, uint8 col) = treasureHunt.playerPos(player1);
        assertLt(row, 10);
        assertLt(col, 10);
    }

    function testJoinRevertsOnInsufficientFee() public {
        vm.deal(player1, 5 ether);
        vm.prank(player1);
        vm.expectRevert("Insufficient ETH to join");
        treasureHunt.joinGame{value: joinFee - 1}();
    }

    // ---- move -----------------------------------------------------------

    function testMoveToAdjacentCell() public {
        vm.deal(player1, 5 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        (uint8 row, uint8 col) = treasureHunt.playerPos(player1);
        uint8 nextRow = row + 1 < 10 ? row + 1 : row - 1;
        uint8 nextCol = col;

        vm.prank(player1);
        treasureHunt.move(nextRow, nextCol);

        (uint8 newRow, uint8 newCol) = treasureHunt.playerPos(player1);
        assertEq(newRow, nextRow);
        assertEq(newCol, nextCol);
    }

    function testMoveRevertsOnNonAdjacentCell() public {
        vm.deal(player1, 5 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        (uint8 row, uint8 col) = treasureHunt.playerPos(player1);
        // a diagonal (or far) cell is not a valid one-step move
        uint8 farRow = row < 8 ? row + 2 : row - 2;

        vm.prank(player1);
        vm.expectRevert("Invalid move");
        treasureHunt.move(farRow, col == 9 ? col - 1 : col + 1);
    }

    function testMoveRevertsOffBoard() public {
        vm.deal(player1, 5 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();

        vm.prank(player1);
        vm.expectRevert("Invalid move");
        treasureHunt.move(10, 0);
    }

    // ---- withdraw -------------------------------------------------------

    function testWithdrawOnlyOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        treasureHunt.withdraw();
    }

    function testWithdrawTransfersBalance() public {
        uint256 contractBalance = address(treasureHunt).balance;
        uint256 before = address(this).balance;
        treasureHunt.withdraw();
        assertEq(address(this).balance, before + contractBalance);
        assertEq(address(treasureHunt).balance, 0);
    }
}
