(* vwap_calculator.sig
 * Real-time Volume-Weighted Average Price (VWAP) and Time-Weighted Average Price (TWAP) tracking.
 *)

signature VWAP_CALCULATOR =
sig
  type tracker

  val create : Types.symbol_id -> tracker
  val recordTrade : tracker -> Types.price -> Types.qty -> Types.timestamp_ns -> tracker

  val currentVwap : tracker -> Types.price option
  val currentTwap : tracker -> Types.price option
  val totalVolume : tracker -> Types.qty
  val totalNotional : tracker -> LargeInt.int

  val reset : tracker -> tracker
  val toString : tracker -> string
end
