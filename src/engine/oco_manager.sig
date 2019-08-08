(* oco_manager.sig
 * One-Cancels-the-Other (OCO) paired contingent order lifecycle manager.
 *)

signature OCO_MANAGER =
sig
  type oco_id = LargeInt.int
  type order_id = Types.order_id

  type oco_pair = {
    id : oco_id,
    first_order_id : order_id,
    second_order_id : order_id,
    symbol : Types.symbol_id,
    created_at : Types.timestamp_ns
  }

  type manager

  val create : unit -> manager
  val registerPair : manager -> oco_id -> order_id -> order_id -> Types.symbol_id -> Types.timestamp_ns -> manager
  val findSibling : manager -> order_id -> order_id option
  val onOrderFilled : manager -> order_id -> (manager * order_id option)
  val onOrderCancelled : manager -> order_id -> (manager * order_id option)

  val activePairsCount : manager -> int
end
