# Wire Protocol Specifications (SBE, Compact Binary, and FIX 4.2)

Governor provides three production-grade transport codecs designed for varying deployment environments:
1. **Simple Binary Encoding (SBE)**: High-speed, fixed-offset binary codec for sub-microsecond algorithmic execution.
2. **Compact Binary Protocol**: 40-byte packed binary framing for embedded trading clients and market feeds.
3. **FIX 4.2**: Standard tag-value Financial Information eXchange protocol with checksum verification.

---

## 1. Simple Binary Encoding (SBE) Specification

Implemented in `src/protocol/sbe_codec.sml`, Governor SBE conforms to the open Real-Logic SBE standard:
- Fixed-offset memory alignment for direct field indexing.
- Zero string decoding or tag parsing overhead on the critical path.

### 1.1 SBE Message Header (8 Bytes)

Every SBE frame begins with an 8-byte framing header:

| Offset (Bytes) | Field Name | Type | Size | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0..1` | `block_length` | UInt16 | 2 | Size of message root block body (excluding header) |
| `2..3` | `template_id` | UInt16 | 2 | Unique message template identifier |
| `4..5` | `schema_id` | UInt16 | 2 | Schema version identifier (Governor = `0x0001`) |
| `6..7` | `version` | UInt16 | 2 | Schema semantic version |

### 1.2 Trade Event Template (`template_id = 0x0064` / 100)

Total packet length: 48 bytes (8-byte header + 40-byte body).

| Offset (Bytes) | Field Name | Type | Size | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0..7` | `header` | SbeHeader | 8 | Standard SBE header |
| `8..15` | `match_id` | UInt64 | 8 | Monotonic trade match identifier |
| `16..23` | `order_id` | UInt64 | 8 | Unique exchange order identifier |
| `24..31` | `price` | Int64 | 8 | Execution price (fixed-point 8 decimals) |
| `32..39` | `qty` | Int64 | 8 | Traded quantity |
| `40..47` | `timestamp` | UInt64 | 8 | Nanosecond UNIX epoch timestamp |

---

## 2. Compact Binary Protocol Specification

Implemented in `src/protocol/binary_codec.sml`, this 40-byte packed layout is optimized for high-density network throughput:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Sequence Number (UInt64)                  |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Client ID (8 ASCII bytes)                 |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Symbol ID (8 ASCII bytes)                 |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Order ID (UInt64)                         |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Price (Int32 scaled)                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Quantity (UInt32)                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Side  |                   Padding / Reserved                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

---

## 3. FIX 4.2 Protocol Specification

Implemented in `src/protocol/fix_message.sml`, Governor supports industry-standard tag-value messaging using ASCII SOH (`\x01`) or pipe (`|`) field delimiters.

### 3.1 Supported Tag Dictionary

| Tag | Name | Type | Description |
| :--- | :--- | :--- | :--- |
| `8` | `BeginString` | String | Protocol version (`FIX.4.2`) |
| `9` | `BodyLength` | Int | Payload byte length |
| `35` | `MsgType` | Char/Str | `D` (New Order Single), `8` (Execution Report), `F` (Cancel), `0` (Heartbeat) |
| `49` | `SenderCompID`| String | Sending firm identifier |
| `56` | `TargetCompID`| String | Target exchange identifier (`GOVERNOR`) |
| `34` | `MsgSeqNum` | Int | Expected monotonic sequence counter |
| `52` | `SendingTime` | Timestamp | Message generation timestamp |
| `11` | `ClOrdID` | String | Unique client-generated order identifier |
| `55` | `Symbol` | String | Trading instrument ticker |
| `54` | `Side` | Char | `1` = Buy, `2` = Sell |
| `38` | `OrderQty` | Int | Order volume |
| `40` | `OrdType` | Char | `1` = Market, `2` = Limit |
| `44` | `Price` | Price | Limit order price |
| `59` | `TimeInForce` | Char | `0` = Day, `1` = GTC, `3` = IOC, `4` = FOK |
| `10` | `CheckSum` | String | 3-character zero-padded modulo-256 checksum |

### 3.2 Checksum Verification Algorithm
The checksum is calculated by taking the sum of every byte in the message up to (but not including) the `10=xxx\x01` tag, modulo 256:
$$\text{CheckSum} = \left(\sum_{i=0}^{N-1} \text{byte}_i\right) \pmod{256}$$
Governor computes this via `WordUtil` and formats as `%03d`. Messages with mismatched checksums are rejected before session dispatch.
