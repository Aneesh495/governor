(* level2_feed.sml
 * Implementation of Level 2 depth snapshot generator.
 *)

structure Level2Feed :> LEVEL2_FEED =
struct
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

  fun createSnapshot (b : OrderBook.book) (maxLevels : int) (ts : Types.timestamp_ns) : book_snapshot =
      let
        val rawBids = OrderBook.topBids b maxLevels
        val rawAsks = OrderBook.topAsks b maxLevels

        val bids = List.map (fn (p, q, cnt) => { price = p, qty = q, order_count = cnt }) rawBids
        val asks = List.map (fn (p, q, cnt) => { price = p, qty = q, order_count = cnt }) rawAsks
      in
        {
          symbol = OrderBook.symbol b,
          bids = bids,
          asks = asks,
          timestamp = ts
        }
      end

  fun snapshotToString ({ symbol, bids, asks, timestamp } : book_snapshot) : string =
      let
        fun fmtLevel ({ price, qty, order_count } : depth_level) side =
            "  " ^ side ^ ": " ^ Types.priceToString price ^ " x " ^ LargeInt.toString qty ^
            " (" ^ Int.toString order_count ^ " orders)\n"
        val bidStrs = String.concat (List.map (fn l => fmtLevel l "BID") bids)
        val askStrs = String.concat (List.map (fn l => fmtLevel l "ASK") asks)
      in
        "L2 SNAPSHOT [" ^ symbol ^ "] at " ^ LargeInt.toString timestamp ^ ":\n" ^
        askStrs ^ "  ----------------\n" ^ bidStrs
      end
end
