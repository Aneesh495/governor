(* test_trailing_stop.sml
 * Unit tests for TrailingStop order management, dynamic watermarks, and ratchet mechanics.
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
val _ = use "src/engine/trailing_stop.sig";
val _ = use "src/engine/trailing_stop.sml";

structure TestTrailingStop =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("TrailingStop Dynamic Ratchet Tests", fn () =>
        let
          val mgr = TrailingStop.create ()
          val _ = TestFramework.assertEqualInt ("Initial trailing count is 0", 0, TrailingStop.pendingCount mgr)

          (* 1. Sell Trailing Stop: Initial $100.00, Fixed Distance $2.00 *)
          val p100 = toPrice 100
          val pDist2 = toPrice 2
          val ord1 = Order.create {
            id = 201,
            client_id = "ALGO1",
            symbol = "MSFT",
            side = Types.Sell,
            order_type = Types.Market,
            time_in_force = Types.GTC,
            price = p100,
            qty = 100,
            timestamp = 1000
          }
          val mgr = TrailingStop.addTrailingStop mgr ord1 (TrailingStop.FixedDistance pDist2)
          val _ = TestFramework.assertEqualInt ("Pending trailing count is 1", 1, TrailingStop.pendingCount mgr)

          (* Check initial watermark & stop *)
          val (wm0, stop0) = valOf (TrailingStop.getStopInfo mgr 201)
          val _ = TestFramework.assertEqualLargeInt ("Initial watermark is $100", p100, wm0)
          val _ = TestFramework.assertEqualLargeInt ("Initial stop is $98", toPrice 98, stop0)

          (* Price rises to $105: Watermark ratchets to $105, stop ratchets to $103 *)
          val (mgr, trig1) = TrailingStop.updatePrice mgr "MSFT" (toPrice 105) 2000
          val _ = TestFramework.assertEqualInt ("No trigger at $105 rally", 0, List.length trig1)
          val (wm1, stop1) = valOf (TrailingStop.getStopInfo mgr 201)
          val _ = TestFramework.assertEqualLargeInt ("Ratcheted watermark is $105", toPrice 105, wm1)
          val _ = TestFramework.assertEqualLargeInt ("Ratcheted stop is $103", toPrice 103, stop1)

          (* Price retraces to $104: Watermark and stop hold firm *)
          val (mgr, trig2) = TrailingStop.updatePrice mgr "MSFT" (toPrice 104) 3000
          val _ = TestFramework.assertEqualInt ("No trigger at $104 pullback", 0, List.length trig2)
          val (wm2, stop2) = valOf (TrailingStop.getStopInfo mgr 201)
          val _ = TestFramework.assertEqualLargeInt ("Watermark holds at $105", toPrice 105, wm2)
          val _ = TestFramework.assertEqualLargeInt ("Stop holds at $103", toPrice 103, stop2)

          (* Price falls to $103: Triggered! *)
          val (mgr, trig3) = TrailingStop.updatePrice mgr "MSFT" (toPrice 103) 4000
          val _ = TestFramework.assertEqualInt ("Order triggered at $103", 1, List.length trig3)
          val _ = TestFramework.assertEqualInt ("Pending count drops to 0", 0, TrailingStop.pendingCount mgr)
          val executedOrd = List.hd trig3
          val _ = TestFramework.assertEqualLargeInt ("Executed order ID is 201", 201, #id executedOrd)

          (* 2. Test Cancellation *)
          val ord2 = Order.create {
            id = 202,
            client_id = "ALGO2",
            symbol = "MSFT",
            side = Types.Sell,
            order_type = Types.Market,
            time_in_force = Types.GTC,
            price = p100,
            qty = 50,
            timestamp = 5000
          }
          val mgr = TrailingStop.addTrailingStop mgr ord2 (TrailingStop.Percentage 5.0)
          val cancelRes = TrailingStop.cancelTrailingStop mgr 202
          val _ = TestFramework.assert ("Cancel trailing stop succeeds", Option.isSome cancelRes)
          val (_, mgrAfterCancel) = valOf cancelRes
          val _ = TestFramework.assertEqualInt ("Pending count after cancel is 0", 0, TrailingStop.pendingCount mgrAfterCancel)
        in
          ()
        end
      )
end;

val _ = TestTrailingStop.run ();
