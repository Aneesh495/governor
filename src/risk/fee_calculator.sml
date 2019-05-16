(* fee_calculator.sml
 * Implementation of Maker/Taker exchange fee schedules and rebates.
 *)

structure FeeCalculator :> FEE_CALCULATOR =
struct
  datatype fee_tier =
      TierStandard
    | TierSilver
    | TierGold
    | TierPlatinum

  type fee_schedule = {
    tier : fee_tier,
    maker_fee_bps : real,
    taker_fee_bps : real
  }

  type calculator = unit

  fun create () = ()

  fun getSchedule () tier =
      case tier of
          TierStandard => { tier = TierStandard, maker_fee_bps = ~2.0, taker_fee_bps = 8.0 }   (* -2 bps rebate, 8 bps fee *)
        | TierSilver =>   { tier = TierSilver,   maker_fee_bps = ~2.5, taker_fee_bps = 6.0 }   (* -2.5 bps rebate, 6 bps fee *)
        | TierGold =>     { tier = TierGold,     maker_fee_bps = ~3.0, taker_fee_bps = 4.0 }   (* -3 bps rebate, 4 bps fee *)
        | TierPlatinum => { tier = TierPlatinum, maker_fee_bps = ~3.5, taker_fee_bps = 2.5 }   (* -3.5 bps rebate, 2.5 bps fee *)

  fun determineTier (monthlyVolume : Types.qty) : fee_tier =
      if monthlyVolume >= 50000000 then TierPlatinum
      else if monthlyVolume >= 10000000 then TierGold
      else if monthlyVolume >= 1000000 then TierSilver
      else TierStandard

  fun calculateFee () (role : Types.liquidity_indicator) (tier : fee_tier) (p : Types.price) (q : Types.qty) : LargeInt.int =
      let
        val sched = getSchedule () tier
        val bps = case role of
                      Types.Maker => #maker_fee_bps sched
                    | Types.Taker => #taker_fee_bps sched
        val notional = (p * q) div Types.priceScale
        val feeReal = (Real.fromLargeInt (LargeInt.toLarge notional)) * (bps / 10000.0)
      in
        LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST feeReal)
      end
end
