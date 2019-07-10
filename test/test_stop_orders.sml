(* test_stop_orders.sml
 * Unit tests for off-book resting stop orders and dynamic execution triggers.
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
val _ = use "src/engine/stop_order_manager.sig";
val _ = use "src/engine/stop_order_manager.sml";

structure TestStopOrders =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("Stop-Loss and Stop-Limit Trigger Tests", fn () =>
        let
          val mgr = StopOrderManager.create ()
          val _ = TestFramework.assertEqualInt ("Initial pending stops is 0", 0, StopOrderManager.pendingCount mgr)

          (* 1. Create Sell Stop-Loss at $95.00 *)
          val stopLossP = toPrice 95
          val stopLossOrd = Order.create {
            id = 101,
            client_id = "TRADER1",
            symbol = "AAPL",
            side = Types.Sell,
            order_type = Types.StopLoss { stop_price = stopLossP },
            time_in_force = Types.GTC,
            price = stopLossP,
            qty = 50,
            timestamp = 1000
          }
          val mgr = StopOrderManager.addStopOrder mgr stopLossOrd
          val _ = TestFramework.assertEqualInt ("Pending stops after add is 1", 1, StopOrderManager.pendingCount mgr)

          (* 2. Trade tick at $98.00 -> should not trigger *)
          val (mgr, triggered1) = StopOrderManager.evaluateTick mgr "AAPL" (toPrice 98) 2000
          val _ = TestFramework.assertEqualInt ("No stops triggered at $98.00", 0, List.length triggered1)
          val _ = TestFramework.assertEqualInt ("Pending count remains 1", 1, StopOrderManager.pendingCount mgr)

          (* 3. Trade tick drops to $94.50 -> should trigger Sell Stop-Loss into Market order *)
          val (mgr, triggered2) = StopOrderManager.evaluateTick mgr "AAPL" (toPrice 94) 3000
          val _ = TestFramework.assertEqualInt ("1 stop triggered at $94.00", 1, List.length triggered2)
          val _ = TestFramework.assertEqualInt ("Pending count drops to 0", 0, StopOrderManager.pendingCount mgr)

          val trigOrd = List.hd triggered2
          val _ = TestFramework.assertEqualLargeInt ("Triggered order ID is 101", 101, #id trigOrd)
          val _ = TestFramework.assert ("Triggered order converted to Market",
                    case #order_type trigOrd of Types.Market => true | _ => false)

          (* 4. Test Buy Stop-Limit: triggers on upside breakout *)
          val breakoutP = toPrice 105
          val limitP = toPrice 106
          val stopLimitOrd = Order.create {
            id = 102,
            client_id = "TRADER2",
            symbol = "AAPL",
            side = Types.Buy,
            order_type = Types.StopLimit { stop_price = breakoutP, limit_price = limitP },
            time_in_force = Types.GTC,
            price = limitP,
            qty = 100,
            timestamp = 4000
          }
          val mgr = StopOrderManager.addStopOrder mgr stopLimitOrd

          (* Tick at 104 -> not triggered *)
          val (mgr, trig3) = StopOrderManager.evaluateTick mgr "AAPL" (toPrice 104) 5000
          val _ = TestFramework.assertEqualInt ("Buy stop not triggered at 104", 0, List.length trig3)

          (* Tick at 105 -> triggered! *)
          val (mgr, trig4) = StopOrderManager.evaluateTick mgr "AAPL" (toPrice 105) 6000
          val _ = TestFramework.assertEqualInt ("Buy stop triggered at 105", 1, List.length trig4)
          val trigLimitOrd = List.hd trig4
          val _ = TestFramework.assert ("Triggered order converted to Limit",
                    case #order_type trigLimitOrd of Types.Limit { price } => price = limitP | _ => false)

          (* 5. Cancellation test *)
          val stopToCancel = Order.create {
            id = 103,
            client_id = "TRADER3",
            symbol = "AAPL",
            side = Types.Sell,
            order_type = Types.StopLoss { stop_price = toPrice 90 },
            time_in_force = Types.GTC,
            price = toPrice 90,
            qty = 20,
            timestamp = 7000
          }
          val mgr = StopOrderManager.addStopOrder mgr stopToCancel
          val cancelRes = StopOrderManager.cancelStopOrder mgr 103
          val _ = TestFramework.assert ("Cancel stop succeeded", Option.isSome cancelRes)
          val (cancOrd, mgrFinal) = valOf cancelRes
          val _ = TestFramework.assertEqualLargeInt ("Cancelled stop ID is 103", 103, #id cancOrd)
          val _ = TestFramework.assertEqualInt ("Pending count after cancel is 0", 0, StopOrderManager.pendingCount mgrFinal)
        in
          ()
        end
      )
end;

val _ = TestStopOrders.run ();
