# TreasureHunt — On-chain Treasure Hunt Game (Foundry + Solidity)

A small on-chain game where multiple players move on a 10×10 grid trying to find a hidden treasure.
The treasure moves dynamically based on player moves and simple deterministic rules so the game is **provably fair** (within the limits of on-chain randomness from `blockhash`).

---

## 🔖 Quick summary

- Grid: `10 x 10` (positions `0`..`99`), players have `(row, col)` coordinates.
- Players join by paying an ETH `joinFee` (configurable at deployment).
- Each player may move once per turn to an **adjacent** cell (up/down/left/right).
- Treasure:
  - Initially seeded with `keccak256(block.number, block.timestamp)` and `blockhash(block.number - 1)`.
  - Moves whenever a player moves according to:
    - If the player's new position (index = `row * 10 + col`) is **multiple of 5**, the treasure moves to a random **adjacent** cell.
    - If the player's new position is a **prime** number, the treasure teleports to a new random position on the grid.
  - Duplicate numbers and repeated draws have no extra effect.
- Winning: If a player moves to the cell where the treasure is located, they immediately win:
  - Winner receives **90%** of the contract balance.
  - **10%** remains in contract as reserve for future rounds.
- Owner functions:
  - `withdraw()` to withdraw leftover funds (onlyOwner).
  - (Owner is set at construction using `Ownable`).

---

## ⚙️ How randomness is handled (design notes)

- **On-chain determinism** is used: `keccak256` + `blockhash(block.number - 1)` and `block.timestamp` are the entropy sources.
  - Example seed: `uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) % 10)`
- This is **not** secure against a miner who can influence `block.timestamp` or which transactions get included — but for the assignment and low-stakes testnets it is acceptable and transparent.
- For production-grade fairness you would replace with a verifiable RNG (e.g., Chainlink VRF or commit-reveal).
- The contract uses `blockhash(block.number - 1)` to avoid `blockhash(block.number)` correctness pitfalls.

---

## ✅ Why this design

- Simplicity: grid operations are O(1) per move. Treasure moves are inexpensive (constant work).
- Deterministic: every move and treasure update is on-chain and reproducible given the chain history.
- Frontend friendly: all game state (player positions, treasure pos, winner) is readable via public getters.
- Testability: Foundry tests can warp time and simulate moves deterministically.

---

## 🔍 Public API & events

### Core functions
- `constructor(uint256 _joinFee) payable` — deploy with initial ETH reserve and required join fee.
- `joinGame()` payable — join the game by paying `joinFee` (assigns player a random starting position).
- `move(uint8 nextRow, uint8 nextCol)` — move one step to an adjacent cell; triggers treasure move and winner check.
- `getTreasure() public view returns (uint8, uint8)` — returns treasure coordinates.
- `playerPos(address) public view returns (uint8 row, uint8 col)` — player position mapping (public).
- `getWinner() public view returns (address)` — returns current winner (if any).
- `withdraw()` onlyOwner — withdraw contract funds (leftover / reserve).

### Events
- `PlayerMoved(address indexed player, uint8 row, uint8 col)`
- `WinnerDeclared(address indexed player, uint256 reward)`

These allow a frontend to reconstruct game state by subscribing to events.

---

## 🧪 Tests (Foundry)

Included test file: `test/TreasureHuntsTest.t.sol` with tests for:

- `testJoinGame` — join assigns valid random position in `[0..9]` for both row & col.
- `testMove` — players can move to adjacent cells and state updates.
- `testMoveTreasure` — a basic test that triggers treasure movement (validate invariants manually or via assertions).

**Run tests:**

```bash
forge test
```

Run tests with gas report:
```bash
forge test --gas-report
```

Coverage:
```bash
forge coverage
```

- Aim for strong coverage; add tests for edge cases:

- Moving at grid bounds (0 and 9)

- Prime detection around small numbers (2,3,5,7,11,...)

- Multiple players joining and moving

- Winner path and payout correctness (including balance checks)

---

## 🛠 Build / Run / Deploy

### Prerequisites

- Install Foundry: https://book.getfoundry.sh/getting-started/installation

### Build
```bash
forge build
```

### Test
```bash
forge test
```


## Gas & Complexity (worst-case notes)

- ```joinGame()```

  - Executes a few ```keccak256``` calls and assigns ```playerPos```.

  - Cost: moderate (constant).

- ```move()```

  - Validates adjacency (constant checks) and updates player mapping.

  - Calls ```moveTreasure()``` which can call ```moveToAdjacent()``` or ```moveToRandom()``` — constant work.

  - Emits events. Overall constant gas per move.

- ```moveToAdjacent()``` / ```moveToRandom()```:

  - Constant cost (few SLOAD/SSTORE + keccak calls).

- Worst-case per block: no heavy loops over players in current design → gas is bounded per call.

Note: The contract stores players by mapping, not an array, so it's cheap per-player. If you later add arrays to iterate over players, costs would increase with player count.
