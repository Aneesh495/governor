(* test_latency.sml
 * Unit tests for LatencyHistogram nanosecond-precision profiling and percentile calculation.
 *)

val _ = use "test/test_framework.sig";
val _ = use "test/test_framework.sml";
val _ = use "src/core/result.sig";
val _ = use "src/core/result.sml";
val _ = use "src/core/types.sig";
val _ = use "src/core/types.sml";
val _ = use "src/core/time_util.sig";
val _ = use "src/core/time_util.sml";
val _ = use "src/core/latency_histogram.sig";
val _ = use "src/core/latency_histogram.sml";

structure TestLatency =
struct
  fun run () =
      TestFramework.runSuite ("Latency Histogram & Percentiles Tests", fn () =>
        let
          val h = LatencyHistogram.create ()

          (* 1. Initial empty state *)
          val _ = TestFramework.assertEqualInt ("Initial sample count is 0", 0, LatencyHistogram.count h)
          val _ = TestFramework.assert ("Initial min is NONE", Option.isSome (LatencyHistogram.min h) = false)
          val _ = TestFramework.assert ("Initial max is NONE", Option.isSome (LatencyHistogram.max h) = false)
          val _ = TestFramework.assert ("Initial mean is NONE", Option.isSome (LatencyHistogram.mean h) = false)
          val _ = TestFramework.assert ("Initial p50 is NONE", Option.isSome (LatencyHistogram.percentile h 50.0) = false)

          (* 2. Record 100 samples of 250 ns, 100 samples of 1000 ns, and 1 outlier of 50000 ns *)
          val _ = List.app (fn _ => LatencyHistogram.record h 250) (List.tabulate (100, fn _ => ()))
          val _ = List.app (fn _ => LatencyHistogram.record h 1000) (List.tabulate (100, fn _ => ()))
          val _ = LatencyHistogram.record h 50000

          val _ = TestFramework.assertEqualInt ("Recorded 201 samples", 201, LatencyHistogram.count h)
          val _ = TestFramework.assertEqualLargeInt ("Min is 250 ns", 250, valOf (LatencyHistogram.min h))
          val _ = TestFramework.assertEqualLargeInt ("Max is 50000 ns", 50000, valOf (LatencyHistogram.max h))

          (* 3. Check percentiles *)
          val p50Opt = LatencyHistogram.percentile h 50.0
          val _ = TestFramework.assert ("p50 is computed", Option.isSome p50Opt)

          val p99Opt = LatencyHistogram.percentile h 99.0
          val _ = TestFramework.assert ("p99 is computed", Option.isSome p99Opt)

          (* 4. Summary string formatting *)
          val summary = LatencyHistogram.printSummary h
          val _ = TestFramework.assert ("Summary contains samples", String.isSubstring "201 samples" summary)
          val _ = TestFramework.assert ("Summary contains p99", String.isSubstring "p99" summary)

          (* 5. Reset *)
          val _ = LatencyHistogram.reset h
          val _ = TestFramework.assertEqualInt ("Count after reset is 0", 0, LatencyHistogram.count h)
          val _ = TestFramework.assert ("Min after reset is NONE", Option.isSome (LatencyHistogram.min h) = false)
        in
          ()
        end
      )
end;

val _ = TestLatency.run ();
