(* operator_console.sig
 * Interactive terminal operator console and command interpreter.
 *)

signature OPERATOR_CONSOLE =
sig
  type console

  val create : ExchangeSim.sim -> console
  val processCommand : console -> string -> (console * string, string) Result.result
  val runInteractiveLoop : console -> unit
end
