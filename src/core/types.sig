(* types.sig
 * Core financial numerical types, identifiers, and order attribute enumerations.
 *)

signature TYPES =
sig
  (* Price in fixed-point 8 decimal places (1 unit = 10^-8 currency units) *)
  type price = LargeInt.int

  (* Quantity in integer units (shares/contracts) *)
  type qty = LargeInt.int

  (* Identifiers *)
  type order_id = LargeInt.int
  type client_id = string
  type symbol_id = string
  type match_id = LargeInt.int
  type sequence_num = LargeInt.int

  (* Nanoseconds since UNIX epoch *)
  type timestamp_ns = LargeInt.int

  (* Order Side *)
  datatype side =
      Buy
    | Sell

  (* Time in Force *)
  datatype time_in_force =
      GTC   (* Good Till Cancel *)
    | IOC   (* Immediate or Cancel *)
    | FOK   (* Fill or Kill *)
    | GTD of timestamp_ns (* Good Till Date / Timestamp *)
    | Day   (* Good for Trading Day *)

  (* Order Type *)
  datatype order_type =
      Limit of { price : price }
    | Market
    | StopLoss of { stop_price : price }
    | StopLimit of { stop_price : price, limit_price : price }
    | Iceberg of { price : price, peak_qty : qty }
    | PostOnly of { price : price }

  (* Order Lifecycle State *)
  datatype order_status =
      PendingNew
    | Accepted
    | PartiallyFilled
    | Filled
    | Cancelled
    | Rejected of string
    | Expired

  (* Maker / Taker designation for trades *)
  datatype liquidity_indicator =
      Maker
    | Taker

  (* Self-Match Prevention policy *)
  datatype smp_mode =
      CancelNewest
    | CancelOldest
    | CancelBoth
    | DecrementAndCancel

  (* Helper constants and converters *)
  val priceScale : LargeInt.int
  val fromDollars : real -> price
  val toDollars : price -> real
  val priceToString : price -> string
  val priceFromString : string -> price option

  val qtyToString : qty -> string
  val qtyFromString : string -> qty option

  val sideToString : side -> string
  val sideFromString : string -> side option
  val oppositeSide : side -> side

  val orderTypeToString : order_type -> string
  val statusToString : order_status -> string
end
