(* trader_state.sig
 * Account tracking for positions, cash, margins, and message rate history.
 *)

signature TRADER_STATE =
sig
  type state

  val create : Types.client_id -> LargeInt.int -> state
  val clientId : state -> Types.client_id
  val cashBalance : state -> LargeInt.int
  val realizedPnL : state -> LargeInt.int

  val getPosition : state -> Types.symbol_id -> Types.qty
  val updatePositionOnTrade : state -> Types.symbol_id -> Types.side -> Types.qty -> Types.price -> state

  val addOpenExposure : state -> LargeInt.int -> state
  val removeOpenExposure : state -> LargeInt.int -> state
  val openExposure : state -> LargeInt.int

  (* Rate limiting check (sliding 1-second window) *)
  val recordMessage : state -> Types.timestamp_ns -> state
  val messageRateInLastSecond : state -> Types.timestamp_ns -> int
end
