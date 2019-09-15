# Matching Engine Algorithms and Mathematical Specifications

This document outlines the formal mechanics, algorithmic pipelines, and invariant proofs governing trade execution in Governor.

---

## 1. Continuous Trading: Price-Time Priority (FIFO)

The primary execution model is deterministic Price-Time priority. In this regime:
1. **Price Priority**: Orders offering superior prices (higher bids or lower asks) are executed before orders at inferior prices.
2. **Time Priority**: Among orders at identical prices, older resting orders have priority over newer orders.

### 1.1 Formal State Formulation

Let the state of an order book at time $t$ be represented by the tuple:
$$\mathcal{S}_t = (\mathcal{B}_t, \mathcal{A}_t)$$

where:
- $\mathcal{B}_t = \{(p_i^b, \mathcal{Q}_i^b)\}_{i=1}^{m}$ is the sorted sequence of bid price levels such that $p_1^b > p_2^b > \dots > p_m^b$.
- $\mathcal{A}_t = \{(p_j^a, \mathcal{Q}_j^a)\}_{j=1}^{n}$ is the sorted sequence of ask price levels such that $p_1^a < p_2^a < \dots < p_n^a$.
- Each price level $\mathcal{Q}$ is an ordered FIFO sequence of resting orders:
  $$\mathcal{Q} = [o_1, o_2, \dots, o_k]$$
  where $o_1$ was inserted strictly before $o_2$ (i.e., $t(o_1) < t(o_2)$).

### 1.2 Execution Mechanics

When an aggressive Buy order $o_{in} = (side = \text{Buy}, p_{in}, q_{in}, tif)$ enters the engine:
1. Check if the book crosses: while $q_{in} > 0$ and $\mathcal{A}_t \ne \emptyset$ and $p_1^a \le p_{in}$:
   - Take the top ask level $\mathcal{Q}_1^a = [o_1^a, o_2^a, \dots]$.
   - Let maker order be $o_{head} = o_1^a$.
   - Compute fill quantity:
     $$\Delta q = \min(q_{in}, leaves(o_{head}))$$
   - Emit trade event:
     $$T = (p = p_1^a, q = \Delta q, maker = id(o_{head}), taker = id(o_{in}))$$
   - Update leaves quantity:
     $$q_{in} \leftarrow q_{in} - \Delta q$$
     $$leaves(o_{head}) \leftarrow leaves(o_{head}) - \Delta q$$
   - If $leaves(o_{head}) = 0$, pop $o_{head}$ from $\mathcal{Q}_1^a$.
   - If $\mathcal{Q}_1^a$ becomes empty, remove level $p_1^a$ from $\mathcal{A}_t$.
2. Once the loop terminates:
   - If $q_{in} > 0$ and $tif = \text{GTC}$, insert remaining $q_{in}$ as a resting bid in $\mathcal{B}_{t+1}$.
   - If $tif \in \{\text{IOC}, \text{FOK}\}$, cancel any remaining leaves.

---

## 2. Time-in-Force (TIF) Semantics

Governor strictly implements standard exchange Time-in-Force instructions:

| TIF Mode | Execution Behavior | Residual Behavior |
| :--- | :--- | :--- |
| **GTC** (Good-Til-Cancelled) | Matches against resting liquidity up to limit price. | Residual resting quantity placed on book. |
| **IOC** (Immediate-Or-Cancel) | Matches against available resting liquidity immediately. | Any unexecuted quantity is cancelled immediately. |
| **FOK** (Fill-Or-Kill) | Matches if and only if entire quantity is filled. | If not 100% executable immediately, cancels with 0 trades. |
| **PostOnly** | Only accepts orders that do NOT match immediately. | If it would take liquidity, order is rejected immediately. |

---

## 3. Call Auction Uncrossing Algorithm

During market open, market close, or volatility halt resumptions, Governor switches to discrete Call Auction mode to maximize price discovery.

### 3.1 Cumulative Supply and Demand

