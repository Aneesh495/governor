(* risk_limits.sml
 * Implementation of RiskLimits configuration.
 *)

structure RiskLimits :> RISK_LIMITS =
struct
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

  fun defaultLimits (clientId : Types.client_id) : limits =
      {
        client_id = clientId,
        max_order_qty = 10000,
        max_order_notional = 100000000, (* $1,000,000 *)
        price_collar_pct = 0.05,       (* 5% collar *)
        max_long_position = 50000,
        max_short_position = 50000,
        max_gross_exposure = 500000000, (* $5,000,000 *)
        max_orders_per_second = 500,
        smp_mode = Types.CancelNewest
      }

  fun create params = params

  fun toString (l : limits) : string =
      "RiskLimits(client=" ^ #client_id l ^
      ",maxQty=" ^ LargeInt.toString (#max_order_qty l) ^
      ",maxNotional=" ^ LargeInt.toString (#max_order_notional l) ^
      ",rateLimit=" ^ Int.toString (#max_orders_per_second l) ^ ")"
end
