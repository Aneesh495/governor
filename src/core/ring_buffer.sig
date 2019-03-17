(* ring_buffer.sig
 * Fixed-capacity circular ring buffer for bounded audit journals and telemetry.
 *)

signature RING_BUFFER =
sig
  type 'a buffer

  val create : int -> 'a buffer
  val capacity : 'a buffer -> int
  val size : 'a buffer -> int
  val isFull : 'a buffer -> bool
  val isEmpty : 'a buffer -> bool

  val push : 'a buffer -> 'a -> unit
  val toList : 'a buffer -> 'a list
  val clear : 'a buffer -> unit
  val latest : 'a buffer -> 'a option
end
