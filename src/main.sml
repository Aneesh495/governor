(* main.sml
 * Main entrypoint for Governor: Deterministic Matching Engine.
 *)

structure Main =
struct
  fun runBenchmark (orderCount : int) : unit =
      let
        val () = print (Ansi.colorize Ansi.bold ("\n=== GOVERNOR MATCHING ENGINE BENCHMARK ===\n"))
        val () = print ("Generating and processing " ^ Int.toString orderCount ^ " synthetic orders...\n")

        val b = OrderBook.create "BENCH"
        val matchIdCounter = ref (1 : LargeInt.int)
        fun nextMatchId () : LargeInt.int =
            let val id = !matchIdCounter in matchIdCounter := id + 1; id end

        val basePrice = valOf (Types.priceFromString "100.00")
        val tick = Types.priceScale div 100 (* 0.01 *)

        val startTs = TimeUtil.nowNanoseconds ()

        fun benchLoop (0, curB, totalTrades, totalVol) = (curB, totalTrades, totalVol)
          | benchLoop (i, curB, totalTrades, totalVol) =
              let
                val isBuy = (i mod 2 = 0)
                val priceOffset = LargeInt.fromInt ((i mod 10) - 5) * tick
                val ordP = basePrice + priceOffset
                val ordSide = if isBuy then Types.Buy else Types.Sell
                val ord = Order.create {
                  id = LargeInt.fromInt i,
                  client_id = if isBuy then "BUYER" else "SELLER",
                  symbol = "BENCH",
                  side = ordSide,
                  order_type = Types.Limit { price = ordP },
                  time_in_force = Types.GTC,
                  price = ordP,
                  qty = 10,
                  timestamp = startTs
                }

                val res = Matcher.processOrder {
                  book = curB,
                  order = ord,
                  policy = MatchingPolicy.Fifo,
                  nextMatchId = nextMatchId,
                  timestamp = startTs
                }

                val numTrades = List.length (#trades res)
                val batchVol = List.foldl (fn (t, acc) => #qty t + acc) 0 (#trades res)
              in
                benchLoop (i - 1, #book res, totalTrades + numTrades, totalVol + batchVol)
              end

        val (finalBook, tradesCount, volCount) = benchLoop (orderCount, b, 0, 0)
        val finishTs = TimeUtil.nowNanoseconds ()
        val elapsedNs = finishTs - startTs
        val elapsedSec = Real.fromLargeInt (LargeInt.toLarge elapsedNs) / 1000000000.0
        val throughput = if elapsedSec > 0.0 then Real.fromInt orderCount / elapsedSec else 0.0
        val latencyUs = if orderCount > 0 then (Real.fromLargeInt (LargeInt.toLarge elapsedNs) / 1000.0) / Real.fromInt orderCount else 0.0
      in
        print "\n=======================================================\n";
        print ("Benchmark Results: " ^ Int.toString orderCount ^ " orders executed\n");
        print ("  Elapsed Time:       " ^ TimeUtil.formatDuration elapsedNs ^ "\n");
        print ("  Throughput:         " ^ Real.fmt (StringCvt.FIX (SOME 2)) throughput ^ " orders/sec\n");
        print ("  Average Latency:    " ^ Real.fmt (StringCvt.FIX (SOME 3)) latencyUs ^ " microseconds/order\n");
        print ("  Trades Generated:   " ^ Int.toString tradesCount ^ "\n");
        print ("  Volume Executed:    " ^ LargeInt.toString volCount ^ " shares\n");
        print ("  Resting Orders:     " ^ Int.toString (OrderBook.totalOrders finalBook) ^ "\n");
        print "=======================================================\n"
      end

  fun runSimulation (ticks : int) (symbols : Types.symbol_id list) (logFileOpt : string option) : unit =
      let
        val () = print (Ansi.colorize Ansi.bold ("\n=== GOVERNOR MULTI-SYMBOL HEADLESS SIMULATION ===\n"))
        val () = print ("Simulating " ^ Int.toString ticks ^ " ticks across " ^ Int.toString (List.length symbols) ^ " symbols...\n")

        val sim = ExchangeSim.create ()
        val simWithSymbols = List.foldl (fn (sym, curSim) => ExchangeSim.addSymbol curSim sym) sim symbols

        (* Register synthetic participants *)
        val halfSpread = valOf (Types.priceFromString "0.05")
        val mm = SyntheticTrader.createMarketMaker "MM_FLOW" halfSpread 50 0.01
        val noise = SyntheticTrader.createNoiseTrader "RETAIL" 1.0 20
        val momentum = SyntheticTrader.createMomentumTrader "MOMENTUM" 0.005 30

        val simWithTraders = ExchangeSim.registerTrader (ExchangeSim.registerTrader (ExchangeSim.registerTrader simWithSymbols mm) noise) momentum

        val startTs = TimeUtil.nowNanoseconds ()
        fun simLoop (0, s) = s
          | simLoop (k, s) =
              let val now = startTs + LargeInt.fromInt (ticks - k) * 100000000 in
                simLoop (k - 1, ExchangeSim.step s now)
              end

        val finalSim = simLoop (ticks, simWithTraders)
        val finishTs = TimeUtil.nowNanoseconds ()

        val () = print "\n=======================================================\n";
        val () = print "Simulation Execution Summary:\n";
        val () = print ("  Total Simulated Ticks: " ^ Int.toString ticks ^ "\n");
        val () = print ("  Total Trades Executed: " ^ Int.toString (ExchangeSim.totalTrades finalSim) ^ "\n");
        val () = print ("  Total Volume Executed: " ^ LargeInt.toString (ExchangeSim.totalVolume finalSim) ^ " shares\n");
        val () = print ("  Total Journal Events:  " ^ Int.toString (EventJournal.size (ExchangeSim.getJournal finalSim)) ^ "\n");
        val () = print "=======================================================\n\n";

        val () = List.app (fn sym =>
          case ExchangeSim.getBook finalSim sym of
              SOME b => print (DepthLadder.renderLadder b 5 ^ "\n")
            | NONE => ()) symbols
      in
        case logFileOpt of
            SOME logPath =>
              (print ("Writing event journal to " ^ logPath ^ "...\n");
               EventJournal.writeToFile (ExchangeSim.getJournal finalSim) logPath;
               print "Log written successfully.\n")
          | NONE => ()
      end

  fun main () : OS.Process.status =
      let
        val args = CommandLine.arguments ()
        val opts = CliArgs.parseArgs args
      in
        case #mode opts of
            CliArgs.ModeHelp =>
              (print (CliArgs.usageString "governor"); OS.Process.success)
          | CliArgs.ModeTest =>
              (print "Executing Governor full regression test suite...\n";
               OS.Process.system "poly --script test/run_tests.sml")
          | CliArgs.ModeBenchmark { order_count } =>
              (runBenchmark order_count; OS.Process.success)
          | CliArgs.ModeSim { ticks } =>
              (runSimulation ticks (#symbols opts) (#log_file opts); OS.Process.success)
          | CliArgs.ModeConsole =>
              let
                val sim = ExchangeSim.create ()
                val simWithSymbols = List.foldl (fn (sym, curSim) => ExchangeSim.addSymbol curSim sym) sim (#symbols opts)
                val halfSpread = valOf (Types.priceFromString "0.05")
                val mm = SyntheticTrader.createMarketMaker "MM_CORE" halfSpread 100 0.0
                val simReady = ExchangeSim.registerTrader simWithSymbols mm
                val console = OperatorConsole.create simReady
              in
                OperatorConsole.runInteractiveLoop console;
                OS.Process.success
              end
      end
      handle ex =>
        (print (Ansi.colorize Ansi.brightRed ("Fatal error: " ^ exnMessage ex ^ "\n"));
         OS.Process.failure)
end
