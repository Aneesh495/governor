(* test_sim.sml
 * Comprehensive test cases for Synthetic Traders, Deterministic Replay, and ExchangeSim.
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

val _ = TestFramework.runSuite ("Market Replay Determinism Tests", fn () =>
  let
    val p1 = valOf (Types.priceFromString "100.00")
    val p2 = valOf (Types.priceFromString "100.00")

    val ord1 = Order.create { id = 1, client_id = "SELLER", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = p1 }, time_in_force = Types.GTC, price = p1, qty = 100, timestamp = 100 }
    val ord2 = Order.create { id = 2, client_id = "BUYER", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = p2 }, time_in_force = Types.GTC, price = p2, qty = 100, timestamp = 200 }

    val initialBook = OrderBook.create "AAPL"
    val (stats, finalBook, trades) = MarketReplay.replayOrders [ord1, ord2] initialBook
  in
    TestFramework.assertEqualInt ("Replay processed 2 orders", 2, #orders_processed stats);
    TestFramework.assertEqualInt ("Replay generated 1 trade", 1, #trades_generated stats);
    TestFramework.assertEqualLargeInt ("Executed volume 100", 100, #total_volume_executed stats);
    TestFramework.assertEqualInt ("Book remaining orders is 0", 0, OrderBook.totalOrders finalBook)
  end);

val _ = TestFramework.runSuite ("ExchangeSim Multi-Participant Simulation Tests", fn () =>
  let
    val sim = ExchangeSim.create ()
    val sim = ExchangeSim.addSymbol sim "AAPL"

    (* Add Market Maker quoting around 100.00 with 0.10 half-spread *)
    val halfSpread = valOf (Types.priceFromString "0.10")
    val mm = SyntheticTrader.createMarketMaker "MM_FLOW" halfSpread 50 0.0
    val sim = ExchangeSim.registerTrader sim mm

    (* Add Noise Trader submitting orders *)
    val noise = SyntheticTrader.createNoiseTrader "RETAIL_1" 1.0 10
    val sim = ExchangeSim.registerTrader sim noise

    (* Step simulation 5 ticks *)
    val sim = ExchangeSim.step sim 100000000
    val sim = ExchangeSim.step sim 200000000
    val sim = ExchangeSim.step sim 300000000
    val sim = ExchangeSim.step sim 400000000
    val sim = ExchangeSim.step sim 500000000

    val bookOpt = ExchangeSim.getBook sim "AAPL"
  in
    TestFramework.assert ("AAPL book exists", Option.isSome bookOpt);
    let
      val book = valOf bookOpt
    in
      TestFramework.assert ("OrderBook has active quotes", OrderBook.totalOrders book > 0);
      TestFramework.assert ("Event journal recorded entries", EventJournal.size (ExchangeSim.getJournal sim) > 0)
    end
  end);

val _ = TestFramework.reportSummary ();