For any arbitrary clearing price $p$:
1. **Cumulative Demand** (Buyers willing to purchase at price $\ge p$):
   $$D(p) = \sum_{b \in \mathcal{B}, p_b \ge p} q_b$$

2. **Cumulative Supply** (Sellers willing to sell at price $\le p$):
   $$S(p) = \sum_{a \in \mathcal{A}, p_a \le p} q_a$$

3. **Executable Match Volume**:
   $$V(p) = \min(D(p), S(p))$$

4. **Order Imbalance**:
   $$I(p) = D(p) - S(p)$$

### 3.2 Clearing Price Selection Hierarchy

Governor applies a deterministic 4-stage tie-breaking hierarchy to select clearing price $p^*$:

1. **Maximum Tradable Volume**:
   Find the set of candidate prices $\mathcal{P}_1$ that maximize executable volume:
   $$\mathcal{P}_1 = \arg\max_{p} V(p)$$
   If $|\mathcal{P}_1| = 1$, choose $p^* = p \in \mathcal{P}_1$.

2. **Minimum Market Imbalance**:
   If multiple prices maximize volume, select subset $\mathcal{P}_2 \subseteq \mathcal{P}_1$ minimizing absolute imbalance:
   $$\mathcal{P}_2 = \arg\min_{p \in \mathcal{P}_1} |I(p)|$$
   If $|\mathcal{P}_2| = 1$, choose $p^* = p \in \mathcal{P}_2$.

3. **Directional Market Pressure**:
   If multiple prices remain in $\mathcal{P}_2$:
   - If $I(p) > 0$ for all $p \in \mathcal{P}_2$ (excess demand / buy pressure), choose the highest price: $\max(\mathcal{P}_2)$.
   - If $I(p) < 0$ for all $p \in \mathcal{P}_2$ (excess supply / sell pressure), choose the lowest price: $\min(\mathcal{P}_2)$.

4. **Reference Price Proximity**:
   If imbalance is zero or symmetric, select the candidate price closest to the last traded / reference price:
   $$p^* = \arg\min_{p \in \mathcal{P}_2} |p - p_{ref}|$$

---

## 4. Iceberg Order Replenishment

Iceberg orders permit market participants to post large resting liquidity while disguising overall order size:
- An Iceberg order specifies a `peak_qty` (displayed) and a total quantity.
- Initial resting quantity exposed to the market is $\min(q, peak\_qty)$.
- The hidden balance $q - peak\_qty$ remains off the public book.
- **Priority Degradation Rule**: When the resting visible peak is completely filled, the engine replenishes the peak from the hidden pool and appends the fresh peak to the **end** of the FIFO queue for that price level. The replenished peak does NOT retain priority over existing resting orders at that level.

---

## 5. Formal Invariant Proofs

### Theorem 1: Volume Conservation
**Statement**: In any matching transaction involving an aggressive order $o$ with initial quantity $Q_0$, the sum of all executed trade quantities $\sum_{k=1}^m q_k$ plus the unexecuted leaves quantity $L$ is strictly equal to $Q_0$.

**Proof**:
By induction on the number of matches $m$:
- Base Case ($m = 0$): No trades occurred. $L = Q_0$, so $\sum_{k=1}^0 q_k + L = 0 + Q_0 = Q_0$.
- Inductive Step: Assume volume conservation holds for $m - 1$ trades:
  $$\sum_{k=1}^{m-1} q_k + L_{m-1} = Q_0$$
  At step $m$, a new trade is created with quantity:
  $$q_m = \min(L_{m-1}, q_{maker}) > 0$$
  The leaves quantity is decremented by $q_m$:
  $$L_m = L_{m-1} - q_m \implies L_{m-1} = L_m + q_m$$
  Substituting into the inductive hypothesis:
  $$\sum_{k=1}^{m-1} q_k + (L_m + q_m) = \sum_{k=1}^m q_k + L_m = Q_0$$
  Thus, volume conservation is preserved for all $m \ge 0$. $\blacksquare$
