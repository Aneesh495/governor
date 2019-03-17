(* time_util.sig
 * High-precision timestamp generation, elapsed time measurement, and formatting.
 *)

signature TIME_UTIL =
sig
  type timestamp_ns = Types.timestamp_ns

  val nowNanoseconds : unit -> timestamp_ns
  val elapsedNanoseconds : timestamp_ns -> timestamp_ns -> timestamp_ns
  val formatIso8601 : timestamp_ns -> string
  val formatDuration : timestamp_ns -> string

  val fromSeconds : LargeInt.int -> timestamp_ns
  val fromMilliseconds : LargeInt.int -> timestamp_ns
  val fromMicroseconds : LargeInt.int -> timestamp_ns

  val toSeconds : timestamp_ns -> LargeInt.int
  val toMilliseconds : timestamp_ns -> LargeInt.int
  val toMicroseconds : timestamp_ns -> LargeInt.int
end
