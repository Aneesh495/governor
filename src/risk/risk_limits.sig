(* risk_limits.sig
 * Trader risk limits configuration and validation thresholds.
 *)

signature RISK_LIMITS =
sig
  type limits = {
    client_id : Types.client_id,
    max_order_qty : Types.qty,
    max_order_notional : LargeInt.int,
    price_collar_pct : real,
    max_long_position : Types.qty,
    max_short_position : Types.qty,
    max_gross_exposure : LargeInt.int,
    max_orders_per_second : int,
    smp_mode : Types.smp_mode
  }

  val defaultLimits : Types.client_id -> limits

  val create : {
    client_id : Types.client_id,
    max_order_qty : Types.qty,
    max_order_notional : LargeInt.int,
    price_collar_pct : real,
    max_long_position : Types.qty,
    max_short_position : Types.qty,
    max_gross_exposure : LargeInt.int,
    max_orders_per_second : int,
    smp_mode : Types.smp_mode
  } -> limits

  val toString : limits -> string
end
