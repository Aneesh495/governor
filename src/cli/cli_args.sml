(* cli_args.sml
 * Implementation of command line argument parser.
 *)

structure CliArgs :> CLI_ARGS =
struct
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

  val defaultOptions : options = {
    mode = ModeConsole,
    symbols = ["AAPL", "MSFT", "GOOGL", "NVDA"],
    log_file = NONE
  }

  fun usageString progName =
      "Usage: " ^ progName ^ " [OPTIONS]\n\n" ^
      "Options:\n" ^
      "  --console               Start interactive operator console (default)\n" ^
      "  --sim <TICKS>           Run headless simulation for N ticks\n" ^
      "  --benchmark <COUNT>     Run matching engine benchmark with N orders\n" ^
      "  --test                  Run comprehensive test suite\n" ^
      "  --symbol <SYM>          Add symbol to trading universe (can be repeated)\n" ^
      "  --log <FILE>            Output event journal to file\n" ^
      "  --help, -h              Display this help message\n"

  fun parseArgs (args : string list) : options =
      let
        fun loop ([], opts) = opts
          | loop ("--console" :: rest, opts) =
              loop (rest, { mode = ModeConsole, symbols = #symbols opts, log_file = #log_file opts })
          | loop ("--sim" :: ticksStr :: rest, opts) =
              let val ticks = case Int.fromString ticksStr of SOME t => t | NONE => 100 in
                loop (rest, { mode = ModeSim { ticks = ticks }, symbols = #symbols opts, log_file = #log_file opts })
              end
          | loop ("--benchmark" :: countStr :: rest, opts) =
              let val count = case Int.fromString countStr of SOME c => c | NONE => 50000 in
                loop (rest, { mode = ModeBenchmark { order_count = count }, symbols = #symbols opts, log_file = #log_file opts })
              end
          | loop ("--test" :: rest, opts) =
              loop (rest, { mode = ModeTest, symbols = #symbols opts, log_file = #log_file opts })
          | loop ("--help" :: _, opts) =
              { mode = ModeHelp, symbols = #symbols opts, log_file = #log_file opts }
          | loop ("-h" :: _, opts) =
              { mode = ModeHelp, symbols = #symbols opts, log_file = #log_file opts }
          | loop ("--symbol" :: sym :: rest, opts) =
              let val newSyms = String.map Char.toUpper sym :: #symbols opts in
                loop (rest, { mode = #mode opts, symbols = newSyms, log_file = #log_file opts })
              end
          | loop ("--log" :: file :: rest, opts) =
              loop (rest, { mode = #mode opts, symbols = #symbols opts, log_file = SOME file })
          | loop (_ :: rest, opts) =
              loop (rest, opts)
      in
        loop (args, defaultOptions)
      end
end
