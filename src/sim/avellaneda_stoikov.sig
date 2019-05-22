(* avellaneda_stoikov.sig
 * Classical Avellaneda-Stoikov optimal high-frequency market making model.
 *)

signature AVELLANEDA_STOIKOV =
sig
  type model_params = {
    risk_aversion : real,       (* gamma *)
    volatility : real,          (* sigma *)
    order_intensity_kappa : real, (* kappa *)
    time_horizon_sec : real     (* T *)
  }

  type quote = {
    reservation_price : Types.price,
    optimal_bid : Types.price,
    optimal_ask : Types.price,
    optimal_spread : Types.price
  }

  (* Computes optimal Avellaneda-Stoikov quotes for current inventory and time remaining *)
  val computeQuotes : model_params -> {
    mid_price : Types.price,
    inventory : Types.qty,
    elapsed_time_sec : real
  } -> quote
end
