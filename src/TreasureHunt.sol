// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TreasureHunt is Ownable{

    struct Position{
        uint8 row;
        uint8 col;
    }

    uint256 joinFee;
    uint8 public currentTurn;
    //player address -> grid position
    mapping (address => Position) public playerPos;

    address public winner;
    //Treasure Location determined dynamically 
    Position private treasure;

    event PlayerMoved(address indexed player, uint8 row, uint8 col);
    event WinnerDeclared(address indexed player, uint256 reward);

    constructor(uint256 _joinFee) payable Ownable(msg.sender) {
        require(msg.value > 0, "Contract requires initial ETH");
        require(_joinFee > 0, "Join fee must be greater than 0");
        
        joinFee = _joinFee;

        treasure = Position( //setting up the treasure location dynamically 
            uint8(uint256(keccak256(abi.encodePacked(block.number, block.timestamp))) % 10),
            uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1)))) % 10)
        );
    }

    function joinGame() external payable { 
        require(msg.value >= joinFee, "Insufficient ETH to join");
        //if not zero means already joined 
        require(playerPos[msg.sender].row == 0 && playerPos[msg.sender].col == 0, "Already joined"); 
        
        playerPos[msg.sender] = Position(
            uint8(uint256(keccak256(abi.encodePacked(msg.sender,block.timestamp)))%10),
            uint8(uint256(keccak256(abi.encodePacked(msg.sender,block.number)))%10)
        );
    }

    function isValidMove(uint8 row, uint8 col) internal view returns (bool) { 
        // Get the current position of the player
        Position memory current = playerPos[msg.sender];

        if (row >= 10 || col >= 10) return false;

        // Calculate difference 
        uint8 x = current.row > row ? current.row - row : row - current.row;
        uint8 y = current.col > col ? current.col - col : col - current.col;

        // Return true only if the move is to an adjacent cell
        return (x == 1 && y == 0) || (x == 0 && y == 1);
    }

    function move(uint8 nextRow, uint8 nextCol) external{
        require(isValidMove(nextRow, nextCol), "Invalid move");
        
        // Update player position
        playerPos[msg.sender] = Position(nextRow, nextCol);

        if(nextRow == treasure.row && nextCol == treasure.col){
            declareWinner();
            return;
        }

        moveTreasure(nextRow, nextCol);//based on move 
    }

    function moveTreasure(uint8 row, uint8 col) internal { 
        uint256 pos = row * 10 + col;
        if((pos) % 5 == 0){//multiple of 5
            moveToAdjacent();
        }   

        if(isPrime(pos)){ //if it is a prime number 
            moveToRandom();
        } 
    }

    function moveToAdjacent() internal {
        uint8[4] memory directions = [0,1,2,3];//up down left right //is this a better option or not? or using global is more optimal
        uint8 random = directions[uint8(uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) %4 )];

        //if edge case is triggered it won't move is that rightlogic?
        if(random == 0 && treasure.row > 0) treasure.row--; //up
        else if(random == 1 && treasure.row < 9) treasure.row++; //down 
        else if(random == 2 && treasure.col > 0) treasure.col--;
        else if(random == 3 && treasure.col < 9) treasure.col++;
    }

    function moveToRandom() internal{ 
        treasure = Position(
            uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) % 10),
            uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1 )))) % 10)
        );
    }

    function declareWinner() internal { 
        winner = msg.sender;
        uint256 prize = (address(this).balance * 90) / 100;
        uint256 reserve = address(this).balance - prize;

        payable(winner).transfer(prize);

        emit WinnerDeclared(winner, prize);

        treasure = Position(
            uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) % 10),
            uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number-1))))%10)
        );
    }

    function isPrime(uint256 num) internal pure returns(bool){
        if (num <= 1) return false;

        if(num==2 || num==3){
            return true;
        }

        for(uint i=2; i <= num/2; i++){
            if((num % i)==0) return false;
        }

        return true;
    }

    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(address(this).balance);
    }

    function getTreasure() public view returns (uint8, uint8) {
        return (treasure.row, treasure.col);
    }

    function getWinner() public view returns (address) {
        return winner;
    }
}