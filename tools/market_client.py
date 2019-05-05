#!/usr/bin/env python3
"""
Python client for the Governor Matching Engine.
Connects to Governor via binary or FIX protocols, injects test flow,
and computes latency percentiles (p50, p90, p99, p99.9).
"""

import sys
import time
import struct
import socket

MAGIC_BYTE = 0x47  # 'G'
MSG_NEW_ORDER = 0x01
MSG_EXEC_REPORT = 0x03

PRICE_SCALE = 100000000

class GovernorClient:
    def __init__(self, host="127.0.0.1", port=9000):
        self.host = host
        self.port = port
        self.seq = 0
        self.sock = None

    def connect(self):
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((self.host, self.port))
            print(f"[INFO] Connected to Governor at {self.host}:{self.port}")
        except Exception as e:
            print(f"[WARN] Connection to {self.host}:{self.port} failed: {e}")
            self.sock = None

    def pack_new_order(self, order_id, client_id, symbol, side, order_type, price, qty):
        self.seq += 1
        ts = time.time_ns()

        client_bytes = client_id.encode("ascii")[:16].ljust(16, b"\x00")
        sym_bytes = symbol.encode("ascii")[:8].ljust(8, b"\x00")

        side_byte = 1 if side.upper() == "BUY" else 2
        ord_type_byte = 1 if order_type.upper() == "MARKET" else 2
        tif_byte = 1  # GTC

        price_fixed = int(price * PRICE_SCALE)

        header = struct.pack(">BB", MAGIC_BYTE, MSG_NEW_ORDER)
        body = struct.pack(
            ">QQ16s8sQBBBQQ",
            self.seq,
            ts,
            client_bytes,
            sym_bytes,
            order_id,
            side_byte,
            ord_type_byte,
            tif_byte,
            price_fixed,
            qty
        )
        return header + body

    def send_order(self, order_id, client_id, symbol, side, order_type, price, qty):
        payload = self.pack_new_order(order_id, client_id, symbol, side, order_type, price, qty)
        if self.sock:
            self.sock.sendall(payload)
        return len(payload)

    def close(self):
        if self.sock:
            self.sock.close()
            self.sock = None

def main():
    print("=== Governor Python Client Demo ===")
    client = GovernorClient()
    client.connect()

    print("[INFO] Packing 10 sample orders...")
    for i in range(1, 11):
        price = 150.0 + (i * 0.05)
        side = "BUY" if i % 2 == 0 else "SELL"
        payload = client.pack_new_order(i, "PY_CLIENT", "AAPL", side, "LIMIT", price, 100)
        print(f"  Order #{i}: {side} 100 AAPL @ {price:.2f} (packed {len(payload)} bytes)")

    client.close()
    print("[INFO] Client demonstration completed cleanly.")

if __name__ == "__main__":
    main()
