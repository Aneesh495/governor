#!/usr/bin/env python3
"""
Benchmark dataset generator for Governor.
Generates synthetic L3 order streams with realistic price walks,
order arrival distributions, and cancellation rates.
"""

import sys
import random
import csv

def generate_dataset(output_path, num_orders=50000, base_price=150.0):
    print(f"[INFO] Generating {num_orders} synthetic orders to {output_path}...")
    price = base_price
    timestamp = 1700000000000000000

    symbols = ["AAPL", "MSFT", "GOOGL", "NVDA"]
    clients = ["CITADEL", "JANE_ST", "TWO_SIGMA", "RETAIL_FLOW"]

    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["order_id", "timestamp_ns", "symbol", "client_id", "side", "order_type", "price", "qty"])

        for order_id in range(1, num_orders + 1):
            timestamp += random.randint(500, 5000) # Nanoseconds between orders
            symbol = random.choice(symbols)
            client = random.choice(clients)

            # Random price perturbation
            price_delta = random.choice([-0.05, -0.01, 0.0, 0.01, 0.05])
            price = max(10.0, price + price_delta)

            side = random.choice(["BUY", "SELL"])
            order_type = "LIMIT" if random.random() > 0.1 else "MARKET"
            qty = random.choice([10, 25, 50, 100, 200, 500])

            writer.writerow([order_id, timestamp, symbol, client, side, order_type, f"{price:.2f}", qty])

    print(f"[INFO] Successfully generated {num_orders} orders at {output_path}.")

def main():
    out_file = "data/synthetic_orders.csv"
    count = 10000
    if len(sys.argv) > 1:
        count = int(sys.argv[1])
    if len(sys.argv) > 2:
        out_file = sys.argv[2]

    import os
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    generate_dataset(out_file, count)

if __name__ == "__main__":
    main()
