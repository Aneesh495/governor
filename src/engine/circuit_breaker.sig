(* circuit_breaker.sig
 * Volatility guards, Limit-Up / Limit-Down bands, and exchange trading halt state.
 *)

signature CIRCUIT_BREAKER =
sig
  datatype state =
      Active
    | Halted of { reason : string, halt_time : Types.timestamp_ns }
    | AuctionResume of { scheduled_cross_time : Types.timestamp_ns }

  type config = {
    collar_pct : real,           (* E.g. 0.05 for 5% max deviation from reference *)
    halt_duration_ns : Types.timestamp_ns, (* E.g. 5 minutes in nanoseconds *)
    reference_price : Types.price ref
  }

  type circuit_breaker

  val create : config -> circuit_breaker
  val state : circuit_breaker -> state
  val isHalted : circuit_breaker -> bool

  (* Check if order price is within collars *)
  val checkPrice : circuit_breaker -> Types.price -> (unit, string) Result.result

  (* Price limits *)
  val lowerLimit : circuit_breaker -> Types.price
  val upperLimit : circuit_breaker -> Types.price

  (* State transitions *)
  val trip : circuit_breaker -> string -> Types.timestamp_ns -> circuit_breaker
  val checkResume : circuit_breaker -> Types.timestamp_ns -> circuit_breaker
  val updateReferencePrice : circuit_breaker -> Types.price -> circuit_breaker
end
