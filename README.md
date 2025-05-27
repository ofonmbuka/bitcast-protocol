# BitCast Protocol - The Bitcoin Oracle Prediction Market

**BitCast** is a decentralized Bitcoin price prediction market built on **Stacks Layer 2**, enabling STX holders to speculate on short-term BTC/USD price movements in a trust-minimized, oracle-resolved environment.

## Overview

* **Protocol Name:** BitCast
* **Network:** Stacks (Layer 2 for Bitcoin)
* **Core Utility:** Decentralized BTC price prediction markets
* **Token:** STX (Stacks native token)

## Summary

BitCast enables users to stake STX on whether Bitcoin’s price will go **up** or **down** in a given time window. Each market is a binary prediction contract that:

* Tracks market liquidity from both sides (`up` or `down`)
* Uses a trusted oracle to resolve outcomes
* Automatically distributes rewards to winners
* Charges a protocol fee from the winnings

Ideal for:

* Bitcoin maximalists
* DeFi traders seeking BTC exposure
* Builders leveraging BTC-native liquidity on Stacks

---

## Architecture

```txt
                        ┌────────────────────────┐
                        │    Contract Owner      │
                        │(Admin / DAO Multisig)  │
                        └───────┬────────────────┘
                                │
                                ▼
                 ┌──────────────────────────────┐
                 │      BitCast Smart Contract  │
                 │  (Stacks Clarity Language)   │
                 └────────────┬─────────────────┘
                              │
          ┌──────────────────┴────────────────────┐
          ▼                                       ▼
┌────────────────────┐             ┌────────────────────────┐
│   Prediction Users  │           │   Oracle Address        │
│ (Stake STX on up/down)│         │ (Resolves end-price)    │
└────────────────────┘             └────────────────────────┘

          ▲                                       ▲
          │                                       │
┌──────────────────────────┐      ┌────────────────────────────┐
│    Market & User Maps    │      │     Claim Winnings         │
│ - `markets`              │<─────│ - Calculates payouts       │
│ - `user-predictions`     │      │ - Transfers STX + fees     │
└──────────────────────────┘      └────────────────────────────┘
```

---

## Core Features

### ✅ Market Creation

* **Function:** `create-market`
* **Permissioned:** Admin-only
* **Details:** Initializes a new market with start price, start block, and end block

### ✅ Prediction Submission

* **Function:** `make-prediction`
* **Input:** `market-id`, `"up"` or `"down"`, `stake` amount
* **Validations:**

  * Market open
  * Stake >= minimum
  * Sufficient STX balance

### ✅ Market Resolution

* **Function:** `resolve-market`
* **Permissioned:** Oracle-only
* **Input:** Final BTC price from oracle

### ✅ Reward Claims

* **Function:** `claim-winnings`
* **Eligibility:** Winning side only, once per market
* **Process:**

  * Calculate proportional payout
  * Deduct protocol fee
  * Transfer rewards and fees

---

## Administrative Functions

| Function             | Purpose                                          |
| -------------------- | ------------------------------------------------ |
| `set-oracle-address` | Update trusted price oracle                      |
| `set-minimum-stake`  | Set minimum STX required to participate          |
| `set-fee-percentage` | Adjust protocol fee (max 100%)                   |
| `withdraw-fees`      | Admin can withdraw accumulated protocol earnings |

---

## Constants & Parameters

| Variable         | Description              | Default        |
| ---------------- | ------------------------ | -------------- |
| `minimum-stake`  | Minimum position size    | `1 STX`        |
| `fee-percentage` | Protocol fee on winnings | `2%`           |
| `oracle-address` | Trusted BTC/USD oracle   | `ST1PQ...GZGM` |
| `contract-owner` | Admin multisig address   | `tx-sender`    |

---

## Read-Only Functions

* `get-market`: Fetch details of a market by ID
* `get-user-prediction`: View user’s prediction in a market
* `get-contract-balance`: View total STX held by contract
* `get-protocol-info`: View protocol configuration

---

## Example Flow

1. **Admin** calls `create-market` for upcoming price window.
2. **Users** submit `make-prediction` with their stake and position.
3. **Oracle** posts final BTC price via `resolve-market`.
4. **Users** on winning side call `claim-winnings` to receive STX.
5. **Admin** may collect fees via `withdraw-fees`.

---

## Security Considerations

* **Oracle Risk:** Single oracle source—can be expanded to multisig or aggregated feed in future versions.
* **Immutability:** Parameters can be adjusted only by contract owner.
* **Funds Custody:** All STX staked are held by the contract until market resolution.

---

## Future Enhancements

* Multi-oracle aggregation or Chainlink support
* Support for dynamic resolution timeframes
* Integration with UI frontend for live prediction visualization
* NFT reward tiers for active users

---

## Built With

* [Stacks](https://www.stacks.co/) — Bitcoin L2 smart contracts
* [Clarity](https://docs.stacks.co/write-smart-contracts/clarity-language) — Secure, decidable smart contract language
* Oracle integration — Trusted BTC/USD price feed
