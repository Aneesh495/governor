(* latency_histogram.sig
 * High-Dynamic-Range latency histogram for nanosecond-precision benchmarking.
 *)

signature LATENCY_HISTOGRAM =
sig
  type histogram

  val create : unit -> histogram
  val record : histogram -> LargeInt.int -> unit  (* Record value in nanoseconds *)

  val count : histogram -> int
  val min : histogram -> LargeInt.int option
  val max : histogram -> LargeInt.int option
  val mean : histogram -> real option

  val percentile : histogram -> real -> LargeInt.int option (* e.g. 50.0, 99.0, 99.9 *)
  val printSummary : histogram -> string
  val reset : histogram -> unit
end
