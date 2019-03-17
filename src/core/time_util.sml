(* time_util.sml
 * High-precision timestamp generation, elapsed time measurement, and formatting.
 *)

structure TimeUtil :> TIME_UTIL =
struct
  type timestamp_ns = Types.timestamp_ns

  fun nowNanoseconds () : timestamp_ns =
      Time.toNanoseconds (Time.now ())

  fun elapsedNanoseconds (start : timestamp_ns) (finish : timestamp_ns) : timestamp_ns =
      finish - start

  fun fromSeconds s = s * 1000000000
  fun fromMilliseconds ms = ms * 1000000
  fun fromMicroseconds us = us * 1000

  fun toSeconds ns = ns div 1000000000
  fun toMilliseconds ns = ns div 1000000
  fun toMicroseconds ns = ns div 1000

  fun formatDuration (ns : timestamp_ns) : string =
      if ns < 1000 then
        LargeInt.toString ns ^ " ns"
      else if ns < 1000000 then
        let
          val us = ns div 1000
          val rem = (ns mod 1000) div 100
        in
          LargeInt.toString us ^ "." ^ LargeInt.toString rem ^ " us"
        end
      else if ns < 1000000000 then
        let
          val ms = ns div 1000000
          val rem = (ns mod 1000000) div 100000
        in
          LargeInt.toString ms ^ "." ^ LargeInt.toString rem ^ " ms"
        end
      else
        let
          val sec = ns div 1000000000
          val rem = (ns mod 1000000000) div 100000000
        in
          LargeInt.toString sec ^ "." ^ LargeInt.toString rem ^ " s"
        end

  fun formatIso8601 (ns : timestamp_ns) : string =
      let
        val sec = ns div 1000000000
        val fracNs = ns mod 1000000000
        val fracStr = StringCvt.padLeft #"0" 9 (LargeInt.toString fracNs)
        val d = Date.fromTimeLocal (Time.fromSeconds (LargeInt.toLarge sec))
        val yr = Int.toString (Date.year d)
        val mo = StringCvt.padLeft #"0" 2 (Int.toString (case Date.month d of
                     Date.Jan => 1 | Date.Feb => 2 | Date.Mar => 3 | Date.Apr => 4
                   | Date.May => 5 | Date.Jun => 6 | Date.Jul => 7 | Date.Aug => 8
                   | Date.Sep => 9 | Date.Oct => 10 | Date.Nov => 11 | Date.Dec => 12))
        val day = StringCvt.padLeft #"0" 2 (Int.toString (Date.day d))
        val hr = StringCvt.padLeft #"0" 2 (Int.toString (Date.hour d))
        val mi = StringCvt.padLeft #"0" 2 (Int.toString (Date.minute d))
        val sc = StringCvt.padLeft #"0" 2 (Int.toString (Date.second d))
      in
        yr ^ "-" ^ mo ^ "-" ^ day ^ "T" ^ hr ^ ":" ^ mi ^ ":" ^ sc ^ "." ^ fracStr ^ "Z"
      end
end
