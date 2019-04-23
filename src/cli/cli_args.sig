(* cli_args.sig
 * Command line argument parser for Governor entrypoint.
 *)

signature CLI_ARGS =
sig
  datatype run_mode =
      ModeConsole
    | ModeSim of { ticks : int }
    | ModeBenchmark of { order_count : int }
    | ModeTest
    | ModeHelp

  type options = {
    mode : run_mode,
    symbols : Types.symbol_id list,
    log_file : string option
  }

  val defaultOptions : options
  val parseArgs : string list -> options
  val usageString : string -> string
end
