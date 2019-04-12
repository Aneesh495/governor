(* level2_feed.sig
 * Level 2 Market by Price (MBP) aggregated depth book feed.
 *)

signature LEVEL2_FEED =
sig
  type depth_level = {
    price : Types.price,
    qty : Types.qty,
    order_count : int
  }

  type book_snapshot = {
    symbol : Types.symbol_id,
    bids : depth_level list,
    asks : depth_level list,
    timestamp : Types.timestamp_ns
  }

  val createSnapshot : OrderBook.book -> int -> Types.timestamp_ns -> book_snapshot
  val snapshotToString : book_snapshot -> string
end
