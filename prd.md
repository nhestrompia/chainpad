PRD — Crypto Scratchpad (macOS Menu Bar App)

1. Overview

Crypto Scratchpad is a lightweight macOS menu bar utility that automatically captures crypto-related objects users interact with—such as token contracts, wallet addresses, transaction hashes, and explorer links—and converts them into enriched, actionable objects.

Instead of storing raw clipboard strings, the app detects the object type, determines the chain when possible, fetches metadata (e.g., token liquidity, wallet balances, transaction summaries), and stores the result in a temporary scratchpad session accessible from the macOS menu bar.

The product acts as a context memory layer for crypto workflows, helping users track tokens, wallets, and transactions encountered across apps such as Telegram, Discord, browsers, and explorers.

Users can search captured items, pin important objects, and trigger quick actions such as opening charts, explorers, scanners, or swap pages directly from the scratchpad.

⸻

2. Problem

Crypto users constantly copy and paste blockchain identifiers while navigating across multiple tools:
• Telegram / Discord
• browsers
• block explorers
• scanners
• trading interfaces
• social feeds

Common copied items include:
• token contract addresses
• wallet addresses
• transaction hashes
• token pair links
• explorer URLs

However, current workflows suffer from:
• loss of context after copying
• difficulty remembering where an address came from
• repetitive searching across tools
• fragmented research sessions
• lack of cross-app memory for crypto objects

Traditional clipboard history tools only store raw strings, offering no context or enrichment.

⸻

3. Goals

Primary goals:
• Automatically capture crypto objects copied by the user
• Convert raw clipboard strings into contextual crypto objects
• Provide a temporary workspace for research sessions
• Allow users to quickly revisit recently copied crypto objects
• Enable quick navigation to charts, explorers, and trading pages

Secondary goals:
• Provide chain-aware quick actions
• Maintain a searchable history of captured crypto objects
• Allow pinning of frequently used tokens or wallets

⸻

4. Non-Goals (MVP)

The initial version will not attempt to replace existing crypto tools.

Excluded features:
• portfolio tracking
• price monitoring dashboards
• executing transactions
• wallet management
• trading interfaces
• complex analytics

Crypto Scratchpad is a context memory and navigation tool, not a trading terminal.

⸻

5. Target Users

Primary users:
• crypto traders
• memecoin traders
• on-chain researchers
• crypto developers

Secondary users:
• NFT traders
• DeFi users
• analysts tracking wallets or tokens

Typical behavior:

Users frequently copy crypto identifiers from messaging apps, browsers, or explorers while investigating tokens or transactions.

⸻

6. Product Concept

Crypto Scratchpad runs in the macOS menu bar and automatically builds a session stack of crypto objects encountered during a user’s workflow.

Example captured session:

Session Stack

BONK Token
Wallet 7xK...
Transaction 0x82f...
SOL/BONK Pair

Each item contains:
• metadata
• contextual information
• quick action buttons

Users can quickly reopen relevant tools without searching again.

⸻

7. Platform

macOS menu bar application.

Recommended stack:
• Swift + SwiftUI
• NSPasteboard clipboard monitoring
• SwiftData or SQLite for local storage
• external APIs for metadata enrichment

The app runs as a background utility.

⸻

8. Core Features

8.1 Clipboard Detection

The app listens for clipboard changes using macOS pasteboard APIs.

Detected object types include:
• EVM contract addresses
• Solana addresses
• transaction hashes
• explorer URLs
• token pair links

Example copied item:

0xabc123...

The app identifies it as a potential EVM address and runs validation checks.

⸻

8.2 Validation Pipeline

To prevent noise from random strings, each detected object must pass a validation step.

Detection pipeline:

Clipboard Event
↓
Regex Detection
↓
Prober Validation
↓
Valid → Add to Stack
Invalid → Ignore

Validation methods may include:
• DexScreener search
• RPC contract detection
• explorer lookup
• token metadata queries

⸻

8.3 Object Classification

Detected items are classified into one of the following categories:
• Token contract
• Wallet address
• Transaction hash
• Liquidity pair
• Explorer link

