(* avellaneda_stoikov.sml
 * Implementation of Avellaneda-Stoikov market making equations.
 *)

structure AvellanedaStoikov :> AVELLANEDA_STOIKOV =
struct
  type model_params = {
    risk_aversion : real,
    volatility : real,
    order_intensity_kappa : real,
    time_horizon_sec : real
  }

  type quote = {
    reservation_price : Types.price,
    optimal_bid : Types.price,
    optimal_ask : Types.price,
    optimal_spread : Types.price
  }

  fun computeQuotes (params : model_params) { mid_price, inventory, elapsed_time_sec } : quote =
      let
        val gamma = #risk_aversion params
        val sigma = #volatility params
        val kappa = #order_intensity_kappa params
        val tRemaining = Real.max (0.01, #time_horizon_sec params - elapsed_time_sec)

        val s = Types.toDollars mid_price
        val q = Real.fromLargeInt (LargeInt.toLarge inventory)

        (* Reservation price: r(s, q, t) = s - q * gamma * sigma^2 * (T - t) *)
        val variance = sigma * sigma
        val reservationDollars = s - (q * gamma * variance * tRemaining)

        (* Optimal half spread: delta = (1 / gamma) * ln(1 + gamma / kappa) *)
        val halfSpreadDollars =
            if gamma > 0.0 andalso kappa > 0.0 then
              (1.0 / gamma) * Math.ln (1.0 + (gamma / kappa)) + (0.5 * gamma * variance * tRemaining)
            else 0.05

        val bidDollars = reservationDollars - halfSpreadDollars
        val askDollars = reservationDollars + halfSpreadDollars
        val spreadDollars = askDollars - bidDollars

        val resP = Types.fromDollars reservationDollars
        val bidP = Types.fromDollars (Real.max (0.01, bidDollars))
        val askP = Types.fromDollars (Real.max (0.01, askDollars))
        val spP = Types.fromDollars spreadDollars
      in
        {
          reservation_price = resP,
          optimal_bid = bidP,
          optimal_ask = askP,
          optimal_spread = spP
        }
      end
end
