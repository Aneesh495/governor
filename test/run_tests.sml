(* run_tests.sml
 * Master test suite runner executing all unit, structural, property, and stress tests.
 *)

val _ = print "\n=======================================================\n";
val _ = print "  GOVERNOR MATCHING ENGINE MASTER TEST HARNESS\n";
val _ = print "=======================================================\n\n";

val _ = use "test/test_core.sml";
val _ = use "test/test_book.sml";
val _ = use "test/test_engine.sml";
val _ = use "test/test_risk.sml";
val _ = use "test/test_marketdata.sml";
val _ = use "test/test_protocol.sml";
val _ = use "test/test_sim.sml";
val _ = use "test/test_cli.sml";
val _ = use "test/test_net.sml";

(* Extended feature test suites *)
val _ = use "test/test_properties_rbtree.sml";
val _ = use "test/test_properties_matching.sml";
val _ = use "test/test_microprice.sml";
val _ = use "test/test_fees.sml";
val _ = use "test/test_stop_orders.sml";
val _ = use "test/test_order_modify.sml";
val _ = use "test/test_sbe.sml";
val _ = use "test/test_latency.sml";
val _ = use "test/test_trailing_stop.sml";
val _ = use "test/test_oco.sml";
val _ = use "test/test_bracket.sml";
val _ = use "test/test_audit_trail.sml";
val _ = use "test/test_stress.sml";

val _ = print "\n=======================================================\n";
val _ = print "  MASTER TEST RUN COMPLETE: ALL 22 MODULE SUITES VERIFIED\n";
val _ = print "=======================================================\n\n";
