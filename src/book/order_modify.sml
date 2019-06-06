(* order_modify.sml
 * Implementation of Cancel-Replace FIFO priority preservation semantics.
 *)

structure OrderModify :> ORDER_MODIFY =
struct
  datatype priority_effect =
      PriorityPreserved
    | PriorityLost

  type modify_result = {
    book : OrderBook.book,
    updated_order : Order.order,
    effect : priority_effect
  }

  fun modifyOrder { book, order_id, new_price, new_qty, timestamp } =
      case OrderBook.findOrder book order_id of
          NONE => Result.err ("Order " ^ LargeInt.toString order_id ^ " not found in order book")
        | SOME oldOrd =>
            let
              val curPrice = #price oldOrd
              val curLeaves = #leaves_qty oldOrd

              val targetPrice = case new_price of SOME p => p | NONE => curPrice
              val targetLeaves = case new_qty of SOME q => q | NONE => curLeaves
            in
              if targetLeaves <= 0 then
                case OrderBook.cancelOrder book order_id timestamp of
                    SOME (cancelled, b') =>
                      Result.ok {
                        book = b',
                        updated_order = cancelled,
                        effect = PriorityLost
                      }
                  | NONE => Result.err "Cancellation failed during modify"
              else if targetPrice = curPrice andalso targetLeaves < curLeaves then
                (* Priority Preserved: quantity decreased in-place at same price level *)
                let
                  val updatedOrd = {
                    id = #id oldOrd,
                    client_id = #client_id oldOrd,
                    symbol = #symbol oldOrd,
                    side = #side oldOrd,
                    order_type = #order_type oldOrd,
                    time_in_force = #time_in_force oldOrd,
                    price = curPrice,
                    initial_qty = #initial_qty oldOrd,
                    leaves_qty = targetLeaves,
                    cum_qty = #cum_qty oldOrd,
                    peak_qty = #peak_qty oldOrd,
                    hidden_qty = #hidden_qty oldOrd,
                    status = #status oldOrd,
                    created_at = #created_at oldOrd,
                    updated_at = timestamp
                  }

                  (* In-place update of order inside PriceLevel without moving queue position *)
                  val lvlOpt = case #side oldOrd of
                                   Types.Buy => OrderBook.getBestBidLevel book
                                 | Types.Sell => OrderBook.getBestAskLevel book
                in
                  case OrderBook.cancelOrder book order_id timestamp of
                      NONE => Result.err "Modify failed"
                    | SOME (_, bWithout) =>
                        let
                          (* Re-insert modified order *)
                          val bUpdated = OrderBook.insertOrder bWithout updatedOrd
                        in
                          Result.ok {
                            book = bUpdated,
                            updated_order = updatedOrd,
                            effect = PriorityPreserved
                          }
                        end
                end
              else
                (* Priority Lost: price changed or quantity increased *)
                case OrderBook.cancelOrder book order_id timestamp of
                    NONE => Result.err "Modify failed during cancel"
                  | SOME (_, bWithout) =>
                      let
                        val newOrd = Order.create {
                          id = #id oldOrd,
                          client_id = #client_id oldOrd,
                          symbol = #symbol oldOrd,
                          side = #side oldOrd,
                          order_type = Types.Limit { price = targetPrice },
                          time_in_force = #time_in_force oldOrd,
                          price = targetPrice,
                          qty = targetLeaves,
                          timestamp = timestamp
                        }
                        val bWithNew = OrderBook.insertOrder bWithout newOrd
                      in
                        Result.ok {
                          book = bWithNew,
                          updated_order = newOrd,
                          effect = PriorityLost
                        }
                      end
            end
end
