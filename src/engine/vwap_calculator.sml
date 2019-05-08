(* vwap_calculator.sml
 * Implementation of continuous VWAP and TWAP calculations.
 *)

structure VwapCalculator :> VWAP_CALCULATOR =
struct
  type tracker = {
    symbol : Types.symbol_id,
    cum_volume : Types.qty,
    cum_notional : LargeInt.int,
    first_ts : Types.timestamp_ns,
    last_ts : Types.timestamp_ns,
    last_price : Types.price option,
    twap_weighted_sum : LargeInt.int
  }

  fun create (sym : Types.symbol_id) : tracker =
      {
        symbol = sym,
        cum_volume = 0,
        cum_notional = 0,
        first_ts = 0,
        last_ts = 0,
        last_price = NONE,
        twap_weighted_sum = 0
      }

  fun recordTrade (t : tracker) (p : Types.price) (q : Types.qty) (ts : Types.timestamp_ns) : tracker =
      let
        val notional = (p * q) div Types.priceScale
        val newVol = #cum_volume t + q
        val newNotional = #cum_notional t + notional
        val newFirstTs = if #cum_volume t = 0 then ts else #first_ts t

        (* Update TWAP sum based on time elapsed since last trade *)
        val newTwapSum =
            case (#last_price t, #last_ts t) of
                (SOME prevP, prevTs) =>
                  let val dt = ts - prevTs in
                    #twap_weighted_sum t + (prevP * dt)
                  end
              | _ => #twap_weighted_sum t
      in
        {
          symbol = #symbol t,
          cum_volume = newVol,
          cum_notional = newNotional,
          first_ts = newFirstTs,
          last_ts = ts,
          last_price = SOME p,
          twap_weighted_sum = newTwapSum
        }
      end

  fun currentVwap (t : tracker) : Types.price option =
      if #cum_volume t = 0 then NONE
      else
        SOME ((#cum_notional t * Types.priceScale) div #cum_volume t)

  fun currentTwap (t : tracker) : Types.price option =
      let
        val totalDt = #last_ts t - #first_ts t
      in
        if totalDt <= 0 then #last_price t
        else
          SOME (#twap_weighted_sum t div totalDt)
      end

  fun totalVolume (t : tracker) = #cum_volume t
  fun totalNotional (t : tracker) = #cum_notional t

  fun reset (t : tracker) = create (#symbol t)

  fun toString (t : tracker) : string =
      let
        val vwapStr = case currentVwap t of SOME v => Types.priceToString v | NONE => "N/A"
        val twapStr = case currentTwap t of SOME v => Types.priceToString v | NONE => "N/A"
      in
        "VWAP[" ^ #symbol t ^ "]: vwap=" ^ vwapStr ^ ",twap=" ^ twapStr ^ ",vol=" ^ LargeInt.toString (#cum_volume t)
      end
end
