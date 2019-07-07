(* test_fees.sml
 * Unit tests for maker/taker fee schedules, tiered volume thresholds, and liquidity rebates.
 *)

val _ = use "test/test_framework.sig";
val _ = use "test/test_framework.sml";
val _ = use "src/core/result.sig";
val _ = use "src/core/result.sml";
val _ = use "src/core/types.sig";
val _ = use "src/core/types.sml";
val _ = use "src/risk/fee_calculator.sig";
val _ = use "src/risk/fee_calculator.sml";

structure TestFees =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("Exchange Fee Schedule and Liquidity Rebate Tests", fn () =>
        let
          val calc = FeeCalculator.create ()

          (* 1. Verify Tier classification *)
          val tier0 = FeeCalculator.determineTier 500
          val tier1 = FeeCalculator.determineTier 2000000
          val tier2 = FeeCalculator.determineTier 15000000
          val tier3 = FeeCalculator.determineTier 75000000

          val _ = TestFramework.assert ("Volume 500 is TierStandard", tier0 = FeeCalculator.TierStandard)
          val _ = TestFramework.assert ("Volume 2M is TierSilver", tier1 = FeeCalculator.TierSilver)
          val _ = TestFramework.assert ("Volume 15M is TierGold", tier2 = FeeCalculator.TierGold)
          val _ = TestFramework.assert ("Volume 75M is TierPlatinum", tier3 = FeeCalculator.TierPlatinum)

          (* 2. Test Taker Fee on $100,000 notional (1,000 shares @ $100.00) *)
          val price = toPrice 100
          val qty = 1000

          (* Standard tier: 8 bps = $80 *)
          val feeStdTaker = FeeCalculator.calculateFee calc Types.Taker FeeCalculator.TierStandard price qty
          val _ = TestFramework.assertEqualLargeInt ("Standard taker fee is $80", 80, feeStdTaker)

          (* Standard tier maker: -2 bps rebate = -$20 *)
          val rebateStdMaker = FeeCalculator.calculateFee calc Types.Maker FeeCalculator.TierStandard price qty
          val _ = TestFramework.assertEqualLargeInt ("Standard maker rebate is -$20", ~20, rebateStdMaker)

          (* Platinum tier taker: 2.5 bps = $25 *)
          val feePlatTaker = FeeCalculator.calculateFee calc Types.Taker FeeCalculator.TierPlatinum price qty
          val _ = TestFramework.assertEqualLargeInt ("Platinum taker fee is $25", 25, feePlatTaker)

          (* Platinum tier maker: -3.5 bps = -$35 *)
          val rebatePlatMaker = FeeCalculator.calculateFee calc Types.Maker FeeCalculator.TierPlatinum price qty
          val _ = TestFramework.assertEqualLargeInt ("Platinum maker rebate is -$35", ~35, rebatePlatMaker)
        in
          ()
        end
      )
end;

val _ = TestFees.run ();
