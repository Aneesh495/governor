(* test_risk.sml
 * Comprehensive test cases for Pre-Trade Risk Gateway controls.
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
val _ = use "src/risk/risk_limits.sig";
val _ = use "src/risk/risk_limits.sml";
val _ = use "src/risk/trader_state.sig";
val _ = use "src/risk/trader_state.sml";
val _ = use "src/risk/self_match.sig";
val _ = use "src/risk/self_match.sml";
val _ = use "src/risk/risk_engine.sig";
val _ = use "src/risk/risk_engine.sml";

val _ = TestFramework.runSuite ("Trader State Position and Cash Accounting", fn () =>
  let
    val s = TraderState.create "FIRM_A" 1000000
    val p = valOf (Types.priceFromString "100.00")
    val s1 = TraderState.updatePositionOnTrade s "AAPL" Types.Buy 100 p
  in
    TestFramework.assertEqualLargeInt ("Position after buy 100", 100, TraderState.getPosition s1 "AAPL");
    TestFramework.assertEqualLargeInt ("Cash after buy (1,000,000 - 10,000)", 990000, TraderState.cashBalance s1);
    let
      val s2 = TraderState.updatePositionOnTrade s1 "AAPL" Types.Sell 40 p
    in
      TestFramework.assertEqualLargeInt ("Position after partial sell (100 - 40)", 60, TraderState.getPosition s2 "AAPL");
      TestFramework.assertEqualLargeInt ("Cash after sell (990,000 + 4,000)", 994000, TraderState.cashBalance s2)
    end
  end);

val _ = TestFramework.runSuite ("Rate Limiter Sliding Window Tests", fn () =>
  let
    val s = TraderState.create "ALGO_BOT" 5000000
    val t0 = 1000000000000 : Types.timestamp_ns
    val s = TraderState.recordMessage s t0
    val s = TraderState.recordMessage s (t0 + 100000000)
    val s = TraderState.recordMessage s (t0 + 200000000)
  in
    TestFramework.assertEqualInt ("Rate at t0+200ms is 3", 3, TraderState.messageRateInLastSecond s (t0 + 200000000));
    TestFramework.assertEqualInt ("Rate at t0+1.5s drops old messages", 0, TraderState.messageRateInLastSecond s (t0 + 1500000000))
  end);

val _ = TestFramework.runSuite ("Pre-Trade Risk Gateway Limits Enforcement", fn () =>
  let
    val eng = RiskEngine.create ()
    val lim = RiskLimits.create {
      client_id = "TRADER_1",
      max_order_qty = 500,
      max_order_notional = 50000,
      price_collar_pct = 0.05,
      max_long_position = 1000,
      max_short_position = 1000,
      max_gross_exposure = 200000,
      max_orders_per_second = 5,
      smp_mode = Types.CancelNewest
    }
    val eng = RiskEngine.registerClient eng "TRADER_1" lim 1000000
    val b = OrderBook.create "SPY"
    val p = valOf (Types.priceFromString "100.00")

    (* Order exceeding max quantity *)
    val badQtyOrd = Order.create { id = 1, client_id = "TRADER_1", symbol = "SPY", side = Types.Buy, order_type = Types.Limit { price = p }, time_in_force = Types.GTC, price = p, qty = 600, timestamp = 100 }
    val res1 = RiskEngine.validateOrder { engine = eng, book = b, order = badQtyOrd, timestamp = 100 }

    (* Valid order within limits *)
    val goodOrd = Order.create { id = 2, client_id = "TRADER_1", symbol = "SPY", side = Types.Buy, order_type = Types.Limit { price = p }, time_in_force = Types.GTC, price = p, qty = 100, timestamp = 100 }
    val res2 = RiskEngine.validateOrder { engine = eng, book = b, order = goodOrd, timestamp = 100 }
  in
    TestFramework.assert ("Bad qty rejected", Result.isErr res1);
    TestFramework.assert ("Good order accepted", Result.isOk res2)
  end);

val _ = TestFramework.runSuite ("Self-Match Prevention (SMP) Tests", fn () =>
  let
    val b = OrderBook.create "NVDA"
    val p = valOf (Types.priceFromString "120.00")
    val restingAsk = Order.create { id = 10, client_id = "MM_1", symbol = "NVDA", side = Types.Sell, order_type = Types.Limit { price = p }, time_in_force = Types.GTC, price = p, qty = 100, timestamp = 50 }
    val b = OrderBook.insertOrder b restingAsk

    (* Same client sends crossing buy order *)
    val incomingBuy = Order.create { id = 11, client_id = "MM_1", symbol = "NVDA", side = Types.Buy, order_type = Types.Limit { price = p }, time_in_force = Types.GTC, price = p, qty = 100, timestamp = 60 }
    val smpAction = SelfMatch.evaluateSMP { book = b, order = incomingBuy, mode = Types.CancelNewest }
  in
    case smpAction of
        SelfMatch.CancelIncoming _ => TestFramework.assert ("SMP CancelNewest caught self match", true)
      | _ => TestFramework.assert ("SMP CancelNewest failed to catch self match", false)
  end);

val _ = TestFramework.reportSummary ();
