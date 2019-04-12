(* level1_feed.sig
 * Level 1 Top of Book (BBO) feed publisher with change-detection filtering.
 *)

signature LEVEL1_FEED =
sig
  type bbo = {
    symbol : Types.symbol_id,
    bid_price : Types.price option,
    bid_qty : Types.qty option,
    ask_price : Types.price option,
    ask_qty : Types.qty option,
    last_trade_price : Types.price option,
    last_trade_qty : Types.qty option,
    total_volume : Types.qty,
    timestamp : Types.timestamp_ns
  }

  type feed

  val create : unit -> feed
  val updateBook : feed -> OrderBook.book -> Types.timestamp_ns -> (feed * bbo option)
  val getBBO : feed -> Types.symbol_id -> bbo option
  val bboToString : bbo -> string
end
