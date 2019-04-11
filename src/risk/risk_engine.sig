(* risk_engine.sig
 * Comprehensive Pre-Trade Risk Management Gateway coordinating all risk controls.
 *)

signature RISK_ENGINE =
sig
  type engine

  val create : unit -> engine

  val registerClient : engine -> Types.client_id -> RiskLimits.limits -> LargeInt.int -> engine
  val getLimits : engine -> Types.client_id -> RiskLimits.limits option
  val getTraderState : engine -> Types.client_id -> TraderState.state option

  (* Pre-trade order validation *)
  val validateOrder : {
    engine : engine,
    book : OrderBook.book,
    order : Order.order,
    timestamp : Types.timestamp_ns
  } -> (engine, string) Result.result

  (* Post-trade state updates *)
  val recordTradeExecution : engine -> Trade.trade -> engine
end
