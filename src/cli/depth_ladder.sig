(* depth_ladder.sig
 * ANSI vertical limit order book depth ladder with graphical volume bars.
 *)

signature DEPTH_LADDER =
sig
  val renderLadder : OrderBook.book -> int -> string
end
