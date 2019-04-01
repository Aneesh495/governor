(* auction.sig
 * Call auction price discovery and batch uncrossing engine.
 *)

signature AUCTION =
sig
  type uncross_result = {
    clearing_price : Types.price option,
    cleared_volume : Types.qty,
    imbalance : Types.qty,
    trades : Trade.trade list,
    book : OrderBook.book
  }

  (* Discovers indicative clearing price and volume without executing *)
  val calculateIndicativePrice : OrderBook.book -> Types.price -> (Types.price * Types.qty * Types.qty) option

  (* Executes the call auction uncrossing at the optimal clearing price *)
  val uncross : {
    book : OrderBook.book,
    reference_price : Types.price,
    nextMatchId : unit -> Types.match_id,
    timestamp : Types.timestamp_ns
  } -> uncross_result
end
