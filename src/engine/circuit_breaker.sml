(* circuit_breaker.sml
 * Implementation of Circuit Breaker volatility bands and trading halt logic.
 *)

structure CircuitBreaker :> CIRCUIT_BREAKER =
struct
  datatype state =
      Active
    | Halted of { reason : string, halt_time : Types.timestamp_ns }
    | AuctionResume of { scheduled_cross_time : Types.timestamp_ns }

  type config = {
    collar_pct : real,
    halt_duration_ns : Types.timestamp_ns,
    reference_price : Types.price ref
  }

  type circuit_breaker = {
    config : config,
    current_state : state
  }

  fun create cfg =
      { config = cfg, current_state = Active }

  fun state (cb : circuit_breaker) = #current_state cb

  fun isHalted (cb : circuit_breaker) =
      case #current_state cb of
          Halted _ => true
        | _ => false

  fun lowerLimit (cb : circuit_breaker) : Types.price =
      let
        val refP = !(#reference_price (#config cb))
        val collar = #collar_pct (#config cb)
        val delta = LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST (Real.fromLargeInt (LargeInt.toLarge refP) * collar))
      in
        refP - delta
      end

  fun upperLimit (cb : circuit_breaker) : Types.price =
      let
        val refP = !(#reference_price (#config cb))
        val collar = #collar_pct (#config cb)
        val delta = LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST (Real.fromLargeInt (LargeInt.toLarge refP) * collar))
      in
        refP + delta
      end

  fun checkPrice (cb : circuit_breaker) (p : Types.price) : (unit, string) Result.result =
      case #current_state cb of
          Halted { reason, ... } => Result.err ("Trading is HALTED: " ^ reason)
        | _ =>
            let
              val low = lowerLimit cb
              val high = upperLimit cb
            in
              if p < low then
                Result.err ("Price " ^ Types.priceToString p ^ " breaches Limit-Down collar " ^ Types.priceToString low)
              else if p > high then
                Result.err ("Price " ^ Types.priceToString p ^ " breaches Limit-Up collar " ^ Types.priceToString high)
              else
                Result.ok ()
            end

  fun trip (cb : circuit_breaker) (reason : string) (ts : Types.timestamp_ns) : circuit_breaker =
      {
        config = #config cb,
        current_state = Halted { reason = reason, halt_time = ts }
      }

  fun checkResume (cb : circuit_breaker) (ts : Types.timestamp_ns) : circuit_breaker =
      case #current_state cb of
          Halted { halt_time, ... } =>
            if ts - halt_time >= #halt_duration_ns (#config cb) then
              {
                config = #config cb,
                current_state = AuctionResume { scheduled_cross_time = ts + 30000000000 } (* 30s auction *)
              }
            else cb
        | AuctionResume { scheduled_cross_time } =>
            if ts >= scheduled_cross_time then
              { config = #config cb, current_state = Active }
            else cb
        | Active => cb

  fun updateReferencePrice (cb : circuit_breaker) (newRef : Types.price) : circuit_breaker =
      let
        val () = #reference_price (#config cb) := newRef
      in
        cb
      end
end
