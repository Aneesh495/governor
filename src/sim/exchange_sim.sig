(* exchange_sim.sig
 * Integrated multi-symbol simulated market environment.
 *)

signature EXCHANGE_SIM =
sig
  type sim

  val create : unit -> sim
  val addSymbol : sim -> Types.symbol_id -> sim
  val registerTrader : sim -> SyntheticTrader.trader -> sim

  (* Step the market clock forward *)
  val step : sim -> Types.timestamp_ns -> sim

  (* External manual order submission *)
  val submitOrder : sim -> Order.order -> (sim * Trade.trade list, string) Result.result

  (* Inspection *)
  val getBook : sim -> Types.symbol_id -> OrderBook.book option
  val getL1Feed : sim -> Level1Feed.feed
  val getJournal : sim -> EventJournal.journal
  val totalTrades : sim -> int
  val totalVolume : sim -> Types.qty
end
