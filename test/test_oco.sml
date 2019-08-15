(* test_oco.sml
 * Unit tests for One-Cancels-the-Other (OCO) order pairs and sibling cancellation triggers.
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
val _ = use "src/engine/oco_manager.sig";
val _ = use "src/engine/oco_manager.sml";

structure TestOco =
struct
  fun run () =
      TestFramework.runSuite ("OCO (One-Cancels-the-Other) Pair Lifecycle Tests", fn () =>
        let
          val mgr = OcoManager.create ()
          val _ = TestFramework.assertEqualInt ("Initial active pairs is 0", 0, OcoManager.activePairsCount mgr)

          (* 1. Register Pair 1: Order 301 (take-profit limit) and Order 302 (stop-loss) *)
          val mgr = OcoManager.registerPair mgr 1 301 302 "NVDA" 1000
          val _ = TestFramework.assertEqualInt ("Active pairs count is 1", 1, OcoManager.activePairsCount mgr)

          (* 2. Test sibling bi-directional lookup *)
          val sib1 = OcoManager.findSibling mgr 301
          val sib2 = OcoManager.findSibling mgr 302
          val sibUnknown = OcoManager.findSibling mgr 999

          val _ = TestFramework.assertEqualLargeInt ("Sibling of 301 is 302", 302, valOf sib1)
          val _ = TestFramework.assertEqualLargeInt ("Sibling of 302 is 301", 301, valOf sib2)
          val _ = TestFramework.assert ("Unknown order has no sibling", Option.isSome sibUnknown = false)

          (* 3. Simulate take-profit fill on Order 301 *)
          val (mgrAfterFill, cancelTargetOpt) = OcoManager.onOrderFilled mgr 301
          val _ = TestFramework.assert ("Cancel target emitted for sibling", Option.isSome cancelTargetOpt)
          val _ = TestFramework.assertEqualLargeInt ("Target to cancel is 302", 302, valOf cancelTargetOpt)
          val _ = TestFramework.assertEqualInt ("Active pairs drops to 0 after fill", 0, OcoManager.activePairsCount mgrAfterFill)

          (* Verify neither order has an active sibling anymore *)
          val _ = TestFramework.assert ("301 has no sibling after resolution",
                    Option.isSome (OcoManager.findSibling mgrAfterFill 301) = false)
          val _ = TestFramework.assert ("302 has no sibling after resolution",
                    Option.isSome (OcoManager.findSibling mgrAfterFill 302) = false)

          (* 4. Register Pair 2: Order 401 & 402, test cancellation trigger *)
          val mgr2 = OcoManager.registerPair mgrAfterFill 2 401 402 "NVDA" 2000
          val _ = TestFramework.assertEqualInt ("Active pairs count is 1 again", 1, OcoManager.activePairsCount mgr2)

          val (mgrAfterCancel, cancelTarget2) = OcoManager.onOrderCancelled mgr2 402
          val _ = TestFramework.assertEqualLargeInt ("Cancelling 402 triggers cancellation of 401", 401, valOf cancelTarget2)
          val _ = TestFramework.assertEqualInt ("Active pairs drops to 0 after cancel", 0, OcoManager.activePairsCount mgrAfterCancel)
        in
          ()
        end
      )
end;

val _ = TestOco.run ();
