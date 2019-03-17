(* test_framework.sig
 * Minimalist assertion and test reporting framework for Governor.
 *)

signature TEST_FRAMEWORK =
sig
  val testCount : int ref
  val passCount : int ref
  val failCount : int ref

  val assert : string * bool -> unit
  val assertEqualInt : string * int * int -> unit
  val assertEqualLargeInt : string * LargeInt.int * LargeInt.int -> unit
  val assertEqualString : string * string * string -> unit
  val assertEqualBool : string * bool * bool -> unit

  val runSuite : string * (unit -> unit) -> unit
  val reportSummary : unit -> unit
end
