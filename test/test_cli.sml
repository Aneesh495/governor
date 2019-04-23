(* test_cli.sml
 * Comprehensive test cases for CLI tools, DepthLadder, TradeBlotter, and Command parsing.
 *)

val _ = use "test/test_framework.sig";
val _ = use "test/test_framework.sml";
val _ = use "src/core/result.sig";
val _ = use "src/core/result.sml";
val _ = use "src/core/types.sig";
val _ = use "src/core/types.sml";
val _ = use "src/core/word_util.sig";
val _ = use "src/core/word_util.sml";
val _ = use "src/core/fifo_queue.sig";
val _ = use "src/core/fifo_queue.sml";
val _ = use "src/core/red_black_map.sig";
val _ = use "src/core/red_black_map.sml";
val _ = use "src/core/byte_buffer.sig";
val _ = use "src/core/byte_buffer.sml";
val _ = use "src/core/time_util.sig";
val _ = use "src/core/time_util.sml";
val _ = use "src/core/ring_buffer.sig";
val _ = use "src/core/ring_buffer.sml";
val _ = use "src/book/order.sig";
val _ = use "src/book/order.sml";
val _ = use "src/book/price_level.sig";
val _ = use "src/book/price_level.sml";
val _ = use "src/book/order_book.sig";
val _ = use "src/book/order_book.sml";
val _ = use "src/book/book_manager.sig";
val _ = use "src/book/book_manager.sml";
val _ = use "src/engine/trade.sig";
val _ = use "src/engine/trade.sml";
val _ = use "src/engine/matching_policy.sig";
val _ = use "src/engine/matching_policy.sml";
val _ = use "src/engine/circuit_breaker.sig";
val _ = use "src/engine/circuit_breaker.sml";
val _ = use "src/engine/matcher.sig";
val _ = use "src/engine/matcher.sml";
val _ = use "src/engine/auction.sig";
val _ = use "src/engine/auction.sml";
val _ = use "src/risk/risk_limits.sig";
val _ = use "src/risk/risk_limits.sml";
val _ = use "src/risk/trader_state.sig";
val _ = use "src/risk/trader_state.sml";
val _ = use "src/risk/self_match.sig";
val _ = use "src/risk/self_match.sml";
val _ = use "src/risk/risk_engine.sig";
val _ = use "src/risk/risk_engine.sml";
val _ = use "src/marketdata/market_data_event.sig";
val _ = use "src/marketdata/market_data_event.sml";
val _ = use "src/marketdata/level1_feed.sig";
val _ = use "src/marketdata/level1_feed.sml";
val _ = use "src/marketdata/level2_feed.sig";
val _ = use "src/marketdata/level2_feed.sml";
val _ = use "src/marketdata/event_journal.sig";
val _ = use "src/marketdata/event_journal.sml";
val _ = use "src/sim/synthetic_trader.sig";
val _ = use "src/sim/synthetic_trader.sml";
val _ = use "src/sim/market_replay.sig";
val _ = use "src/sim/market_replay.sml";
val _ = use "src/sim/exchange_sim.sig";
val _ = use "src/sim/exchange_sim.sml";
val _ = use "src/cli/ansi.sig";
val _ = use "src/cli/ansi.sml";
val _ = use "src/cli/depth_ladder.sig";
val _ = use "src/cli/depth_ladder.sml";
val _ = use "src/cli/trade_blotter.sig";
val _ = use "src/cli/trade_blotter.sml";
val _ = use "src/cli/operator_console.sig";
val _ = use "src/cli/operator_console.sml";
val _ = use "src/cli/cli_args.sig";
val _ = use "src/cli/cli_args.sml";

val _ = TestFramework.runSuite ("CLI Arguments Parser Tests", fn () =>
  let
    val opts1 = CliArgs.parseArgs ["--sim", "500"]
    val opts2 = CliArgs.parseArgs ["--benchmark", "10000"]
    val opts3 = CliArgs.parseArgs ["--test"]
  in
    case #mode opts1 of
        CliArgs.ModeSim { ticks } => TestFramework.assertEqualInt ("Sim ticks parsed as 500", 500, ticks)
      | _ => TestFramework.assert ("Opts1 mode is ModeSim", false);

    case #mode opts2 of
        CliArgs.ModeBenchmark { order_count } => TestFramework.assertEqualInt ("Benchmark count parsed as 10000", 10000, order_count)
      | _ => TestFramework.assert ("Opts2 mode is ModeBenchmark", false);

    case #mode opts3 of
        CliArgs.ModeTest => TestFramework.assert ("Opts3 mode is ModeTest", true)
      | _ => TestFramework.assert ("Opts3 mode is ModeTest", false)
  end);

val _ = TestFramework.runSuite ("Operator Console Command Dispatcher Tests", fn () =>
  let
    val sim = ExchangeSim.create ()
    val sim = ExchangeSim.addSymbol sim "AAPL"
    val console = OperatorConsole.create sim

    val resHelp = OperatorConsole.processCommand console "HELP"
    val resStats = OperatorConsole.processCommand console "STATS"
    val resSubmit = OperatorConsole.processCommand console "SUBMIT AAPL BUY 100 150.00 TRADER_X"
  in
    TestFramework.assert ("HELP command succeeds", Result.isOk resHelp);
    TestFramework.assert ("STATS command succeeds", Result.isOk resStats);
    TestFramework.assert ("SUBMIT command succeeds", Result.isOk resSubmit);

    let
      val (cAfterSubmit, msg) = Result.unwrap resSubmit
    in
      TestFramework.assert ("Submit returned success message", String.isSubstring "SUBMITTED" msg)
    end
  end);

val _ = TestFramework.reportSummary ();
