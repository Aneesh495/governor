(* order.sig
 * Order record structure, attribute mutations, and lifecycle transitions.
 *)

signature ORDER =
sig
  type order = {
    id : Types.order_id,
    client_id : Types.client_id,
    symbol : Types.symbol_id,
    side : Types.side,
    order_type : Types.order_type,
    time_in_force : Types.time_in_force,
    price : Types.price,
    initial_qty : Types.qty,
    leaves_qty : Types.qty,
    cum_qty : Types.qty,
    peak_qty : Types.qty,
    hidden_qty : Types.qty,
    status : Types.order_status,
    created_at : Types.timestamp_ns,
    updated_at : Types.timestamp_ns
  }

  val create : {
    id : Types.order_id,
    client_id : Types.client_id,
    symbol : Types.symbol_id,
    side : Types.side,
    order_type : Types.order_type,
    time_in_force : Types.time_in_force,
    price : Types.price,
    qty : Types.qty,
    timestamp : Types.timestamp_ns
  } -> order

  val isFilled : order -> bool
  val isCancelled : order -> bool
  val isActive : order -> bool
  val isResting : order -> bool

  (* Fill execution *)
  val executeFill : order -> Types.qty -> Types.timestamp_ns -> order

  (* Iceberg replenishment: replenishes peak from hidden *)
  val replenishIceberg : order -> Types.timestamp_ns -> order

  (* Cancellation and rejection *)
  val cancel : order -> Types.timestamp_ns -> order
  val reject : order -> string -> Types.timestamp_ns -> order
  val expire : order -> Types.timestamp_ns -> order

  (* Stringification and debug representations *)
  val toString : order -> string
end
