(* latency_histogram.sml
 * Implementation of latency histogram using array of logarithmically spaced buckets.
 *)

structure LatencyHistogram :> LATENCY_HISTOGRAM =
struct
  (* 60 buckets covering 1 ns to 1 second *)
  val numBuckets = 60

  type histogram = {
    buckets : int Array.array,
    total_count : int ref,
    total_sum : LargeInt.int ref,
    min_val : LargeInt.int ref,
    max_val : LargeInt.int ref
  }

  fun create () : histogram =
      {
        buckets = Array.array (numBuckets, 0),
        total_count = ref 0,
        total_sum = ref 0,
        min_val = ref 0x7FFFFFFFFFFFFFFF,
        max_val = ref 0
      }

  fun bucketFor (ns : LargeInt.int) : int =
      if ns <= 0 then 0
      else
        let
          fun loop (v, idx) =
              if v <= 1 orelse idx >= numBuckets - 1 then idx
              else loop (v div 2, idx + 1)
        in
          loop (ns, 0)
        end

  fun valueForBucket (idx : int) : LargeInt.int =
      let
        fun loop (0, acc) = acc
          | loop (k, acc) = loop (k - 1, acc * 2)
      in
        loop (idx, 1)
      end

  fun record (h : histogram) (ns : LargeInt.int) : unit =
      let
        val idx = bucketFor ns
        val curCount = Array.sub (#buckets h, idx)
      in
        Array.update (#buckets h, idx, curCount + 1);
        #total_count h := !(#total_count h) + 1;
        #total_sum h := !(#total_sum h) + ns;
        if ns < !(#min_val h) then #min_val h := ns else ();
        if ns > !(#max_val h) then #max_val h := ns else ()
      end

  fun count (h : histogram) = !(#total_count h)

  fun min (h : histogram) =
      if !(#total_count h) = 0 then NONE
      else SOME (! (#min_val h))

  fun max (h : histogram) =
      if !(#total_count h) = 0 then NONE
      else SOME (! (#max_val h))

  fun mean (h : histogram) =
      if !(#total_count h) = 0 then NONE
      else
        SOME (Real.fromLargeInt (LargeInt.toLarge (! (#total_sum h))) / Real.fromInt (! (#total_count h)))

  fun percentile (h : histogram) (pct : real) : LargeInt.int option =
      if !(#total_count h) = 0 then NONE
      else
        let
          val targetCount = Real.ceil (Real.fromInt (! (#total_count h)) * (pct / 100.0))
          fun search (idx, cum) =
              if idx >= numBuckets then SOME (valueForBucket (numBuckets - 1))
              else
                let
                  val newCum = cum + Array.sub (#buckets h, idx)
                in
                  if newCum >= targetCount then
                    SOME (valueForBucket idx)
                  else
                    search (idx + 1, newCum)
                end
        in
          search (0, 0)
        end

  fun printSummary (h : histogram) : string =
      if !(#total_count h) = 0 then "LatencyHistogram: no samples recorded\n"
      else
        let
          val p50 = case percentile h 50.0 of SOME v => TimeUtil.formatDuration v | NONE => "N/A"
          val p90 = case percentile h 90.0 of SOME v => TimeUtil.formatDuration v | NONE => "N/A"
          val p99 = case percentile h 99.0 of SOME v => TimeUtil.formatDuration v | NONE => "N/A"
          val p999 = case percentile h 99.9 of SOME v => TimeUtil.formatDuration v | NONE => "N/A"
          val minStr = case min h of SOME v => TimeUtil.formatDuration v | NONE => "N/A"
          val maxStr = case max h of SOME v => TimeUtil.formatDuration v | NONE => "N/A"
        in
          "=== Latency Distribution (" ^ Int.toString (!(#total_count h)) ^ " samples) ===\n" ^
          "  Min:   " ^ minStr ^ "\n" ^
          "  p50:   " ^ p50 ^ "\n" ^
          "  p90:   " ^ p90 ^ "\n" ^
          "  p99:   " ^ p99 ^ "\n" ^
          "  p99.9: " ^ p999 ^ "\n" ^
          "  Max:   " ^ maxStr ^ "\n"
        end

  fun reset (h : histogram) : unit =
      (Array.modify (fn _ => 0) (#buckets h);
       #total_count h := 0;
       #total_sum h := 0;
       #min_val h := 0x7FFFFFFFFFFFFFFF;
       #max_val h := 0)
end
