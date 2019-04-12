(* test_marketdata.sml
 * Comprehensive test cases for Market Data dissemination feeds and Event Journal.
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
val _ = use "src/marketdata/market_data_event.sig";
val _ = use "src/marketdata/market_data_event.sml";
val _ = use "src/marketdata/level1_feed.sig";
val _ = use "src/marketdata/level1_feed.sml";
val _ = use "src/marketdata/level2_feed.sig";
val _ = use "src/marketdata/level2_feed.sml";
val _ = use "src/marketdata/event_journal.sig";
val _ = use "src/marketdata/event_journal.sml";

val _ = TestFramework.runSuite ("MarketData Event Formatting Tests", fn () =>
  let
    val p = valOf (Types.priceFromString "150.25")
    val ev = MarketDataEvent.OrderAdded {
      seq = 1,
      symbol = "AAPL",
      order_id = 100,
      side = Types.Buy,
      price = p,
      qty = 250,
      timestamp = 5000
    }
  in
    TestFramework.assertEqualLargeInt ("Event seq is 1", 1, MarketDataEvent.sequenceNumber ev);
    TestFramework.assertEqualString ("Event symbol is AAPL", "AAPL", MarketDataEvent.symbol ev);
    TestFramework.assert ("Formatted event contains price", String.isSubstring "150.25000000" (MarketDataEvent.toString ev))
  end);

val _ = TestFramework.runSuite ("Level 1 BBO Filtering Tests", fn () =>
  let
    val f = Level1Feed.create ()
    val b = OrderBook.create "AAPL"
    val pBid = valOf (Types.priceFromString "150.00")
    val pAsk = valOf (Types.priceFromString "150.10")

    val ord1 = Order.create { id = 1, client_id = "C1", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = pBid }, time_in_force = Types.GTC, price = pBid, qty = 100, timestamp = 10 }
    val b = OrderBook.insertOrder b ord1

    (* First update: must emit initial BBO *)
    val (f1, emit1) = Level1Feed.updateBook f b 10
  in
    TestFramework.assert ("First update emits BBO", Option.isSome emit1);
    let
      val bbo = valOf emit1
    in
      TestFramework.assertEqualLargeInt ("BBO bid price 150.00", pBid, valOf (#bid_price bbo));
      TestFramework.assertEqualLargeInt ("BBO bid qty 100", 100, valOf (#bid_qty bbo));
      TestFramework.assert ("BBO ask is none", not (Option.isSome (#ask_price bbo)))
    end;

    (* Identical update: should filter out and emit NONE *)
    let
      val (f2, emit2) = Level1Feed.updateBook f1 b 15
    in
      TestFramework.assert ("Identical book update emits NONE", not (Option.isSome emit2))
    end;

    (* Add ask: BBO changes -> must emit new BBO *)
    let
      val ord2 = Order.create { id = 2, client_id = "C2", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 50, timestamp = 20 }
      val b2 = OrderBook.insertOrder b ord2
      val (f3, emit3) = Level1Feed.updateBook f1 b2 20
    in
      TestFramework.assert ("Ask addition emits new BBO", Option.isSome emit3);
      let
        val bbo3 = valOf emit3
      in
        TestFramework.assertEqualLargeInt ("New BBO ask price 150.10", pAsk, valOf (#ask_price bbo3));
        TestFramework.assertEqualLargeInt ("New BBO ask qty 50", 50, valOf (#ask_qty bbo3))
      end
    end
  end);

val _ = TestFramework.runSuite ("Level 2 Depth Snapshot Tests", fn () =>
  let
    val b = OrderBook.create "GOOGL"
    val p1 = valOf (Types.priceFromString "100.00")
    val p2 = valOf (Types.priceFromString "99.00")
    val p3 = valOf (Types.priceFromString "101.00")

    val b = OrderBook.insertOrder b (Order.create { id = 1, client_id = "C1", symbol = "GOOGL", side = Types.Buy, order_type = Types.Limit { price = p1 }, time_in_force = Types.GTC, price = p1, qty = 100, timestamp = 1 })
    val b = OrderBook.insertOrder b (Order.create { id = 2, client_id = "C2", symbol = "GOOGL", side = Types.Buy, order_type = Types.Limit { price = p2 }, time_in_force = Types.GTC, price = p2, qty = 200, timestamp = 2 })
    val b = OrderBook.insertOrder b (Order.create { id = 3, client_id = "C3", symbol = "GOOGL", side = Types.Sell, order_type = Types.Limit { price = p3 }, time_in_force = Types.GTC, price = p3, qty = 300, timestamp = 3 })

    val snap = Level2Feed.createSnapshot b 5 100
  in
    TestFramework.assertEqualInt ("Snapshot has 2 bid levels", 2, List.length (#bids snap));
    TestFramework.assertEqualInt ("Snapshot has 1 ask level", 1, List.length (#asks snap));
    TestFramework.assert ("Snapshot string contains depth info", String.isSubstring "GOOGL" (Level2Feed.snapshotToString snap))
  end);

val _ = TestFramework.runSuite ("Event Journal Append and Replay Tests", fn () =>
  let
    val j = EventJournal.create 5
    val ev1 = MarketDataEvent.OrderAdded { seq = 1, symbol = "SPY", order_id = 10, side = Types.Buy, price = valOf (Types.priceFromString "500.00"), qty = 10, timestamp = 100 }
    val ev2 = MarketDataEvent.OrderAdded { seq = 2, symbol = "SPY", order_id = 11, side = Types.Sell, price = valOf (Types.priceFromString "501.00"), qty = 20, timestamp = 200 }

    val () = EventJournal.record j ev1
    val () = EventJournal.record j ev2
  in
    TestFramework.assertEqualInt ("Journal size 2", 2, EventJournal.size j);
    let
      val events = EventJournal.replayEvents j
    in
      TestFramework.assertEqualInt ("Replay count 2", 2, List.length events);
      TestFramework.assertEqualLargeInt ("First event seq 1", 1, MarketDataEvent.sequenceNumber (hd events))
    end
  end);

val _ = TestFramework.reportSummary ();
