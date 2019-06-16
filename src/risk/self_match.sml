(* self_match.sml
 * Implementation of Self-Match Prevention actions.
 *)

structure SelfMatch :> SELF_MATCH =
struct
  datatype smp_action =
      NoSelfMatch
    | CancelIncoming of string
    | CancelResting of Types.order_id * string
    | CancelBothOrders of Types.order_id * string
    | DecrementIncoming of Types.qty * string
    | DecrementResting of Types.order_id * Types.qty * string

  fun evaluateSMP { book, order = inOrd : Order.order, mode } : smp_action =
      let
        val clientId = #client_id inOrd
        val side = #side inOrd
        val p = #price inOrd

        (* Find the best opposite resting order belonging to the same client that crosses inOrd *)
        val conflictingOrderOpt =
            case side of
                Types.Buy =>
                  (case OrderBook.getBestAskLevel book of
                       NONE => NONE
                     | SOME lvl =>
                         if #price lvl <= p then
                           List.find (fn (ord : Order.order) => #client_id ord = clientId) (PriceLevel.getOrders lvl)
                         else NONE)
              | Types.Sell =>
                  (case OrderBook.getBestBidLevel book of
                       NONE => NONE
                     | SOME lvl =>
                         if #price lvl >= p then
                           List.find (fn (ord : Order.order) => #client_id ord = clientId) (PriceLevel.getOrders lvl)
                         else NONE)
      in
        case conflictingOrderOpt of
            NONE => NoSelfMatch
          | SOME (restingOrd : Order.order) =>
              let
                val restingId = #id restingOrd
                val inQty = #leaves_qty inOrd
                val restQty = #leaves_qty restingOrd
              in
                case mode of
                    Types.CancelNewest =>
                      CancelIncoming ("SMP CancelNewest: would trade with resting order " ^ LargeInt.toString restingId)
                  | Types.CancelOldest =>
                      CancelResting (restingId, "SMP CancelOldest triggered against order " ^ LargeInt.toString restingId)
                  | Types.CancelBoth =>
                      CancelBothOrders (restingId, "SMP CancelBoth triggered on order " ^ LargeInt.toString restingId)
                  | Types.DecrementAndCancel =>
                      if inQty = restQty then
                        CancelBothOrders (restingId, "SMP DecrementAndCancel: equal quantities")
                      else if inQty < restQty then
                        DecrementResting (restingId, inQty, "SMP DecrementResting: resting decremented by incoming")
                      else
                        DecrementIncoming (restQty, "SMP DecrementIncoming: incoming decremented by resting")
              end
      end
end
