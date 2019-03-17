(* test_framework.sml
 * Minimalist assertion and test reporting framework implementation.
 *)

structure TestFramework :> TEST_FRAMEWORK =
struct
  val testCount = ref 0
  val passCount = ref 0
  val failCount = ref 0

  fun recordPass name =
      (testCount := !testCount + 1;
       passCount := !passCount + 1;
       print ("  [PASS] " ^ name ^ "\n"))

  fun recordFail (name, details) =
      (testCount := !testCount + 1;
       failCount := !failCount + 1;
       print ("  [FAIL] " ^ name ^ ": " ^ details ^ "\n"))

  fun assert (name, cond) =
      if cond then recordPass name
      else recordFail (name, "assertion returned false")

  fun assertEqualInt (name, expected, actual) =
      if expected = actual then recordPass name
      else recordFail (name, "expected " ^ Int.toString expected ^ " but got " ^ Int.toString actual)

  fun assertEqualLargeInt (name, expected, actual) =
      if expected = actual then recordPass name
      else recordFail (name, "expected " ^ LargeInt.toString expected ^ " but got " ^ LargeInt.toString actual)

  fun assertEqualString (name, expected, actual) =
      if expected = actual then recordPass name
      else recordFail (name, "expected \"" ^ expected ^ "\" but got \"" ^ actual ^ "\"")

  fun assertEqualBool (name, expected, actual) =
      if expected = actual then recordPass name
      else recordFail (name, "expected " ^ Bool.toString expected ^ " but got " ^ Bool.toString actual)

  fun runSuite (name, suiteFn) =
      (print ("\n=== Test Suite: " ^ name ^ " ===\n");
       (suiteFn () handle ex =>
          recordFail (name, "unhandled exception: " ^ exnMessage ex)))

  fun reportSummary () =
      let
        val total = !testCount
        val passed = !passCount
        val failed = !failCount
      in
        print "\n========================================\n";
        print ("Test Execution Summary: " ^ Int.toString total ^ " tests executed\n");
        print ("  Passed: " ^ Int.toString passed ^ "\n");
        print ("  Failed: " ^ Int.toString failed ^ "\n");
        print "========================================\n";
        if failed > 0 then
          (print "TEST RUN FAILED!\n"; OS.Process.exit OS.Process.failure)
        else
          (print "ALL TESTS PASSED WITH ZERO DEFECTS!\n")
      end
end
