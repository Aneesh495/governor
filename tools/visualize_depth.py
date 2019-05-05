#!/usr/bin/env python3
"""
Order book depth curve and volume profile visualizer.
Parses synthetic order files or live feeds and displays terminal depth curves.
"""

import sys
import csv

def visualize_summary(csv_path):
    print(f"\n=== Order Book Volume Profile for {csv_path} ===")
    buy_vol = 0
    sell_vol = 0
    trade_count = 0

    with open(csv_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            trade_count += 1
            qty = int(row["qty"])
            if row["side"] == "BUY":
                buy_vol += qty
            else:
                sell_vol += qty

    total_vol = buy_vol + sell_vol
    buy_pct = (buy_vol / total_vol * 100) if total_vol > 0 else 0
    sell_pct = (sell_vol / total_vol * 100) if total_vol > 0 else 0

    bar_len = 40
    buy_bar = int(bar_len * (buy_vol / total_vol)) if total_vol > 0 else 0
    sell_bar = bar_len - buy_bar

    print(f"Total Orders:    {trade_count}")
    print(f"Total Volume:    {total_vol:,} shares")
    print(f"Buy Volume:      {buy_vol:,} ({buy_pct:.1f}%)")
    print(f"Sell Volume:     {sell_vol:,} ({sell_pct:.1f}%)")
    print("\nOrder Flow Imbalance Profile:")
    print(f"BUY  [{'#' * buy_bar}{' ' * (bar_len - buy_bar)}] {buy_pct:.1f}%")
    print(f"SELL [{'#' * sell_bar}{' ' * (bar_len - sell_bar)}] {sell_pct:.1f}%\n")

def main():
    path = "data/synthetic_orders.csv"
    if len(sys.argv) > 1:
        path = sys.argv[1]
    visualize_summary(path)

if __name__ == "__main__":
    main()
