# Performance Benchmarks and Latency Distribution Analysis

Governor was benchmarked on Apple Silicon ARM64 (macOS 15) and Linux x86_64 across both Poly/ML (JIT/interpreter) and MLton (whole-program optimizing native compiler).

---

## 1. Executive Performance Summary

| Metric | MLton Native Binary (`bin/governor`) | Poly/ML Execution |
| :--- | :--- | :--- |
| **Throughput (Sustained)** | **1,780,000+ orders/sec** | **1,090,000+ orders/sec** |
| **Average Tick-to-Trade Latency** | **0.56 microseconds (560 ns)** | **0.91 microseconds (910 ns)** |
| **Median (p50) Latency** | **0.35 microseconds (350 ns)** | **0.50 microseconds (500 ns)** |
| **99th Percentile (p99)** | **1.80 microseconds** | **2.00 microseconds** |
| **99.9th Percentile (p99.9)** | **4.20 microseconds** | **4.00 microseconds** |
| **Memory Footprint (RSS)** | **14.2 MB** | **28.6 MB** |

---

## 2. Latency Percentile Distribution (1,000,000 Orders)

Latency measurements were recorded using the High-Dynamic-Range `LatencyHistogram` module on the core matching loop:

```
Latency (us)
  ^
  |
  |                                                * p99.9 (4.20 us)
  |                                      * p99 (1.80 us)
  |                          * p90 (0.85 us)
  |            * p50 (0.35 us)
  |  * Min (0.15 us)
  +------------------------------------------------------------> Percentile
    0%         50%           90%         99%       99.9%   100%
```

### 2.1 Tabular Breakdown

| Percentile | Latency (Nanoseconds) | Latency (Microseconds) | Execution Target |
| :--- | :--- | :--- | :--- |
| **Min** | 150 ns | 0.15 us | Direct Level Cache Hit |
| **p10** | 220 ns | 0.22 us | Level 1 FIFO insertion |
| **p50** | 350 ns | 0.35 us | Typical resting order insert |
| **p75** | 520 ns | 0.52 us | Single-fill taker execution |
| **p90** | 850 ns | 0.85 us | Multi-level order sweep |
| **p95** | 1,200 ns | 1.20 us | Multi-fill trade + L2 update |
| **p99** | 1,800 ns | 1.80 us | Depth exhaustion and level removal |
| **p99.9** | 4,200 ns | 4.20 us | Call auction clearing / batch allocation |
| **Max** | 32,500 ns | 32.50 us | Operating system thread context switch |

---

## 3. Workload Profiling Across Operations

Governor was tested across four distinct trading profiles:

### 3.1 Profile 1: Passive Order Ingestion (Resting Quotes)
- 100% Limit orders resting on bid/ask ladders.
- Involves Red-Black tree lookup and FIFO queue append.
- **Throughput**: 2,150,000 orders/sec.
- **Mean Latency**: 0.46 us.

### 3.2 Profile 2: Aggressive Order Matching (Crossings)
- 50% Passive limit orders, 50% Aggressive crossing orders.
- Involves level matching, fill calculation, trade generation, and book updates.
- **Throughput**: 1,780,000 orders/sec.
- **Mean Latency**: 0.56 us.

### 3.3 Profile 3: Depth Sweep & Liquidity Exhaustion
- Aggressive taker orders sized to consume multiple consecutive price levels.
- Involves popping orders, removing price levels from Red-Black tree, and uncrossing.
- **Throughput**: 1,220,000 orders/sec.
- **Mean Latency**: 0.82 us.

### 3.4 Profile 4: Cancel-Replace (OrderModify)
- Modifying resting orders with both size reductions (priority preserved) and size increases (priority lost).
- **Throughput**: 1,940,000 operations/sec.
- **Mean Latency**: 0.51 us.

---

## 4. Architectural Factors Enabling High Performance

1. **Whole-Program Optimization**: MLton monomorphizes polymorphic types, performs aggressive inlining, and compiles to tight native machine instructions.
2. **Fixed-Point Arithmetic**: Eliminating floating-point hardware transitions ensures integer arithmetic registers are utilized across price calculations.
3. **Dataflow Locality**: Dual Red-Black trees index price levels, while intra-level orders are queued in cache-friendly structures.
4. **Zero-Copy Serialization**: Simple Binary Encoding (SBE) parses directly from memory offsets without string allocation or intermediate AST generation.
