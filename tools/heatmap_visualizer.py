#!/usr/bin/env python3
"""
Order flow heatmap and volume density curve visualizer for Governor.
Renders 2D time-price depth heatmaps with ANSI color gradients in the terminal.
"""

import sys
import math
import random

ANSI_RESET = "\033[0m"
ANSI_BOLD = "\033[1m"
ANSI_DIM = "\033[2m"

# Heat intensity color palette (from dark purple -> blue -> cyan -> yellow -> bright white)
COLOR_RAMP = [
    (20, 20, 40),
    (30, 40, 100),
    (0, 120, 180),
    (0, 200, 150),
    (240, 220, 50),
    (255, 255, 255)
]

def interpolate_rgb(val):
    """Interpolate RGB color between 0.0 and 1.0."""
    val = max(0.0, min(1.0, val))
    n = len(COLOR_RAMP) - 1
    idx = val * n
    base = int(idx)
    frac = idx - base
    if base >= n:
        return COLOR_RAMP[-1]
    c1 = COLOR_RAMP[base]
    c2 = COLOR_RAMP[base + 1]
    r = int(c1[0] + frac * (c2[0] - c1[0]))
    g = int(c1[1] + frac * (c2[1] - c1[1]))
    b = int(c1[2] + frac * (c2[2] - c1[2]))
    return (r, g, b)

def render_heatmap(grid, price_labels, time_steps):
    """
    Renders 2D grid of volume density as an ANSI colored terminal heatmap.
    grid is 2D list: grid[price_idx][time_idx]
    """
    num_prices = len(grid)
    num_times = len(grid[0]) if num_prices > 0 else 0

    max_val = max(max(row) for row in grid) if grid else 1.0
    if max_val == 0:
        max_val = 1.0

    print(f"\n{ANSI_BOLD}=== Order Flow Volume Density Heatmap (Governor L2 Depth) ==={ANSI_RESET}")
    print(f"Time slices: {num_times} intervals | Price levels: {num_prices} buckets | Max density: {int(max_val):,} units\n")

    for p_idx in range(num_prices - 1, -1, -1):
        price_str = f"{price_labels[p_idx]:>8.2f} | "
        row_chars = []
        for t_idx in range(num_times):
            density = grid[p_idx][t_idx]
            norm = density / max_val
            r, g, b = interpolate_rgb(norm)
            # Use block character with foreground color
            if norm < 0.05:
                char = f"\033[38;2;{r};{g};{b}m.{ANSI_RESET}"
            elif norm < 0.25:
                char = f"\033[38;2;{r};{g};{b}m:{ANSI_RESET}"
            elif norm < 0.50:
                char = f"\033[38;2;{r};{g};{b}mo{ANSI_RESET}"
            elif norm < 0.75:
                char = f"\033[38;2;{r};{g};{b}mO{ANSI_RESET}"
            else:
                char = f"\033[38;2;{r};{g};{b}m#{ANSI_RESET}"
            row_chars.append(char)
        print(price_str + "".join(row_chars))

    # Time axis
    axis_padding = " " * 11
    print(axis_padding + "-" * num_times)
    print(axis_padding + "t=0" + " " * (num_times - 8) + "t=end")

    # Legend
    print(f"\n{ANSI_BOLD}Volume Density Legend:{ANSI_RESET}")
    legend_steps = 10
    legend_str = []
    for i in range(legend_steps + 1):
        norm = i / legend_steps
        r, g, b = interpolate_rgb(norm)
        legend_str.append(f"\033[48;2;{r};{g};{b}m \033[0m")
    print("  Low " + "".join(legend_str) + " High (Liquidity Concentration)\n")

def run_simulation_demo():
    """Generates a realistic synthetic order flow book depth profile and renders heatmap."""
    num_price_buckets = 25
    num_time_steps = 60

    base_price = 150.0
    tick_size = 0.10
    price_labels = [base_price + (i - num_price_buckets // 2) * tick_size for i in range(num_price_buckets)]

    # Generate evolving order flow with bid/ask walls and mid-price drift
    grid = [[0.0 for _ in range(num_time_steps)] for _ in range(num_price_buckets)]

    current_mid_idx = num_price_buckets // 2

    for t in range(num_time_steps):
        # Random walk drift in mid price
        drift = random.choice([-1, 0, 0, 1])
        current_mid_idx = max(4, min(num_price_buckets - 5, current_mid_idx + drift))

        for p_idx in range(num_price_buckets):
            dist = abs(p_idx - current_mid_idx)
            if dist == 0:
                grid[p_idx][t] = 0.0 # Inside the spread
            elif dist <= 3:
                # Top of book quotes
                grid[p_idx][t] = random.uniform(500, 1500)
            elif dist == 6:
                # Liquidity wall
                grid[p_idx][t] = random.uniform(3000, 6000)
            else:
                # Background depth
                decay = math.exp(-0.2 * dist)
                grid[p_idx][t] = random.uniform(100, 800) * decay

    render_heatmap(grid, price_labels, num_time_steps)

def main():
    random.seed(42)
    run_simulation_demo()

if __name__ == "__main__":
    main()
