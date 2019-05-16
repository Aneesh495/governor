(* fee_calculator.sig
 * Maker/Taker exchange fee schedules, liquidity rebates, and tiered volume discounts.
 *)

signature FEE_CALCULATOR =
sig
  datatype fee_tier =
      TierStandard
    | TierSilver
    | TierGold
    | TierPlatinum

  type fee_schedule = {
    tier : fee_tier,
    maker_fee_bps : real,  (* Negative represents rebate *)
    taker_fee_bps : real
  }

  type calculator

  val create : unit -> calculator
  val getSchedule : calculator -> fee_tier -> fee_schedule
  val determineTier : Types.qty -> fee_tier

  (* Computes fee (or rebate if negative) in fixed-point cents *)
  val calculateFee : calculator -> Types.liquidity_indicator -> fee_tier -> Types.price -> Types.qty -> LargeInt.int
end
