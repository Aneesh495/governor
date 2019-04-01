(* matcher.sig
 * Core deterministic matching engine algorithm with Time-in-Force handling.
 *)

signature MATCHER =
sig
  type match_result = {
    book : OrderBook.book,
    trades : Trade.trade list,
    order : Order.order
  }

  val processOrder : {
    book : OrderBook.book,
    order : Order.order,
    policy : MatchingPolicy.policy,
    nextMatchId : unit -> Types.match_id,
    timestamp : Types.timestamp_ns
  } -> match_result
end
