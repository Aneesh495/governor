(* trailing_stop.sig
 * Trailing stop order manager with dynamic peak and trough water-mark tracking.
 *)

signature TRAILING_STOP =
sig
  type order_id = Types.order_id
  type price = Types.price
  type qty = Types.qty
  type symbol_id = Types.symbol_id

  datatype trail_mode =
      FixedDistance of price
    | Percentage of real

  type trailing_order = {
    order : Order.order,
    mode : trail_mode,
    water_mark : price ref,     (* Peak for sell stops, trough for buy stops *)
    current_stop : price ref    (* Dynamic trigger price *)
  }

  type manager

  val create : unit -> manager
  val addTrailingStop : manager -> Order.order -> trail_mode -> manager
  val cancelTrailingStop : manager -> order_id -> (trailing_order * manager) option

  (* Updates water marks on market trade ticks and releases triggered orders *)
  val updatePrice : manager -> symbol_id -> price -> Types.timestamp_ns -> (manager * Order.order list)

  val getStopInfo : manager -> order_id -> (price * price) option (* returns (water_mark, current_stop) *)
  val pendingCount : manager -> int
end