Example classification:

Token
BONK
Chain: Solana

⸻

8.4 Metadata Enrichment

Once validated, the app fetches metadata.

Example metadata:

Token
• name
• symbol
• price
• liquidity
• market cap
• token age

Wallet
• balance
• transaction count
• known labels (if available)

Transaction
• tokens transferred
• swap details
• block confirmation

The enriched object becomes a structured card in the scratchpad.

⸻

8.5 Session Stack

All captured objects are stored in a temporary session stack.

Menu bar icon displays item count:

📌 3

Opening the panel shows:

Session

BONK Token
Wallet 7xK...
Tx 0x8f...

Session stack behavior:
• items ordered by recency
• duplicates moved to top instead of re-added
• automatically cleared after inactivity

⸻

8.6 Deduplication

If the same object is copied multiple times:
• the existing entry is moved to the top
• metadata is refreshed

Example:

Before
Wallet A
BONK
Tx

Copy BONK again

After
BONK
Wallet A
Tx

⸻

8.7 Source Tagging

The app records which application was active during the copy event.

Example metadata:

BONK
Copied from Telegram
10:43

This helps users remember where the object originated.

⸻

8.8 Quick Actions

Each object card includes quick actions.

Example token card:

BONK
Liquidity $2.1M
Age 4 days

Actions:
Chart
Swap
Explorer
Bubblemaps
Copy
Pin

Actions open external tools.

⸻

8.9 Deep Link Integrations

Instead of building trading interfaces, the app uses deep links.

Examples:

Solana

https://jup.ag/swap/SOL-{token}

Ethereum / EVM

https://app.uniswap.org/#/swap?outputCurrency={token}

This allows instant trading access while keeping the app lightweight.

⸻

8.10 Search

Users can search across captured objects.

Example:

Search scratchpad

Search results include:
• tokens
• wallets
• transactions
• pinned items

Searchable attributes include:
• address
• token name
• symbol
• chain

⸻

8.11 Pinning

Users can pin important objects.

Pinned items appear in a separate section:

Pinned

BONK
Deployer Wallet
LP Pair

Pinned objects persist across sessions.

⸻

9. UI

Menu Bar Icon

Icon indicates number of items captured.

Examples:

📌
📌 3
📌 7

⸻

Menu Bar Panel Layout

Clicking the icon opens the panel.

Example layout:

Search

Session
BONK
Wallet 7xK...
Tx 0x8f...

Pinned
BONK
Wallet

⸻

Object Cards

Each object appears as a compact card.

Example:

BONK
Solana
Liquidity $2.1M

[Chart] [Swap] [Explorer]

⸻

10. Data Storage

Local storage only.

Possible solutions:
• SwiftData
• SQLite

Stored data:
• captured objects
• metadata
• pinned items
• timestamps
• source application

Session items may expire automatically.

⸻

11. Security & Privacy

The app does not:
• store private keys
• access wallet permissions
• monitor sensitive clipboard content

Optional features:
• pause capture toggle
• blacklist certain applications
• manual session clearing

⸻

12. MVP Scope

Included:
• clipboard detection
• validation pipeline
• object classification
• metadata enrichment
• session stack
• search
• pinning
• quick actions

Excluded:
• wallet tracking
• portfolio monitoring
• automated alerts
• trading execution

⸻

13. Future Enhancements

Possible future features:
• relationship detection (token → deployer wallet → LP)
• wallet activity tracking
• timeline view of research sessions
• tagging and labeling
• chain risk indicators
• integration with scanners and analytics tools

⸻

14. Success Metrics

Key product metrics:
• daily active users
• number of objects captured per session
• quick action usage rate
• pinned object usage
• repeat session retention

⸻

15. Product Positioning

Crypto Scratchpad is best described as:

A contextual memory layer for crypto workflows.

It automatically captures, enriches, and organizes tokens, wallets, and transactions encountered during research, allowing users to quickly revisit and act on crypto objects across apps without repeated searching or copy-paste friction.
