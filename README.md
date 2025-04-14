---

# ⚔️ Stacks PvP Battle Game

A simple, turn-based player-vs-player (PvP) battle game built with [Clarity](https://docs.stacks.co/docs/clarity-language) on the [Stacks blockchain](https://stacks.co). This smart contract allows two players to challenge each other, take alternating turns to attack, and win either by reducing their opponent's health or claiming victory via timeout.

---

## 🚀 Features

- ✅ Turn-based battle mechanics
- ✅ Dual-entry game state (for flexible lookup)
- ✅ Timeout-based forfeit system
- ✅ HP management and winner detection
- ✅ Modular, readable, and extensible codebase
- 🛠️ Easily extendable to include power-ups, special moves, or NFTs

---

## 🧱 Tech Stack

- **Language:** Clarity (smart contracts on Stacks)
- **Blockchain:** Stacks 2.0
- **Tools:** Clarity CLI, Clarinet (for testing)

---

## 🗂️ Contract Structure

| Section | Description |
|--------|-------------|
| `Constants` | Game values and error definitions |
| `Data Structures` | Game state map and block tracking |
| `Helper Functions` | Utility functions for logic reuse |
| `Core Game Logic` | Main game functions (start, attack, forfeit) |
| `Read-Only Functions` | View game state and turn info |
| `Future Extensions` | Placeholder comments for upcoming features |

---

## 🕹️ How It Works

### 1. Start a Game

```clojure
(start-game opponent)
```
- Initializes a new match.
- Stores game state for both player orders.

### 2. Attack or Counter-Attack

```clojure
(attack opponent)
(counter-attack opponent)
```
- Reduce opponent's HP.
- Automatically checks for victory.

### 3. Forfeit Game on Timeout

```clojure
(forfeit-game opponent)
```
- If the other player is inactive for `20` blocks, you win.

---

## 📖 Example Game Flow

```text
Player A starts a game with Player B ➝ Player A attacks ➝ Player B counter-attacks ➝ ...
If Player A doesn't respond in time ➝ Player B can forfeit and win.
```

---

## 🔍 Developer Guide

### Clone & Set Up

```bash
git clone https://github.com/your-username/stacks-pvp-game.git
cd stacks-pvp-game
```

### Install Clarinet

```bash
npm install -g @hirosystems/clarinet
```

### Run Tests

```bash
clarinet test
```

### Simulate Game

Use Clarinet console to test:

```bash
clarinet console
(contract-call? .battle-game start-game 'SP2...)
```

---

## 📁 Suggested Repository Structure

```
/contracts
  battle-game.clar      # Main contract
/tests
  battle-game_test.ts   # Test suite (if using Clarinet + Typescript)
/docs
  architecture.md       # Architecture decisions and diagrams
README.md
```

---

## 🔮 Future Enhancements

- 💥 Variable attack damage
- 🧙 Special moves / power-ups
- 🧾 Game stats & leaderboards
- 🖼️ NFT integration for avatars/weapons
- 📈 Analytics dashboard

---

## 👤 Author

**Oluwabunmi Ogunlana**  
Smart Contract Developer • Blockchain Enthusiast

---

## 📄 License

MIT License. Feel free to use, modify, and share.

---