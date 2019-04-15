(* market_replay.sig
 * Deterministic historical order replay and validation engine.
 *)

signature MARKET_REPLAY =
sig
  type replay_stats = {
    orders_processed : int,
    trades_generated : int,
    total_volume_executed : Types.qty,
    elapsed_sim_time_ns : Types.timestamp_ns
  }

  val replayOrders : Order.order list -> OrderBook.book -> replay_stats * OrderBook.book * Trade.trade list
end
