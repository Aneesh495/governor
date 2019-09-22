# Pre-Trade Risk Controls and Self-Match Prevention Manual

Governor provides a deterministic, zero-allocation pre-trade risk filter that inspects every inbound message before it reaches the order book or matching core. The risk engine protects market integrity, enforces margin and credit boundaries, throttles aberrant algorithmic runaway, and eliminates illegal wash trades.

---

## 1. Risk Pipeline Architecture

Every order arriving at the gateway passes through the pre-trade risk pipeline:

```
[Inbound Order]
       |
       v
+-------------------------------------------------------------+
| 1. Format & Sanity Verification                             |
|    - Quantity > 0 and <= max_order_qty                      |
|    - Price > 0 and within collar bands                      |
+------------------------------+------------------------------+
                               | Pass
                               v
+-------------------------------------------------------------+
| 2. Sliding-Window Rate Limiter                              |
|    - Enforce messages per second throttle                   |
|    - Drop / reject runaway algorithm traffic                |
+------------------------------+------------------------------+
                               | Pass
                               v
+-------------------------------------------------------------+
| 3. Margin & Position Collars                                |
|    - Projected position <= max_net_position                 |
|    - Projected gross notional <= max_gross_notional         |
|    - Cash balance sufficiency verification                  |
+------------------------------+------------------------------+
                               | Pass
                               v
+-------------------------------------------------------------+
| 4. Self-Match Prevention (SMP) Inspection                   |
|    - Check opposing book for resting orders from same client|
|    - Execute SMP action if crossing detected                |
+------------------------------+------------------------------+
                               | Pass
                               v
                     [Core Matching Engine]
```

---

## 2. Self-Match Prevention (SMP)

Self-matching occurs when an aggressive incoming order crosses with resting liquidity posted by the same market participant or legal entity. To comply with exchange regulations prohibiting wash trades, Governor provides four distinct SMP policies:

### 2.1 Supported SMP Modes

1. **CancelNewest** (Default):
   - The incoming aggressive order is cancelled immediately.
   - The resting maker order retains its price and queue position in the book.
   - Useful for market makers wishing to protect resting quotes from their own aggressive hedges.

2. **CancelOldest**:
   - The resting maker order is cancelled from the book.
   - The incoming aggressive order continues matching against the next available resting liquidity or rests in the book.

3. **CancelBoth**:
   - Both the incoming aggressive order and the resting maker order are cancelled simultaneously.
   - Zero trade volume is executed.

4. **DecrementAndCancel**:
   - The order with the smaller quantity is cancelled completely.
   - The order with the larger quantity has its leaves quantity decremented by the smaller order's leaves quantity.
   - If quantities are equal, both orders are cancelled.
   - If the resting order is larger, its size is reduced in-place without losing FIFO queue priority.

---

## 3. Position and Notional Controls

Governor tracks positions and margin requirements on every account in real time:

### 3.1 Net Position Calculation
$$\text{Net Position} = \text{Current Inventory} + \text{Signed Order Quantity}$$
where Buy orders have positive sign and Sell orders have negative sign.
The risk engine enforces:
$$-\text{MaxNetPosition} \le \text{Net Position} \le \text{MaxNetPosition}$$

### 3.2 Gross Notional Exposure
$$\text{Gross Exposure} = \sum_{\text{symbols}} |\text{Position}_s| \times P_{s,\text{ref}} + \sum_{\text{open orders}} Q_o \times P_o$$
Governor ensures that total committed capital never breaches the participant's credit margin:
$$\text{Gross Exposure} \le \text{MaxGrossNotional}$$

---

## 4. Rate Limiting and Algorithmic Throttling

To mitigate erroneous quote loops and feed spam:
- Governor implements a sliding-window message rate counter in `src/risk/trader_state.sml`.
- The sliding window measures message arrival times over a configurable interval (typically 1.0 second).
- Any order arriving when the active window count reaches `max_orders_per_sec` is rejected with `OrderRejected "Rate limit exceeded"`.

---

## 5. Volatility Circuit Breakers and Price Collars

Governor incorporates dynamic price collars in `src/engine/circuit_breaker.sml`:
- Around each symbol's reference price $P_{ref}$, a symmetric price band $[\underline{P}, \bar{P}]$ is established:
  $$\underline{P} = P_{ref} \times (1 - \text{collar\_pct} / 100)$$
  $$\bar{P} = P_{ref} \times (1 + \text{collar\_pct} / 100)$$
- Orders submitted outside this band are rejected before matching.
- If a market trade executes at the collar boundary, the circuit breaker triggers a temporary trading halt for `halt_duration_ns` nanoseconds, transitioning the market to a Call Auction uncrossing state.
