(* test_microprice.sml
 * Unit tests for VWAP tracking, TWAP, Microprice estimation, and Order Flow Imbalance.
 *)

val _ = use "test/test_framework.sig";
val _ = use "test/test_framework.sml";
val _ = use "src/core/result.sig";
val _ = use "src/core/result.sml";
val _ = use "src/core/types.sig";
val _ = use "src/core/types.sml";
val _ = use "src/core/fifo_queue.sig";
val _ = use "src/core/fifo_queue.sml";
val _ = use "src/core/red_black_map.sig";
val _ = use "src/core/red_black_map.sml";
val _ = use "src/book/order.sig";
val _ = use "src/book/order.sml";
val _ = use "src/book/price_level.sig";
val _ = use "src/book/price_level.sml";
val _ = use "src/book/order_book.sig";
val _ = use "src/book/order_book.sml";
val _ = use "src/engine/vwap_calculator.sig";
val _ = use "src/engine/vwap_calculator.sml";
val _ = use "src/engine/microprice.sig";
val _ = use "src/engine/microprice.sml";

structure TestMicroprice =
struct
  fun toPrice (dollars : LargeInt.int) : Types.price =
      dollars * Types.priceScale

  fun runVwapTests () =
      TestFramework.runSuite ("VWAP and TWAP Tracking Tests", fn () =>
        let
          val tracker = VwapCalculator.create "AAPL"

          (* Initial tracker has no trades *)
          val _ = TestFramework.assert ("Initial VWAP is NONE", Option.isSome (VwapCalculator.currentVwap tracker) = false)
          val _ = TestFramework.assertEqualLargeInt ("Initial volume is 0", 0, VwapCalculator.totalVolume tracker)

          (* Trade 1: 100 shares @ $10.00 at t = 1000 *)
          val p1 = toPrice 10
          val t1 = VwapCalculator.recordTrade tracker p1 100 1000

          (* Trade 2: 100 shares @ $20.00 at t = 2000 *)
          val p2 = toPrice 20
          val t2 = VwapCalculator.recordTrade t1 p2 100 2000

          val vwapOpt = VwapCalculator.currentVwap t2
          val expectedVwap = toPrice 15
        in
          TestFramework.assert ("VWAP is calculated", Option.isSome vwapOpt);
          TestFramework.assertEqualLargeInt ("VWAP of 100@$10 and 100@$20 is $15", expectedVwap, valOf vwapOpt);
          TestFramework.assertEqualLargeInt ("Total volume is 200", 200, VwapCalculator.totalVolume t2);

          (* Trade 3: 200 shares @ $30.00 -> total vol 400, notional = 1000 + 2000 + 6000 = 9000 -> VWAP = 9000 / 400 = 22.50 *)
          let
            val p3 = toPrice 30
            val t3 = VwapCalculator.recordTrade t2 p3 200 3000
            val vwap3 = valOf (VwapCalculator.currentVwap t3)
            val expectedVwap3 = (22 * Types.priceScale) + (50 * (Types.priceScale div 100))
          in
            TestFramework.assertEqualLargeInt ("VWAP with 3 trades is 22.50", expectedVwap3, vwap3);
            TestFramework.assertEqualLargeInt ("Total volume is 400", 400, VwapCalculator.totalVolume t3)
          end
        end
      )

  fun runMicropriceTests () =
      TestFramework.runSuite ("Microprice and Order Flow Imbalance Tests", fn () =>
        let
          val book = OrderBook.create "AAPL"

          (* Microprice on empty book is NONE *)
          val _ = TestFramework.assert ("Empty book microprice is NONE",
                    Option.isSome (Microprice.calculateMicroprice book) = false)

          (* Bid: 100 shares @ $10.00 *)
          val pBid = toPrice 10
          val bid = Order.create {
            id = 1,
            client_id = "BIDDER",
            symbol = "AAPL",
            side = Types.Buy,
            order_type = Types.Limit { price = pBid },
            time_in_force = Types.GTC,
            price = pBid,
            qty = 100,
            timestamp = 100
          }
          val book = OrderBook.insertOrder book bid

          (* Ask: 300 shares @ $11.00 *)
          val pAsk = toPrice 11
          val ask = Order.create {
            id = 2,
            client_id = "ASKER",
            symbol = "AAPL",
            side = Types.Sell,
            order_type = Types.Limit { price = pAsk },
            time_in_force = Types.GTC,
            price = pAsk,
            qty = 300,
            timestamp = 100
          }
          val book = OrderBook.insertOrder book ask

          (* Microprice = (100 * 11 + 300 * 10) / 400 = 4100 / 400 = 10.25 *)
          val microOpt = Microprice.calculateMicroprice book
          val expectedMicro = (10 * Types.priceScale) + (25 * (Types.priceScale div 100))

          (* OFI Imbalance = (100 - 300) / 400 = -0.50 *)
          val ofiOpt = Microprice.calculateImbalanceRatio book
        in
          TestFramework.assert ("Microprice computed", Option.isSome microOpt);
          TestFramework.assertEqualLargeInt ("Microprice is 10.25 (skewed toward heavy bid resistance)",
                                             expectedMicro, valOf microOpt);
          TestFramework.assert ("OFI computed", Option.isSome ofiOpt);
          let
            val ofi = valOf ofiOpt
            val diff = abs (ofi - (~0.50))
          in
            TestFramework.assert ("OFI is -0.50", diff < 0.001)
          end
        end
      )

  fun run () =
      (runVwapTests ();
       runMicropriceTests ())
end;

val _ = TestMicroprice.run ();
