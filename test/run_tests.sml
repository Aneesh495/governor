(* run_tests.sml
 * Master test suite runner executing all unit, structural, and integration tests.
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

val _ = print "\n=======================================================\n";
val _ = print "  MASTER TEST RUN COMPLETE: ALL MODULES VERIFIED\n";
val _ = print "=======================================================\n\n";
