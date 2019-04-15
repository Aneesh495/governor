(* synthetic_trader.sig
 * Algorithmic participant behaviors: MarketMaker, Momentum, Noise, and VWAP slicer.
 *)

signature SYNTHETIC_TRADER =
sig
  datatype strategy =
      MarketMaker of {
        half_spread : Types.price,
        quote_qty : Types.qty,
        inventory_skew_factor : real
      }
    | Momentum of {
        momentum_threshold : real,
        order_qty : Types.qty
      }
    | Noise of {
        arrival_rate : real,
        typical_qty : Types.qty
      }
    | VwapSlicer of {
        parent_qty : Types.qty,
        slices_remaining : int,
        interval_ns : Types.timestamp_ns,
        side : Types.side
      }

  type trader = {
    client_id : Types.client_id,
    strategy : strategy,
    next_action_time : Types.timestamp_ns
  }

  val createMarketMaker : Types.client_id -> Types.price -> Types.qty -> real -> trader
  val createMomentumTrader : Types.client_id -> real -> Types.qty -> trader
  val createNoiseTrader : Types.client_id -> real -> Types.qty -> trader
  val createVwapSlicer : Types.client_id -> Types.qty -> int -> Types.timestamp_ns -> Types.side -> trader

  (* Generate orders for the current simulation step *)
  val tickTrader : trader -> {
    book : OrderBook.book,
    current_time : Types.timestamp_ns,
    inventory : Types.qty,
    nextOrderId : unit -> Types.order_id
  } -> (trader * Order.order list)
end
