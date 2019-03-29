(* price_level.sig
 * Aggregated price level structure containing total volume and FIFO queue of orders.
 *)

signature PRICE_LEVEL =
sig
  type price_level = {
    price : Types.price,
    total_qty : Types.qty,
    order_count : int,
    orders : Order.order FifoQueue.queue
  }

  val create : Types.price -> price_level
  val isEmpty : price_level -> bool

  (* Queue modifications *)
  val addOrder : price_level -> Order.order -> price_level
  val peekFront : price_level -> Order.order option
  val popFront : price_level -> (Order.order * price_level) option

  (* Remove or update specific order *)
  val removeOrder : price_level -> Types.order_id -> (Order.order * price_level) option
  val updateFrontOrder : price_level -> Order.order -> price_level

  (* Inspection and conversion *)
  val getOrders : price_level -> Order.order list
  val toString : price_level -> string
end
