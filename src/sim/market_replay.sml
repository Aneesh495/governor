(* market_replay.sml
 * Implementation of deterministic historical order replay.
 *)

structure MarketReplay :> MARKET_REPLAY =
struct
  type replay_stats = {
    orders_processed : int,
    trades_generated : int,
    total_volume_executed : Types.qty,
    elapsed_sim_time_ns : Types.timestamp_ns
  }

  fun replayOrders (orders : Order.order list) (initialBook : OrderBook.book) =
      let
        val matchIdCounter = ref (1 : LargeInt.int)
        fun nextMatchId () : LargeInt.int =
            let val id = !matchIdCounter in matchIdCounter := id + 1; id end

        fun step ([], b, allTrades, count, startTs, lastTs) =
              let
                val totalVol = List.foldl (fn (t, acc) => #qty t + acc) 0 allTrades
                val elapsed = lastTs - startTs
                val stats : replay_stats = {
                  orders_processed = count,
                  trades_generated = List.length allTrades,
                  total_volume_executed = totalVol,
                  elapsed_sim_time_ns = elapsed
                }
              in
                (stats, b, List.rev allTrades)
              end
          | step (ord :: rest, b, allTrades, count, startTs, _) =
              let
                val ts = #created_at ord
                val curStart = if count = 0 then ts else startTs
                val res = Matcher.processOrder {
                  book = b,
                  order = ord,
                  policy = MatchingPolicy.Fifo,
                  nextMatchId = nextMatchId,
                  timestamp = ts
                }
              in
                step (rest, #book res, (#trades res) @ allTrades, count + 1, curStart, ts)
              end
      in
        step (orders, initialBook, [], 0, 0, 0)
      end
end
