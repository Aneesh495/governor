# System Architecture and Design Specification

The Governor matching engine is an ultra-low-latency, multi-asset electronic trading core engineered entirely in Standard ML (SML 97). The architecture enforces strict mathematical determinism, cache-conscious data layout, zero-exception error routing via monadic result types, and mechanical sympathy for native execution on POSIX/x86_64 and ARM64 platforms.

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

## 1. Modular Decomposition

The codebase is organized into modular subsystems under `src/`:

### 1.1 Core Foundations (`src/core/`)
- `types.sml`: Fixed-point 64-bit numerical representations for currency and quantities (`priceScale = 100,000,000`). All floating-point operations are strictly eliminated from the matching fast-path to prevent IEEE 754 rounding inaccuracies.
- `result.sml`: Monadic error management (`('a, 'e) result = Ok of 'a | Err of 'e`). Eliminates out-of-band exceptions across business logic.
- `word_util.sml`: Endian-aware bitwise serialization routines for network wire encoding.
- `fifo_queue.sml`: Purely functional double-list amortized O(1) FIFO queues for order matching.
- `red_black_map.sml`: Left-leaning red-black tree with guaranteed O(log N) worst-case search, insertion, and deletion bounds.
- `ring_buffer.sml`: Contiguous cyclic buffer for zero-allocation market event journals and metrics.
- `latency_histogram.sml`: High-Dynamic-Range nanosecond latency tracking with logarithmic binning and percentile calculation (p50, p90, p99, p99.9).

### 1.2 Book Structure (`src/book/`)
- `order.sml`: Complete order lifecycle state machine (PendingNew, Accepted, PartiallyFilled, Filled, Cancelled, Rejected, Expired).
- `price_level.sml`: Aggregated depth queues containing resting liquidity at a discrete price point.
- `order_book.sml`: Dual-tree order book maintaining descending bids and ascending asks, fast BBO extraction, and O(1) order cancellation via secondary index maps.
- `order_modify.sml`: Cancel-Replace logic enforcing priority retention on size reduction while demoting orders to queue tail on size increases or price adjustments.
- `book_manager.sml`: Multi-symbol container dispatching cross-instrument quotes.

### 1.3 Matching Pipeline (`src/engine/`)
- `trade.sml`: Immutable trade execution records.
- `matching_policy.sml`: Configurable allocation policies including pure FIFO price-time and Pro-Rata allocation.
- `circuit_breaker.sml`: Dynamic reference-price price collars and volatility halt management.
- `matcher.sml`: Core crossing engine executing aggressive market and limit orders against resting liquidity.
- `auction.sml`: Call auction price discovery maximizing executed volume and minimizing market imbalance.
- `vwap_calculator.sml`: Cumulative volume-weighted and time-weighted average price trackers.
- `microprice.sml`: Order flow imbalance (OFI) and volume-weighted microprice calculators.
- `stop_order_manager.sml`: Off-book stop-loss and stop-limit trigger queues.
- `trailing_stop.sml`: Dynamic peak and trough watermark ratchets.
- `oco_manager.sml`: One-Cancels-the-Other linked exit pair manager.
- `bracket_order.sml`: Automated multi-leg parent-child order coordinator.

### 1.4 Risk Gateway (`src/risk/`)
- `risk_limits.sml`: Per-trader configurable risk boundaries.
- `trader_state.sml`: Real-time position tracking, cash accounting, and margin checks.
- `self_match.sml`: Pre-trade self-match prevention (SMP) protecting against wash trades.
- `risk_engine.sml`: Pre-trade filtering pipeline executing before order book ingress.
- `fee_calculator.sml`: Tiered maker/taker fee schedules and liquidity rebate calculators.

### 1.5 Market Data & Protocols (`src/marketdata/`, `src/protocol/`, `src/net/`)
- `level1_feed.sml`: Top-of-book (BBO) dissemination with update deduplication.
- `level2_feed.sml`: Aggregated multi-level market depth snapshots.
- `audit_trail.sml`: Consolidated Audit Trail (CAT) regulatory event recorder.
- `sbe_codec.sml`: Fixed-offset 48-byte Simple Binary Encoding wire serializer.
- `binary_codec.sml`: Compact high-speed binary protocol for embedded feeds.
- `fix_message.sml`: Tag-value FIX 4.2 protocol parser and checksum generator.
- `order_gateway.sml`: Session sequence tracking, heartbeat handling, and network dispatcher.

---

## 2. Invariant Specifications

The system enforces six core architectural invariants at all times:

1. **Volume Conservation Invariant**:
   For any aggressive taker order matching against resting maker orders:
   $$\sum_{i=1}^k \text{trade}_i.\text{qty} + \text{order}.\text{leaves\_qty} = \text{order}.\text{initial\_qty}$$

2. **Price Priority Invariant**:
   For Buy orders matching resting Asks:
   $$\forall i < j : \text{trade}_i.\text{price} \le \text{trade}_j.\text{price}$$
   For Sell orders matching resting Bids:
   $$\forall i < j : \text{trade}_i.\text{price} \ge \text{trade}_j.\text{price}$$

3. **Limit Price Bound Invariant**:
   No aggressive order shall execute at a price inferior to its limit price:
   $$\text{trade}.\text{price} \le \text{taker}.\text{price} \quad (\text{Buy})$$
   $$\text{trade}.\text{price} \ge \text{taker}.\text{price} \quad (\text{Sell})$$

4. **FIFO Priority Invariant**:
   Orders at identical price levels are filled strictly in chronological order of queue entry, unless reduced in size via `OrderModify`.

5. **Self-Match Non-Crossing Invariant**:
   No trade may occur where `maker.client_id = taker.client_id` when SMP is enabled.

6. **Monotonic Sequence Invariant**:
   Every market data event and audit log entry receives a strictly monotonically increasing 64-bit sequence identifier.
