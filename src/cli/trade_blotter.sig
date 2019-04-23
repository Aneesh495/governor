(* trade_blotter.sig
 * ANSI formatted execution blotter rendering executed fills and trader activity.
 *)

signature TRADE_BLOTTER =
sig
  val renderBlotter : Trade.trade list -> int -> string
end
