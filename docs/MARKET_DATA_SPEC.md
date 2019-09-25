# Market Data Feed Specifications (Level 1, Level 2, Level 3, and CAT)

Governor generates real-time, deterministic market data dissemination streams designed for algorithmic consuming systems, risk dashboards, and regulatory compliance journals.

---

## 1. Market Data Feed Hierarchy

Governor classifies market data dissemination into four distinct tiers:

```
+-----------------------------------------------------------------------------+
|                     GOVERNOR MARKET DATA DISSEMINATION                      |
+-------------------+-------------------+-------------------+-----------------+
| Level 1 (BBO)     | Level 2 (L2 Depth)| Level 3 (MBO)     | CAT Audit Trail |
| Top-of-Book Quotes| Aggregated Depth  | Order-by-Order    | Regulatory Log  |
| Delta Filtered    | Top N Price Levels| Complete Lifecycle| SEC Rule 613    |
+-------------------+-------------------+-------------------+-----------------+
```

---

## 2. Level 1 (L1) Top of Book / BBO Feed

The Level 1 feed publishes real-time Best Bid and Offer (BBO) quotes:
- **Symbol**: Ticker identifier (e.g., `AAPL`, `MSFT`).
- **Bid Price & Bid Size**: Highest price among all resting buy orders and total aggregate volume at that price.
- **Ask Price & Ask Size**: Lowest price among all resting sell orders and total aggregate volume at that price.
- **Spread & Mid-Price**: Computed dynamically as $P_{ask} - P_{bid}$ and $(P_{bid} + P_{ask}) / 2$.

### 2.1 Delta Filtering Optimization
In `src/marketdata/level1_feed.sml`, Governor implements zero-cost delta filtering. If an order placement, cancellation, or modification does NOT alter the top-of-book price or aggregate quantity, the update is suppressed without generating network traffic.

---

## 3. Level 2 (L2) Aggregated Market Depth

The Level 2 feed aggregates order volume across discrete price levels:
- Configurable depth ladder (default 10 levels on Bid and Ask sides).
- Each level contains:
  1. Price (fixed-point 8 decimals).
  2. Total aggregate quantity at this price level.
  3. Total count of resting orders at this level.

### 3.1 Snapshot vs Incremental Updates
- **Snapshot Format**: Transmits the entire current depth ladder for periodic sync or new gateway client connections.
- **Incremental Format**: Emits deltas specifying price level modifications (`NewLevel`, `UpdateVolume`, `DeleteLevel`).

---

## 4. Level 3 (L3) Market By Order (MBO)

The Level 3 feed broadcasts atomic order lifecycle events with nanosecond timestamps:
- `OrderAdded`: Disseminates new resting limit order entry with order ID, side, price, and initial displayed size.
- `OrderModified`: Disseminates size reductions or priority loss notifications.
- `OrderExecuted`: Disseminates trade execution with match ID, price, and executed size.
- `OrderCancelled`: Disseminates order withdrawal and removed quantity.

---

## 5. Consolidated Audit Trail (CAT) Logging

Engineered in `src/marketdata/audit_trail.sml` to meet regulatory compliance requirements (such as SEC Rule 613):
- Every order submission, risk rejection, crossing execution, and cancellation receives an immutable audit log entry.
- Key record attributes:
  - `sequence_number`: Monotonically increasing 64-bit integer.
  - `timestamp`: Nanoseconds since UNIX epoch.
  - `event`: Type-safe variant tagging order events, trades, and circuit breaker halts.
- Indexed by order ID and sequence range for regulatory audit queries and reconstruction.

---

## 6. Deterministic Replay Journal

The event journal (`src/marketdata/event_journal.sml`) logs every incoming event to an in-memory ring buffer and persistent journal. Running `MarketReplay` over an event log re-creates identical order book states, trades, and depth curves, enabling deterministic backtesting, algorithm verification, and root-cause analysis of market anomalies.
