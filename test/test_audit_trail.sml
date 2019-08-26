(* test_audit_trail.sml
 * Unit tests for Consolidated Audit Trail (CAT) regulatory logging and event journal querying.
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
val _ = use "src/marketdata/audit_trail.sig";
val _ = use "src/marketdata/audit_trail.sml";

structure TestAuditTrail =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("Consolidated Audit Trail (CAT) Logging Tests", fn () =>
        let
          val trail = AuditTrail.create ()
          val _ = TestFramework.assertEqualInt ("Initial records count is 0", 0, AuditTrail.totalRecords trail)
          val _ = TestFramework.assert ("Lookup seq 1 on empty trail is NONE",
                    Option.isSome (AuditTrail.lookupBySequence trail 1) = false)

          (* 1. Record Order Accepted for Order 1001 *)
          val ev1 = AuditTrail.CatOrderAccepted {
            order_id = 1001,
            client_id = "FIRM_A",
            symbol = "GOOGL",
            side = Types.Buy,
            price = toPrice 175,
            qty = 200
          }
          val (trail, rec1) = AuditTrail.record trail ev1 1000
          val _ = TestFramework.assertEqualLargeInt ("First record sequence is 1", 1, #sequence_number rec1)
          val _ = TestFramework.assertEqualLargeInt ("Timestamp matches 1000", 1000, #timestamp rec1)

          (* 2. Record Order Modified (qty decreased to 150) *)
          val ev2 = AuditTrail.CatOrderModified {
            order_id = 1001,
            old_qty = 200,
            new_qty = 150,
            old_price = toPrice 175,
            new_price = toPrice 175
          }
          val (trail, rec2) = AuditTrail.record trail ev2 2000
          val _ = TestFramework.assertEqualLargeInt ("Second record sequence is 2", 2, #sequence_number rec2)

          (* 3. Record Trade Execution *)
          val ev3 = AuditTrail.CatTradeExecuted {
            match_id = 5001,
            maker_order_id = 1001,
            taker_order_id = 2002,
            symbol = "GOOGL",
            price = toPrice 175,
            qty = 150
          }
          val (trail, rec3) = AuditTrail.record trail ev3 3000
          val _ = TestFramework.assertEqualLargeInt ("Third record sequence is 3", 3, #sequence_number rec3)

          (* 4. Record Cancellation of an unrelated Order 3003 *)
          val ev4 = AuditTrail.CatOrderCancelled {
            order_id = 3003,
            cancelled_qty = 50,
            reason = "Trader request"
          }
          val (trail, rec4) = AuditTrail.record trail ev4 4000
          val _ = TestFramework.assertEqualLargeInt ("Fourth record sequence is 4", 4, #sequence_number rec4)
          val _ = TestFramework.assertEqualInt ("Total records logged is 4", 4, AuditTrail.totalRecords trail)

          (* 5. Test range query (seq 2 to 3) *)
          val range2to3 = AuditTrail.getRange trail 2 3
          val _ = TestFramework.assertEqualInt ("Range [2, 3] returns 2 records", 2, List.length range2to3)

          (* 6. Test order lifecycle reconstruction (filterByOrder 1001) *)
          val orderHistory1001 = AuditTrail.filterByOrder trail 1001
          val _ = TestFramework.assertEqualInt ("Order 1001 has 3 audit records", 3, List.length orderHistory1001)

          val orderHistory3003 = AuditTrail.filterByOrder trail 3003
          val _ = TestFramework.assertEqualInt ("Order 3003 has 1 audit record", 1, List.length orderHistory3003)

          (* 7. Format formatting test *)
          val fmtStr = AuditTrail.formatRecord rec1
          val _ = TestFramework.assert ("Formatted string contains sequence", String.isSubstring "[CAT #1" fmtStr)
          val _ = TestFramework.assert ("Formatted string contains symbol", String.isSubstring "sym=GOOGL" fmtStr)
        in
          ()
        end
      )
end;

val _ = TestAuditTrail.run ();
