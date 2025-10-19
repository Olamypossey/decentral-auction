# Decentralized Auction — Clarity Contract

Short description
A simple on-chain auction contract written in Clarity for the Stacks blockchain. Supports creating auctions, placing bids, and closing auctions. This repo contains the contract source at `contracts/decentral-auction.clar`.

Features
- Create auctions with a minimum bid and duration (block height).
- Place bids and track highest bidder and amount.
- Refund previous highest bidder when outbid.
- Close auction after end-block and transfer proceeds to the auction creator.
- Read-only views to query auction and highest bid.

Contract public functions
- create-auction (item-name (string-ascii 100), description (string-ascii 200), min-bid uint, duration uint) -> (ok id) | err
- place-bid (id uint) -> (ok "Bid placed successfully") | err
- close-auction (id uint) -> (ok { winner: principal, amount: uint }) | err
- get-auction (id uint) -> optional auction
- get-highest-bid (id uint) -> (ok { bidder: (optional principal), amount: uint }) | err
- get-total-auctions () -> uint

Prerequisites
- Node.js and npm (for Clarinet tooling)
- Clarinet (Hiro) for local compile/test: npm i -g @hirosystems/clarinet
- Stacks CLI / stacks.js (optional) for deployment and interaction with mainnet/testnet

Quick start (development)
1. Install Clarinet:
   npm install -g @hirosystems/clarinet

2. Compile and run tests:
   clarinet test

3. Open a local console to interact with the contract (after starting clarinet):
   clarinet console
   Then use the console to call contract functions / run scenarios.

Notes on current contract (important)
- The contract stores auctions in the `auctions` map and individual bids in the `bids` map.
- Be aware that STX transfers must be initiated correctly:
  - Bidders should send STX when calling `place-bid`. The contract must receive and hold STX or use the correct transfer semantics (as-contract) — review `stx-transfer?` usage.
- Top-level use of `tx-sender` (for `contract-owner`) is invalid in Clarity. Initialize owner via a var and set it in a post-deploy transaction, or use a pattern that sets owner during `init` or first call.
- `unwrap-panic` on optionals can fail at runtime. Prefer `match` on optionals to handle None cases safely.
- Consider changing `place-bid` to accept an explicit `amount` argument and to escrow STX into the contract on bid placement (so refunds and final payouts are secure).

Common error codes
- ERR_UNAUTHORIZED (u100) — caller not authorized to perform action
- ERR_AUCTION_NOT_FOUND (u101) — auction id not found
- ERR_ALREADY_ENDED (u102) — auction already closed/ended
- ERR_AUCTION_NOT_ENDED (u103) — auction end-block not reached
- ERR_LOW_BID (u104) — bid is below min or highest bid
- ERR_SELF_BID (u105) — creator bidding on own auction (if enforced)

Security & best practices
- Ensure the contract receives STX when bids are placed (accept amount parameter and use `stx-transfer?` from the bidder to the contract).
- Avoid unsafe unwraps; use `match` for optionals and `ok/error` checks for transfers.
- Initialize contract owner via a mutable var set in a controlled transaction after deployment.
- Add tests covering edge cases: simultaneous bids, refunds, unauthorized closures, and zero/low bids.

Contributing
- Create issues or PRs. Include tests for any bug fix or feature.
- Follow Clarity and Clarinet conventions for tests and deployment scripts.

Contact
For questions or help with this repo, open an issue.
