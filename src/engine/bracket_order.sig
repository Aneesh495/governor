(* bracket_order.sig
 * Automated bracket order lifecycle manager: entry order with contingent take-profit and stop-loss exits.
 *)

signature BRACKET_ORDER =
sig
  type bracket_id = LargeInt.int
  type order_id = Types.order_id

  type bracket_order = {
    id : bracket_id,
    entry_order : Order.order,
    take_profit_price : Types.price,
    stop_loss_price : Types.price,
    active : bool ref
  }

  type manager

  val create : unit -> manager
  val registerBracket : manager -> bracket_id -> Order.order -> Types.price -> Types.price -> manager
  val onEntryFilled : manager -> order_id -> Types.timestamp_ns -> (manager * (Order.order * Order.order) option)
  val onEntryCancelled : manager -> order_id -> manager

  val activeBracketCount : manager -> int
end
