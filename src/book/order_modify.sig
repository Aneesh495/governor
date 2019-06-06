(* order_modify.sig
 * Order modification (Cancel-Replace) rules preserving or re-queueing FIFO priority.
 *)

signature ORDER_MODIFY =
sig
  datatype priority_effect =
      PriorityPreserved
    | PriorityLost

  type modify_result = {
    book : OrderBook.book,
    updated_order : Order.order,
    effect : priority_effect
  }

  val modifyOrder : {
    book : OrderBook.book,
    order_id : Types.order_id,
    new_price : Types.price option,
    new_qty : Types.qty option,
    timestamp : Types.timestamp_ns
  } -> (modify_result, string) Result.result
end
