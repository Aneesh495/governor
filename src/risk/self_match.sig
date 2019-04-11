(* self_match.sig
 * Self-Match Prevention (SMP) logic to prevent wash trading.
 *)

signature SELF_MATCH =
sig
  datatype smp_action =
      NoSelfMatch
    | CancelIncoming of string
    | CancelResting of Types.order_id * string
    | CancelBothOrders of Types.order_id * string
    | DecrementIncoming of Types.qty * string
    | DecrementResting of Types.order_id * Types.qty * string

  val evaluateSMP : {
    book : OrderBook.book,
    order : Order.order,
    mode : Types.smp_mode
  } -> smp_action
end
