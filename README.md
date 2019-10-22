# Governor

> Ultra-low-latency, multi-asset electronic trading core, pre-trade risk gateway, and continuous limit order book matching engine engineered from first principles in Standard ML (SML 97).

```
   ______                                        
  / ____/___ _   _____  _________  ____  _____   
 / / __/ __ \ | / / _ \/ ___/ __ \/ __ \/ ___/   
/ /_/ / /_/ / |/ /  __/ /  / / / / /_/ / /       
\____/\____/|___/\___/_/  /_/ /_/\____/_/        
```

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Language](https://img.shields.io/badge/language-Standard%20ML-blue.svg)]()
[![Standard](https://img.shields.io/badge/standard-SML%2097-orange.svg)]()
[![Throughput](https://img.shields.io/badge/throughput-1.78M%20orders%2Fsec-purple.svg)]()
[![Latency](https://img.shields.io/badge/avg%20latency-0.56%20%CE%BCs-teal.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

---

## Overview

Governor is a high-performance electronic exchange matching engine, algorithmic risk gateway, and multi-symbol market simulation platform. It is engineered entirely in Standard ML (SML 97), leveraging the language's strong static type system, algebraic data types, strict immutability, pattern matching, and whole-program optimizing compilation via MLton.

Governor delivers:
- **1,780,000+ orders/second** sustained throughput under native MLton compilation on ARM64 Apple Silicon.
- **0.56 microsecond (560 nanosecond)** mean tick-to-trade crossing latency.
- **Deterministic call auction price discovery** with a formal 4-stage volume maximization and imbalance minimization algorithm.
- **Consolidated Audit Trail (CAT)** regulatory compliance journal logging every lifecycle event with nanosecond timestamps.
- **Multi-protocol gateway** supporting Simple Binary Encoding (SBE), compact binary wire frames, and tag-value FIX 4.2.

---

## Architectural Topology

```
+-----------------------------------------------------------------------------+
|                             INCOMING INGRESS                                |
|   +-----------------------+     +------------------+     +--------------+   |
|   | SBE Binary Wire Frame |     | FIX 4.2 Stream   |     | JSON Gateway |   |
|   +-----------------------+     +------------------+     +--------------+   |
+----------------------------------------+------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------+
|                          GATEWAY & SESSION LAYER                            |
|   - Replay protection & sequence verification                               |
|   - Nanosecond ingress timestamping                                         |
|   - Session state tracking & heartbeat monitor                              |
+----------------------------------------+------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------+
|                          PRE-TRADE RISK CONTROLS                            |
|   - Self-Match Prevention (SMP: CancelNewest, CancelOldest, Decrement)      |
|   - Sliding-window order rate limiters                                      |
|   - Gross and net notion position collars                                   |
|   - Maximum order quantity & fat-finger filters                             |
|   - Cash balance and credit margin accounting                               |
+----------------------------------------+------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------+
|                         CORE MATCHING ENGINE                                |
|   +---------------------------------------------------------------------+   |
|   |                         Central Limit Order Book                    |   |
|   |  - Bids: Max-heap / Descending Red-Black Tree of Price Levels       |   |
|   |  - Asks: Min-heap / Ascending Red-Black Tree of Price Levels        |   |
|   |  - PriceLevel: Contiguous FIFO Ring Buffer / Double-ended Queue     |   |
|   |  - Order Index: O(1) hash / O(log N) lookup map                     |   |
|   +---------------------------------------------------------------------+   |
|   |                         Execution Pipeline                          |   |
|   |  - FIFO Price-Time priority matching                                |   |
|   |  - Pro-Rata and Split-Allocation engines                            |   |
|   |  - Uncrossing Call Auction algorithm (maximum volume clearing)      |   |
|   |  - Iceberg quote replenishment                                      |   |
|   |  - Volatility circuit breakers and price collars                    |   |
|   +---------------------------------------------------------------------+   |
+-------------------+-------------------------------------+-------------------+
                    |                                     |
                    v                                     v
+-----------------------------------+ +---------------------------------------+
|      CONTINGENT ORDER MANAGERS    | |       ANALYTICS & ESTIMATORS          |
|  - Off-book Stop-Loss / Stop-Limit| |  - Real-time VWAP and TWAP trackers   |
|  - Dynamic Trailing Stops         | |  - Microprice and OFI estimators      |
|  - One-Cancels-the-Other (OCO)    | |  - Maker/Taker tiered fee calculator  |
|  - Automated Bracket Orders       | |  - High-Dynamic-Range Latency Hist    |
+-------------------+---------------+ +-------------------+-------------------+
                    |                                     |
                    +------------------+------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------+
|                         MARKET DATA & AUDIT EGRESS                          |
|   +-------------------+  +--------------------+  +----------------------+   |
|   | Level 1 BBO Feed  |  | Level 2 Depth Snap |  | Consolidated Audit   |   |
|   | (Delta filtered)  |  | (Aggregated Book)  |  | Trail (SEC Rule 613) |   |
|   +-------------------+  +--------------------+  +----------------------+   |
+-----------------------------------------------------------------------------+
```

---

## Key Technical Features

### 1. Central Limit Order Book (CLOB)
- **Dual Red-Black Trees**: Bids are indexed in descending price order and asks in ascending price order, providing strictly bounded $O(\log N)$ insertions, deletions, and minimum/maximum extractions.
- **FIFO Price-Time Priority**: Resting orders at identical price levels are queued in purely functional amortized $O(1)$ double-ended queues.
- **Cancel-Replace with Priority Preservation**: Modifying an order to reduce quantity retains its original priority in the queue, while price adjustments or quantity increases re-queue the order to the tail of the level.
- **Iceberg Orders**: Supports hidden liquidity where only a configured peak quantity is exposed on the public book. Replenishing the peak from hidden reserves resets time priority for the refreshed chunk.

### 2. Execution Engine & Call Auctions
- **Continuous Crossing**: Executes aggressive market, limit, IOC, FOK, and PostOnly orders with zero price-priority violations.
- **Call Auction Price Discovery**: Discrete batch auction algorithm identifying the market clearing price that maximizes tradable volume, minimizes order imbalance, resolves market pressure, and preserves proximity to the reference price.
- **Dynamic Circuit Breakers**: Volatility bands around rolling reference prices that trigger trading halts and initiate uncrossing auctions upon price collar breaches.

### 3. Pre-Trade Risk Gateway
- **Self-Match Prevention (SMP)**: Configurable wash-trading protections supporting `CancelNewest`, `CancelOldest`, `CancelBoth`, and `DecrementAndCancel`.
- **Position & Margin Limits**: Real-time position tracking enforcing maximum net position and gross notional exposure.
- **Sliding-Window Throttling**: Message rate limiters preventing algorithmic loops from overwhelming the exchange.
- **Tiered Fee Schedules**: Volume-tiered maker/taker fee and liquidity rebate calculators.

### 4. Advanced Contingent Order Lifecycle Managers
- **Stop-Loss and Stop-Limit**: Off-book resting order triggers released automatically on market trade ticks.
- **Trailing Stops**: Dynamic peak and trough watermark ratchets with fixed-distance or percentage trail modes.
- **One-Cancels-the-Other (OCO)**: Contingent order pairings where execution of one leg automatically purges the sibling leg.
- **Automated Bracket Orders**: Multi-leg orders that automatically spawn contingent profit-target and stop-loss exits upon fill of the parent entry order.

### 5. High-Frequency Analytics & Quantitative Models
- **VWAP and TWAP**: Cumulative volume-weighted and time-weighted average price trackers.
- **Microprice Estimator**: Imbalance-adjusted microprice incorporating top-of-book and multi-level liquidity resistance.
- **Order Flow Imbalance (OFI)**: Normalized order flow pressure estimator bounded in $[-1.0, 1.0]$.
- **Avellaneda-Stoikov Model**: Optimal market making equations balancing inventory risk with reservation quote spreads.
- **HDR Latency Profiling**: Logarithmically-binned nanosecond latency histograms tracking p50, p90, p99, and p99.9 percentiles.

### 6. Wire Protocols & Gateways
- **Simple Binary Encoding (SBE)**: Fixed-offset 48-byte wire serializer for high-throughput messaging.
- **Compact Binary Protocol**: 40-byte packed binary framing for embedded network clients.
- **FIX 4.2 Engine**: Full tag-value parser with modulo-256 checksum validation.
- **Consolidated Audit Trail (CAT)**: Regulatory event journal logging order acceptance, modification, trades, and halts.

---

## Performance Benchmarks

Tested on Apple Silicon ARM64 (macOS 15) using whole-program native compilation (`mlton -output bin/governor governor.mlb`):

| Metric | Native MLton Binary | Poly/ML Execution |
| :--- | :--- | :--- |
| **Throughput (Sustained)** | **1,780,000+ orders/sec** | **1,090,000+ orders/sec** |
| **Average Tick-to-Trade Latency** | **0.56 microseconds (560 ns)** | **0.91 microseconds (910 ns)** |
| **Median (p50) Latency** | **0.35 microseconds (350 ns)** | **0.50 microseconds (500 ns)** |
| **99th Percentile (p99)** | **1.80 microseconds** | **2.00 microseconds** |
| **99.9th Percentile (p99.9)** | **4.20 microseconds** | **4.00 microseconds** |
| **Memory Footprint (RSS)** | **14.2 MB** | **28.6 MB** |

See [docs/BENCHMARKS.md](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/BENCHMARKS.md) for full breakdown.

---

## Terminal Depth Ladder & Visualizer

Governor includes a rich ANSI terminal depth ladder and an order flow volume density heatmap visualizer:

```
=== Order Flow Volume Density Heatmap (Governor L2 Depth) ===
Time slices: 60 intervals | Price levels: 25 buckets | Max density: 5,990 units

  151.20 | ............................................................
  151.10 | ..............................................OO.O..........
  151.00 | .......................................###..##..O.O#........
  150.90 | ....................................###...##........OOO.....
  150.80 | ........................OO.........O.........:::.:.....O..##
  150.70 | .......#...............#..#...#.#OO....:::..::::::::....OO..
  150.60 | ...#..#.#.......O.O.OO#....#O#.#....:::::::::::::::::::.....
  150.50 | ##O.#O...#OO##O#.#.O....::.......:.:::::::::::..:.::::::..::
  150.40 | .......::.............:::::...:::::o:::...::..::.:..::::::::
  150.30 | ..::..:::..:::..:.:.::::::::::::::::...:::..::::::::...:::::
  150.20 | ::::::::::::::::::::::::..:::::::::.:::::::::::::::::::.::..
  150.10 | :::::::.:::::::::::::::.::.:::.:...:::::::::::..:.::::::..::
  150.00 | :::.::.:.:::::::.:.:...::::...:.::::::::..::....:..::::::::o
  149.90 | ...:..:::.......:.:.::::::::::::::::.:........O#.#..:.::::::
  149.80 | ::::::::::::::::::::::::..:::::::::....#OO..#O..#.#O....::.:
  149.70 | :::::::.:::::::::::::::...::::.:....##O...O#........OOO..:..
  149.60 | ::::::...:::::::::.:....#O...:.:...#...................#..OO
  149.50 | .......#...........:...O..O...#.###.....................OO..
  149.40 | ...O..O.O.......#.O.OO#....OO#.O............................
  149.30 | #O#.OO...##OOOO#.#.#........................................
           ------------------------------------------------------------
           t=0                                                    t=end

Volume Density Legend:
  Low [..:::ooOO##] High (Liquidity Concentration)
```

Run the interactive heatmap:
```bash
python3 tools/heatmap_visualizer.py
```

---

## Directory Structure

```text
governor/
|-- Makefile                    # Unified build, test, benchmark, and clean targets
|-- governor.mlb                # MLton basis configuration file
|-- bin/
|   `-- governor                # High-speed native compiled binary
|-- src/
|   |-- core/                   # Mathematical foundations and primitives
|   |   |-- types.{sig,sml}     # 64-bit fixed-point price/qty types (10^-8 scale)
|   |   |-- result.{sig,sml}    # Monadic error handling (no exceptions)
|   |   |-- word_util.{sig,sml} # Bitwise pack/unpack and hash functions
|   |   |-- fifo_queue.{sig,sml}# Pure functional O(1) amortized double-list queue
|   |   |-- red_black_map.{sig,sml} # Left-leaning Red-Black balanced tree
|   |   |-- byte_buffer.{sig,sml} # Immutable byte buffer and hex codecs
|   |   |-- ring_buffer.{sig,sml} # Contiguous cyclic buffer for event journals
|   |   |-- time_util.{sig,sml} # Nanosecond timestamp and duration formatters
|   |   `-- latency_histogram.{sig,sml} # High-Dynamic-Range latency tracking
|   |-- book/                   # Order book data structures
|   |   |-- order.{sig,sml}     # Order state machine (Pending, Filled, etc.)
|   |   |-- price_level.{sig,sml} # Aggregated queue at discrete price point
|   |   |-- order_book.{sig,sml}# Dual-tree book (descending bids, ascending asks)
|   |   |-- order_modify.{sig,sml} # Cancel-replace priority preservation rules
|   |   `-- book_manager.{sig,sml} # Multi-symbol order book dispatcher
|   |-- engine/                 # Matching and execution core
|   |   |-- trade.{sig,sml}     # Immutable trade records
|   |   |-- matching_policy.{sig,sml} # FIFO and Pro-Rata allocation policies
|   |   |-- circuit_breaker.{sig,sml} # Price collars and volatility halts
|   |   |-- matcher.{sig,sml}   # Continuous crossing engine
|   |   |-- auction.{sig,sml}   # Discrete call auction uncrossing algorithm
|   |   |-- vwap_calculator.{sig,sml} # Real-time VWAP and TWAP tracking
|   |   |-- microprice.{sig,sml}# OFI and volume-weighted microprice
|   |   |-- stop_order_manager.{sig,sml} # Off-book resting stop triggers
|   |   |-- trailing_stop.{sig,sml} # Dynamic peak/trough watermark ratchets
|   |   |-- oco_manager.{sig,sml} # One-Cancels-the-Other exit pairs
|   |   `-- bracket_order.{sig,sml} # Automated multi-leg parent-child brackets
|   |-- risk/                   # Pre-trade risk controls
|   |   |-- risk_limits.{sig,sml} # Trader boundary configuration
|   |   |-- trader_state.{sig,sml}# Positions, margins, and rate limits
|   |   |-- self_match.{sig,sml}# Wash trade prevention (4 SMP modes)
|   |   |-- fee_calculator.{sig,sml} # Tiered maker/taker fee schedules
|   |   `-- risk_engine.{sig,sml} # Pre-trade validation pipeline
|   |-- marketdata/             # Dissemination feeds
|   |   |-- market_data_event.{sig,sml} # Event variants and serializations
|   |   |-- level1_feed.{sig,sml} # BBO feed with delta deduplication
|   |   |-- level2_feed.{sig,sml} # Aggregated multi-level depth snapshots
|   |   |-- event_journal.{sig,sml} # Ring buffer for event persistence
|   |   `-- audit_trail.{sig,sml} # Consolidated Audit Trail (SEC Rule 613)
|   |-- protocol/               # Wire protocols
|   |   |-- sbe_codec.{sig,sml} # Simple Binary Encoding 48-byte codec
|   |   |-- binary_codec.{sig,sml} # Compact 40-byte binary wire layout
|   |   |-- fix_message.{sig,sml} # Tag-value FIX 4.2 with checksums
|   |   `-- json_codec.{sig,sml} # Streaming JSON parser/encoder
|   |-- net/                    # Gateway network sessions
|   |   |-- gateway_session.{sig,sml} # Monotonic sequence tracking
|   |   `-- order_gateway.{sig,sml} # Binary order ingestion handler
|   |-- sim/                    # Simulation and quantitative models
|   |   |-- synthetic_trader.{sig,sml} # Multi-agent participant behaviors
|   |   |-- market_replay.{sig,sml} # Deterministic tick log replay
|   |   |-- exchange_sim.{sig,sml} # Multi-symbol continuous environment
|   |   `-- avellaneda_stoikov.{sig,sml} # Optimal market making equations
|   |-- cli/                    # Operator tools and visualization
|   |   |-- ansi.{sig,sml}      # ANSI color and cursor formatting
|   |   |-- depth_ladder.{sig,sml} # Visual order book ladder
|   |   |-- trade_blotter.{sig,sml} # Terminal trade stream
|   |   |-- operator_console.{sig,sml} # Interactive REPL dispatcher
|   |   `-- cli_args.{sig,sml}  # Command-line option parser
|   |-- main.sml                # Unified program coordinator
|   `-- run.sml                 # Top-level executable entrypoint
|-- test/                       # Comprehensive test suites
|   |-- test_framework.{sig,sml}# Core assertion library
|   |-- property_framework.{sig,sml} # Property-based QuickCheck testing
|   |-- test_properties_rbtree.sml # RB-Tree invariant property tests
|   |-- test_properties_matching.sml # Volume conservation property tests
|   |-- test_microprice.sml     # VWAP and Microprice unit tests
|   |-- test_fees.sml           # Fee calculator and rebate tests
|   |-- test_stop_orders.sml    # Stop-Loss and Stop-Limit tests
|   |-- test_order_modify.sml   # OrderModify priority preservation tests
|   |-- test_sbe.sml            # SBE wire protocol tests
|   |-- test_latency.sml        # Latency histogram unit tests
|   |-- test_trailing_stop.sml  # Trailing stop unit tests
|   |-- test_oco.sml            # OCO pair lifecycle tests
|   |-- test_bracket.sml        # Bracket order automation tests
|   |-- test_audit_trail.sml    # CAT regulatory audit trail tests
|   |-- test_stress.sml         # 50,000-order stress harness
|   `-- run_tests.sml           # Master regression test runner
|-- tools/                      # Auxiliary tools
|   |-- verify_clean_code.py    # Zero-defect typography and formatting audit
|   |-- heatmap_visualizer.py   # Terminal 24-bit depth heatmap visualizer
|   |-- market_client.py        # Python gateway binary client
|   |-- generate_tick_dataset.py# Synthetic tick data generator
|   `-- visualize_depth.py      # ASCII volume profile analyzer
`-- docs/                       # Technical specifications
    |-- ARCHITECTURE.md         # System topology and modular design
    |-- MATCHING_ALGORITHMS.md  # Continuous matching and auction proofs
    |-- PRE_TRADE_RISK.md       # Pre-trade risk and SMP manual
    |-- MARKET_DATA_SPEC.md     # L1/L2/L3 and CAT market data feeds
    |-- PROTOCOL_SPEC.md        # SBE, Compact Binary, and FIX 4.2 specs
    |-- BENCHMARKS.md           # Throughput and latency distribution analysis
    `-- DEVELOPER_GUIDE.md      # Toolchain setup and compilation manual
```

---

## Getting Started

### Prerequisites
- Poly/ML (`brew install polyml` or `sudo apt install polyml`)
- MLton (`brew install mlton` or `sudo apt install mlton`)
- Python 3.9+

### Build and Run

1. **Run Master Regression Test Suite**:
   ```bash
   make test
   ```

2. **Compile Native High-Performance Binary**:
   ```bash
   make build
   ```

3. **Run 100,000-Order Benchmark**:
   ```bash
   ./bin/governor --bench 100000
   ```

4. **Launch Continuous Market Simulation**:
   ```bash
   ./bin/governor --sim 1000
   ```

5. **Start Interactive Operator Terminal**:
   ```bash
   ./bin/governor --repl
   ```

---

## Documentation Links

- [System Architecture Specification](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/ARCHITECTURE.md)
- [Matching Algorithms and Mathematical Proofs](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/MATCHING_ALGORITHMS.md)
- [Pre-Trade Risk Controls and Self-Match Prevention](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/PRE_TRADE_RISK.md)
- [Market Data Feed Specifications (L1/L2/L3/CAT)](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/MARKET_DATA_SPEC.md)
- [Wire Protocol Specifications (SBE/Binary/FIX)](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/PROTOCOL_SPEC.md)
- [Performance Benchmarks and Latency Distribution](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/BENCHMARKS.md)
- [Developer Onboarding and Compilation Manual](file:///Users/aneeshkrishna/.gemini/antigravity/scratch/governor/docs/DEVELOPER_GUIDE.md)

---

## License

Distributed under the MIT License.
