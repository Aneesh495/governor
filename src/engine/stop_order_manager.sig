(* stop_order_manager.sig
 * Off-book resting stop orders triggered dynamically by trade price updates.
 *)

signature STOP_ORDER_MANAGER =
sig
  type manager

  val create : unit -> manager
  val addStopOrder : manager -> Order.order -> manager
  val cancelStopOrder : manager -> Types.order_id -> (Order.order * manager) option

  (* Evaluates trade tick price and releases triggered orders *)
  val evaluateTick : manager -> Types.symbol_id -> Types.price -> Types.timestamp_ns -> (manager * Order.order list)

  val pendingCount : manager -> int
end
