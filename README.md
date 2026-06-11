# Treasure Hunt

A fully on-chain, multiplayer treasure hunt on a 10x10 grid, where the prize moves as players chase it.

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636?logo=solidity&logoColor=white)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FE5421)
![License](https://img.shields.io/badge/License-Unlicense-blue)

## Overview

Treasure Hunt is a Solidity smart contract game built and tested with Foundry. Players join by paying an ETH fee, then take turns walking one cell at a time across a 10x10 grid. A hidden treasure sits somewhere on that grid, and the goal is simple: step onto the treasure's cell to win.

The twist is that the treasure is not static. Every player move can nudge or teleport the treasure based on deterministic on-chain rules, so the target keeps shifting as the hunt unfolds. All game state lives on-chain and is derived purely from chain data (`block.number`, `block.timestamp`, and `blockhash`), which keeps the game transparent and reproducible from the chain's history.

The first player to land on the treasure's cell takes 90% of the contract balance as the prize, while the remaining 10% stays in the contract as a reserve.

## Contract

Source: [`src/TreasureHunt.sol`](src/TreasureHunt.sol). Built on OpenZeppelin's `Ownable` for owner-gated funds management.

### State

- `playerPos` (public mapping `address` to `Position`): each player's `(row, col)` on the grid.
- `treasure` (private `Position`): the hidden target cell, set at deployment and updated as the game runs.
- `winner` (public `address`): the address that last landed on the treasure.
- `joinFee` (uint256): ETH required to join, fixed at deployment.

### Functions

- `constructor(uint256 _joinFee) payable` deploys the contract, sets the owner to the deployer, requires a non-zero `_joinFee` and a non-zero initial ETH reserve, and seeds the treasure position from `block.number`, `block.timestamp`, and the previous block hash.
- `joinGame() external payable` joins the game on payment of at least `joinFee`, then assigns the caller a pseudo-random starting cell derived from their address.
- `move(uint8 nextRow, uint8 nextCol) external` moves the caller one adjacent cell (up, down, left, or right). It rejects out-of-bounds or non-adjacent moves, updates the caller's position, and either declares them the winner (if the new cell holds the treasure) or relocates the treasure.
- `getTreasure() public view returns (uint8, uint8)` returns the treasure's current `(row, col)`.
- `getWinner() public view returns (address)` returns the current winner address.
- `withdraw() external onlyOwner` lets the owner withdraw the contract's remaining balance.

Internal helpers: `isValidMove` (bounds and adjacency check), `moveTreasure` (applies the treasure rules), `moveToAdjacent` (shifts the treasure one random cell), `moveToRandom` (teleports the treasure), `declareWinner` (pays out and re-seeds), and `isPrime` (primality test used by the treasure rules).

### Events

- `PlayerMoved(address indexed player, uint8 row, uint8 col)`
- `WinnerDeclared(address indexed player, uint256 reward)`

A front end can reconstruct game progress by subscribing to these events alongside the public getters.

## How the hunt works

1. **Deploy.** The contract is deployed with a `joinFee` and an initial ETH reserve. The treasure's starting cell is seeded from on-chain values.
2. **Join.** A player calls `joinGame()` with at least `joinFee` in ETH and is placed at a pseudo-random starting cell keyed to their address and the current block.
3. **Move.** A player calls `move(nextRow, nextCol)` to step to an adjacent cell. The move is rejected unless the target cell is in bounds and exactly one step away (horizontally or vertically, not diagonally).
4. **Check for a win first.** If the player's new cell matches the treasure's cell, the game immediately declares them the winner and pays out. No treasure movement happens on a winning move.
5. **Otherwise, move the treasure.** The contract converts the player's new cell to an index `pos = row * 10 + col`, then applies two rules:
   - If `pos` is a multiple of 5, the treasure shifts one cell in a pseudo-random direction (it stays put if that direction would push it off the grid edge).
   - If `pos` is a prime number, the treasure teleports to a fresh pseudo-random cell.
   Both rules can apply on the same move.
6. **Payout.** On a win, the winner receives 90% of the contract balance and 10% remains as reserve. The treasure is re-seeded so play can continue.

The owner can reclaim leftover funds with `withdraw()`.

### Notes on randomness and limitations

Randomness comes entirely from `keccak256` over `block.timestamp`, `block.number`, and `blockhash(block.number - 1)`. This is deterministic and transparent, which is good for verifiability and easy testing, but it is not secure against an actor who can influence block timing or transaction ordering. A production version would swap in a verifiable source such as Chainlink VRF or a commit-reveal scheme.

The contract is a learning and portfolio project. One known quirk worth flagging: `joinGame()` treats a stored position of `(0, 0)` as "not joined", and `move` does not require prior registration, so the cell at index 0 is a special case. These are intentional rough edges left visible rather than papered over.

## Tech stack

- **Solidity** `^0.8.20`
- **Foundry** (`forge`) for building, testing, and gas reporting
- **OpenZeppelin Contracts** (`Ownable`) for ownership and fund withdrawal

## Getting started

### Prerequisites

Install Foundry by following the [official guide](https://book.getfoundry.sh/getting-started/installation).

### Install dependencies

```bash
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

## Testing

Tests live in [`test/treasureHunt.t.sol`](test/treasureHunt.t.sol) and use Foundry's cheatcodes (`vm.deal`, `vm.prank`) to fund and impersonate players against a freshly deployed contract.

| Test | What it checks |
| --- | --- |
| `testJoinGame` | A player who pays the join fee is assigned a valid starting cell, with `row` and `col` both inside `[0, 9]`. |
| `testMove` | A joined player can step to an adjacent cell, and `playerPos` reflects the new coordinates. |
| `testMoveTreasure` | A join-then-move sequence runs end to end without reverting, exercising the treasure-movement path. |

Run with a gas report:

```bash
forge test --gas-report
```

Measure coverage:

```bash
forge coverage
```

Suggested areas to extend coverage: grid-boundary moves (rows and columns at 0 and 9), prime detection around small values, multiple players joining and moving, and the full winner path with payout and balance assertions.

## Author

Krish Ojha
