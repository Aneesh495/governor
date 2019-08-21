(* test_bracket.sml
 * Unit tests for Bracket Order entry-to-exit automation (take-profit and stop-loss generation).
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
val _ = use "src/engine/bracket_order.sig";
val _ = use "src/engine/bracket_order.sml";

structure TestBracket =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("Bracket Order Automation Tests", fn () =>
        let
          val mgr = BracketOrder.create ()
          val _ = TestFramework.assertEqualInt ("Initial active brackets is 0", 0, BracketOrder.activeBracketCount mgr)

          (* 1. Create Entry Order: Buy 100 TSLA @ $200.00 *)
          val pEntry = toPrice 200
          val pTp = toPrice 215
          val pSl = toPrice 192

          val entryOrd = Order.create {
            id = 501,
            client_id = "QUANT_STRAT",
            symbol = "TSLA",
            side = Types.Buy,
            order_type = Types.Limit { price = pEntry },
            time_in_force = Types.GTC,
            price = pEntry,
            qty = 100,
            timestamp = 1000
          }

          val mgr = BracketOrder.registerBracket mgr 1 entryOrd pTp pSl
          val _ = TestFramework.assertEqualInt ("Active brackets count is 1", 1, BracketOrder.activeBracketCount mgr)

          (* 2. Simulate Entry Order Execution -> Spawns Take-Profit and Stop-Loss orders *)
          val (mgrAfterFill, exitsOpt) = BracketOrder.onEntryFilled mgr 501 2000
          val _ = TestFramework.assert ("Exit orders spawned on entry fill", Option.isSome exitsOpt)
          val _ = TestFramework.assertEqualInt ("Active brackets drops to 0", 0, BracketOrder.activeBracketCount mgrAfterFill)

          val (tpOrd, slOrd) = valOf exitsOpt

          (* Verify Take-Profit order *)
          val _ = TestFramework.assert ("Take-profit side is Sell", #side tpOrd = Types.Sell)
          val _ = TestFramework.assertEqualLargeInt ("Take-profit qty is 100", 100, #initial_qty tpOrd)
          val _ = TestFramework.assertEqualLargeInt ("Take-profit price is $215", pTp, #price tpOrd)
          val _ = TestFramework.assert ("Take-profit type is Limit",
                    case #order_type tpOrd of Types.Limit { price } => price = pTp | _ => false)

          (* Verify Stop-Loss order *)
          val _ = TestFramework.assert ("Stop-loss side is Sell", #side slOrd = Types.Sell)
          val _ = TestFramework.assertEqualLargeInt ("Stop-loss qty is 100", 100, #initial_qty slOrd)
          val _ = TestFramework.assertEqualLargeInt ("Stop-loss price is $192", pSl, #price slOrd)
          val _ = TestFramework.assert ("Stop-loss type is StopLoss",
                    case #order_type slOrd of Types.StopLoss { stop_price } => stop_price = pSl | _ => false)

          (* 3. Test Entry Order Cancellation *)
          val entryOrd2 = Order.create {
            id = 601,
            client_id = "QUANT_STRAT",
            symbol = "TSLA",
            side = Types.Sell,
            order_type = Types.Limit { price = toPrice 200 },
            time_in_force = Types.GTC,
            price = toPrice 200,
            qty = 50,
            timestamp = 3000
          }
          val mgr2 = BracketOrder.registerBracket mgrAfterFill 2 entryOrd2 (toPrice 185) (toPrice 208)
          val _ = TestFramework.assertEqualInt ("Active brackets count is 1 again", 1, BracketOrder.activeBracketCount mgr2)

          val mgrAfterCancel = BracketOrder.onEntryCancelled mgr2 601
          val _ = TestFramework.assertEqualInt ("Bracket cancelled without firing exits", 0, BracketOrder.activeBracketCount mgrAfterCancel)
        in
          ()
        end
      )
end;

val _ = TestBracket.run ();
