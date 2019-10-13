# Developer Onboarding and Compilation Manual

This guide covers building, testing, profiling, and extending the Governor matching engine codebase.

---

## 1. Prerequisites and Toolchain Setup

Governor is built using standard ISO/IEC Standard ML (SML 97) and supports two primary compilers:

### 1.1 macOS (Homebrew)
```bash
brew install polyml mlton python3
```

### 1.2 Ubuntu / Debian
```bash
sudo apt update
sudo apt install -y polyml mlton python3 build-essential
```

### 1.3 Verifying Toolchain Versions
Ensure both compilers are available on your system path:
```bash
poly -v       # Expected: Poly/ML 5.9+
mlton         # Expected: MLton 20210117 or newer
python3 --version
```

---

## 2. Compilation and Build Targets

The project includes a unified `Makefile` configuring build workflows:

### 2.1 Native Executable Compilation (MLton)
To compile a whole-program optimized, standalone native binary:
```bash
make build
```
This produces the high-performance binary `bin/governor`.

### 2.2 Running Test Suites (Poly/ML)
Execute the complete master test harness:
```bash
make test
```
Or execute individual test suites:
```bash
poly --script test/run_tests.sml                  # Master harness (147+ assertions)
poly --script test/test_properties_rbtree.sml    # Property tests for RB-Tree invariants
poly --script test/test_properties_matching.sml  # Property tests for volume conservation
poly --script test/test_microprice.sml           # VWAP and Microprice estimators
poly --script test/test_fees.sml                 # Tiered fees and liquidity rebates
poly --script test/test_stop_orders.sml          # Stop-Loss and Stop-Limit triggers
poly --script test/test_order_modify.sml         # Cancel-Replace priority preservation
poly --script test/test_sbe.sml                  # SBE 48-byte binary codec
poly --script test/test_latency.sml              # HDR latency histogram
poly --script test/test_trailing_stop.sml        # Trailing stop ratchets
poly --script test/test_oco.sml                  # One-Cancels-the-Other pairs
poly --script test/test_bracket.sml              # Bracket order automation
poly --script test/test_audit_trail.sml          # CAT regulatory audit trail
poly --script test/test_stress.sml               # 50,000-order stress harness
```

---

## 3. Running Governor

Governor supports multiple execution modes through command-line flags:

### 3.1 Integrated Multi-Participant Simulation
Runs a continuous multi-asset simulation with liquidity providers, noise traders, and momentum buyers:
```bash
./bin/governor --sim 500
```

### 3.2 High-Throughput Native Benchmark
Executes a rapid 100,000-order crossing benchmark and reports throughput and latency distributions:
```bash
./bin/governor --bench 100000
```

### 3.3 Interactive Operator Console (REPL)
Launches the interactive exchange terminal:
```bash
./bin/governor --repl
```

Inside the console, supported commands include:
```text
  SUBMIT <side> <symbol> <qty> <price> [clientId]
  CANCEL <symbol> <orderId>
  BOOK <symbol>
  TRADES
  STATS
  RESET
  QUIT
```

---

## 4. Auxiliary Python Tools

Governor provides companion scripts in `tools/`:
- `tools/verify_clean_code.py`: Audits every file in the repository for forbidden characters (such as non-ASCII em dashes or unicode typography) to guarantee pristine source formatting.
- `tools/heatmap_visualizer.py`: Renders an ANSI 24-bit order flow depth heatmap in the terminal.
- `tools/market_client.py`: Python socket client streaming binary orders to the gateway.
- `tools/generate_tick_dataset.py`: Synthesizes market tick datasets for replay and backtesting.
- `tools/visualize_depth.py`: Generates ASCII depth curves and volume profiles.

---

## 5. Coding Standards and Invariant Verification

When contributing new modules to Governor:
1. Every new module must provide a signature file (`.sig`) and an implementation file (`.sml`).
2. SML 97 standard compliance: Avoid non-standard Basis functions; ensure variable names do not clash with infix operators (e.g. `op o`).
3. Zero em dashes: Use hyphens (`-`) or colons (`:`) in all comments and documentation.
4. Verify with `python3 tools/verify_clean_code.py` before committing.
