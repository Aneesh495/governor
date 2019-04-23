(* operator_console.sml
 * Implementation of Operator Console command dispatcher and REPL.
 *)

structure OperatorConsole :> OPERATOR_CONSOLE =
struct
  type console = {
    sim : ExchangeSim.sim,
    active_symbol : Types.symbol_id ref,
    recent_trades : Trade.trade list ref,
    order_id_counter : Types.order_id ref
  }

  fun create (initialSim : ExchangeSim.sim) : console =
      {
        sim = initialSim,
        active_symbol = ref "AAPL",
        recent_trades = ref [],
        order_id_counter = ref 1000
      }

  fun nextOrderId (c : console) () : Types.order_id =
      let val id = !(#order_id_counter c) in #order_id_counter c := id + 1; id end

  fun helpMessage () : string =
      Ansi.colorize Ansi.bold "=== GOVERNOR MATCHING ENGINE OPERATOR COMMANDS ===\n" ^
      "  HELP                                    : Show this command menu\n" ^
      "  BOOK [SYMBOL]                           : Display depth ladder for symbol\n" ^
      "  SUBMIT <SYM> <BUY|SELL> <QTY> <PX> [CL] : Submit manual limit order\n" ^
      "  CANCEL <SYM> <ORDER_ID>                 : Cancel resting order\n" ^
      "  TRADES [N]                              : Show recent executed trades blotter\n" ^
      "  STATS                                   : Display engine throughput & volume stats\n" ^
      "  STEP [N]                                : Advance simulation clock by N ticks\n" ^
      "  QUIT                                    : Exit operator console\n"

  fun processCommand (c : console) (line : string) : (console * string, string) Result.result =
      let
        val trimmed = String.concatWith " " (String.tokens Char.isSpace line)
        val tokens = String.tokens Char.isSpace trimmed
      in
        case tokens of
            [] => Result.ok (c, "")
          | ["HELP"] => Result.ok (c, helpMessage ())
          | ["help"] => Result.ok (c, helpMessage ())
          | ["BOOK"] =>
              let
                val sym = !(#active_symbol c)
              in
                case ExchangeSim.getBook (#sim c) sym of
                    SOME b => Result.ok (c, DepthLadder.renderLadder b 10)
                  | NONE => Result.err ("Symbol " ^ sym ^ " not registered")
              end
          | ["BOOK", sym] =>
              let
                val upperSym = String.map Char.toUpper sym
                val () = #active_symbol c := upperSym
              in
                case ExchangeSim.getBook (#sim c) upperSym of
                    SOME b => Result.ok (c, DepthLadder.renderLadder b 10)
                  | NONE => Result.err ("Symbol " ^ upperSym ^ " not registered")
              end
          | ["TRADES"] =>
              Result.ok (c, TradeBlotter.renderBlotter (!(#recent_trades c)) 15)
          | ["TRADES", nStr] =>
              let val n = case Int.fromString nStr of SOME v => v | NONE => 15 in
                Result.ok (c, TradeBlotter.renderBlotter (!(#recent_trades c)) n)
              end
          | ["STATS"] =>
              let
                val tradesCount = ExchangeSim.totalTrades (#sim c)
                val totalVol = ExchangeSim.totalVolume (#sim c)
                val journalSize = EventJournal.size (ExchangeSim.getJournal (#sim c))
                val statsStr =
                    Ansi.colorize Ansi.bold "=== GOVERNOR MATCHING ENGINE METRICS ===\n" ^
                    "  Total Trades Executed: " ^ Int.toString tradesCount ^ "\n" ^
                    "  Total Volume Executed: " ^ LargeInt.toString totalVol ^ " shares\n" ^
                    "  Event Journal Size:    " ^ Int.toString journalSize ^ " events\n"
              in
                Result.ok (c, statsStr)
              end
          | ("SUBMIT" :: sym :: sideStr :: qtyStr :: priceStr :: rest) =>
              (case (Types.sideFromString sideStr, LargeInt.fromString qtyStr, Types.priceFromString priceStr) of
                   (SOME side, SOME qty, SOME p) =>
                     let
                       val upperSym = String.map Char.toUpper sym
                       val clientId = case rest of (cl :: _) => cl | [] => "OPERATOR"
                       val ordId = nextOrderId c ()
                       val ord = Order.create {
                         id = ordId,
                         client_id = clientId,
                         symbol = upperSym,
                         side = side,
                         order_type = Types.Limit { price = p },
                         time_in_force = Types.GTC,
                         price = p,
                         qty = qty,
                         timestamp = TimeUtil.nowNanoseconds ()
                       }
                     in
                       case ExchangeSim.submitOrder (#sim c) ord of
                           Result.Ok (updatedSim, trades) =>
                             let
                               val () = #recent_trades c := trades @ (!(#recent_trades c))
                               val updatedConsole : console = {
                                 sim = updatedSim,
                                 active_symbol = #active_symbol c,
                                 recent_trades = #recent_trades c,
                                 order_id_counter = #order_id_counter c
                               }
                               val tradeMsg = if List.null trades then " (resting in book)"
                                              else " (" ^ Int.toString (List.length trades) ^ " fills executed)"
                             in
                               Result.ok (updatedConsole, Ansi.colorize Ansi.brightGreen ("Order " ^ LargeInt.toString ordId ^ " SUBMITTED" ^ tradeMsg ^ "\n"))
                             end
                         | Result.Err e => Result.err ("Order rejected by Risk Gateway: " ^ e)
                     end
                 | _ => Result.err "Invalid SUBMIT arguments: usage SUBMIT <SYM> <BUY|SELL> <QTY> <PRICE> [CLIENT]")
          | ["STEP"] =>
              let
                val updatedSim = ExchangeSim.step (#sim c) (TimeUtil.nowNanoseconds ())
                val updatedConsole = {
                  sim = updatedSim,
                  active_symbol = #active_symbol c,
                  recent_trades = #recent_trades c,
                  order_id_counter = #order_id_counter c
                }
              in
                Result.ok (updatedConsole, "Simulated 1 tick step.\n")
              end
          | ["STEP", countStr] =>
              let
                val count = case Int.fromString countStr of SOME v => v | NONE => 1
                fun loop (0, s) = s
                  | loop (k, s) = loop (k - 1, ExchangeSim.step s (TimeUtil.nowNanoseconds ()))
                val updatedSim = loop (count, #sim c)
                val updatedConsole = {
                  sim = updatedSim,
                  active_symbol = #active_symbol c,
                  recent_trades = #recent_trades c,
                  order_id_counter = #order_id_counter c
                }
              in
                Result.ok (updatedConsole, "Simulated " ^ Int.toString count ^ " ticks.\n")
              end
          | ["QUIT"] => Result.ok (c, "QUIT")
          | ["quit"] => Result.ok (c, "QUIT")
          | (unknown :: _) =>
              Result.err ("Unknown command: \"" ^ unknown ^ "\". Type HELP for menu.")
      end

  fun runInteractiveLoop (initialConsole : console) : unit =
      let
        fun loop (c : console) =
            let
              val () = print (Ansi.colorize Ansi.bold "governor> ")
            in
              case TextIO.inputLine TextIO.stdIn of
                  NONE => ()
                | SOME rawLine =>
                    let
                      val trimmed = String.substring (rawLine, 0, String.size rawLine - 1) handle _ => rawLine
                    in
                      case processCommand c trimmed of
                          Result.Ok (nextC, "QUIT") => print "Shutting down Governor.\n"
                        | Result.Ok (nextC, output) =>
                            (if String.size output > 0 then print output else ();
                             loop nextC)
                        | Result.Err errMsg =>
                            (print (Ansi.colorize Ansi.brightRed ("[ERROR] " ^ errMsg ^ "\n"));
                             loop c)
                    end
            end
      in
        print (Ansi.colorize Ansi.brightCyan "Governor Electronic Trading Platform v1.0\n");
        print "Type HELP for commands, QUIT to exit.\n\n";
        loop initialConsole
      end
end
