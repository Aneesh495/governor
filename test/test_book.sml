(* test_book.sml
 * Comprehensive test cases for Order Book structures.
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

val _ = TestFramework.runSuite ("Order Lifecycle & Iceberg Tests", fn () =>
  let
    val p = valOf (Types.priceFromString "150.00")
    val ord = Order.create {
      id = 1001,
      client_id = "TRADER_A",
      symbol = "AAPL",
      side = Types.Buy,
      order_type = Types.Limit { price = p },
      time_in_force = Types.GTC,
      price = p,
      qty = 100,
      timestamp = 1000
    }
  in
    TestFramework.assert ("Order is active", Order.isActive ord);
    TestFramework.assertEqualLargeInt ("Initial leaves qty", 100, #leaves_qty ord);
    let
      val partiallyFilled = Order.executeFill ord 40 1050
    in
      TestFramework.assertEqualLargeInt ("Leaves after 40 fill", 60, #leaves_qty partiallyFilled);
      TestFramework.assertEqualLargeInt ("Cum after 40 fill", 40, #cum_qty partiallyFilled);
      TestFramework.assert ("Partially filled status", #status partiallyFilled = Types.PartiallyFilled);
      let
        val fullyFilled = Order.executeFill partiallyFilled 60 1100
      in
        TestFramework.assertEqualLargeInt ("Leaves after remaining 60 fill", 0, #leaves_qty fullyFilled);
        TestFramework.assert ("Fully filled status", Order.isFilled fullyFilled)
      end
    end;

    (* Iceberg test *)
    let
      val iceOrd = Order.create {
        id = 1002,
        client_id = "TRADER_B",
        symbol = "MSFT",
        side = Types.Sell,
        order_type = Types.Iceberg { price = p, peak_qty = 50 },
        time_in_force = Types.GTC,
        price = p,
        qty = 200,
        timestamp = 2000
      }
    in
      TestFramework.assertEqualLargeInt ("Iceberg visible peak", 50, #leaves_qty iceOrd);
      TestFramework.assertEqualLargeInt ("Iceberg hidden qty", 150, #hidden_qty iceOrd);
      let
        val filledPeak = Order.executeFill iceOrd 50 2050
        val replenished = Order.replenishIceberg filledPeak 2051
      in
        TestFramework.assertEqualLargeInt ("Replenished peak", 50, #leaves_qty replenished);
        TestFramework.assertEqualLargeInt ("Remaining hidden", 100, #hidden_qty replenished)
      end
    end
  end);

val _ = TestFramework.runSuite ("OrderBook BBO & Price-Time Depth Tests", fn () =>
  let
    val b = OrderBook.create "AAPL"
    val pBid1 = valOf (Types.priceFromString "150.00")
    val pBid2 = valOf (Types.priceFromString "149.90")
    val pAsk1 = valOf (Types.priceFromString "150.10")
    val pAsk2 = valOf (Types.priceFromString "150.20")

    val ordBid1 = Order.create { id = 1, client_id = "C1", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = pBid1 }, time_in_force = Types.GTC, price = pBid1, qty = 100, timestamp = 100 }
    val ordBid2 = Order.create { id = 2, client_id = "C2", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = pBid2 }, time_in_force = Types.GTC, price = pBid2, qty = 200, timestamp = 101 }
    val ordBid3 = Order.create { id = 3, client_id = "C3", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = pBid1 }, time_in_force = Types.GTC, price = pBid1, qty = 150, timestamp = 102 }

    val ordAsk1 = Order.create { id = 4, client_id = "C4", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = pAsk1 }, time_in_force = Types.GTC, price = pAsk1, qty = 300, timestamp = 103 }
    val ordAsk2 = Order.create { id = 5, client_id = "C5", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = pAsk2 }, time_in_force = Types.GTC, price = pAsk2, qty = 400, timestamp = 104 }

    val b = OrderBook.insertOrder b ordBid1
    val b = OrderBook.insertOrder b ordBid2
    val b = OrderBook.insertOrder b ordBid3
    val b = OrderBook.insertOrder b ordAsk1
    val b = OrderBook.insertOrder b ordAsk2
  in
    TestFramework.assertEqualInt ("Total resting orders 5", 5, OrderBook.totalOrders b);
    let
      val (bestBidP, bestBidQ) = valOf (OrderBook.bestBid b)
      val (bestAskP, bestAskQ) = valOf (OrderBook.bestAsk b)
      val sp = valOf (OrderBook.spread b)
      val mid = valOf (OrderBook.midPrice b)
    in
      TestFramework.assertEqualLargeInt ("Best bid price 150.00", pBid1, bestBidP);
      TestFramework.assertEqualLargeInt ("Best bid quantity aggregated 250", 250, bestBidQ);
      TestFramework.assertEqualLargeInt ("Best ask price 150.10", pAsk1, bestAskP);
      TestFramework.assertEqualLargeInt ("Best ask quantity 300", 300, bestAskQ);
      TestFramework.assertEqualLargeInt ("Spread 0.10", valOf (Types.priceFromString "0.10"), sp);
      TestFramework.assertEqualLargeInt ("Mid price 150.05", valOf (Types.priceFromString "150.05"), mid)
    end;

    (* Cancel order 1 *)
    case OrderBook.cancelOrder b 1 200 of
        NONE => TestFramework.assert ("Cancel order 1 should succeed", false)
      | SOME (cancelled, b') =>
          let
            val (_, bestBidQ') = valOf (OrderBook.bestBid b')
          in
            TestFramework.assertEqualInt ("Orders after cancel", 4, OrderBook.totalOrders b');
            TestFramework.assertEqualLargeInt ("Best bid qty after cancel of 100", 150, bestBidQ');
            TestFramework.assert ("Cancelled order status is Cancelled", #status cancelled = Types.Cancelled)
          end
  end);

val _ = TestFramework.runSuite ("BookManager Multi-Symbol Tests", fn () =>
  let
    val mgr = BookManager.create ()
    val mgr = BookManager.addSymbol mgr "AAPL"
    val mgr = BookManager.addSymbol mgr "GOOGL"

    val p = valOf (Types.priceFromString "180.00")
    val ord1 = Order.create { id = 101, client_id = "T1", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = p }, time_in_force = Types.GTC, price = p, qty = 50, timestamp = 100 }
    val ord2 = Order.create { id = 102, client_id = "T2", symbol = "GOOGL", side = Types.Sell, order_type = Types.Limit { price = p }, time_in_force = Types.GTC, price = p, qty = 75, timestamp = 101 }

    val mgr = Result.unwrap (BookManager.insertOrder mgr ord1)
    val mgr = Result.unwrap (BookManager.insertOrder mgr ord2)
  in
    TestFramework.assert ("Has AAPL", BookManager.hasSymbol mgr "AAPL");
    TestFramework.assert ("Has GOOGL", BookManager.hasSymbol mgr "GOOGL");
    TestFramework.assert ("Does not have TSLA", not (BookManager.hasSymbol mgr "TSLA"));
    TestFramework.assertEqualInt ("Total orders across books 2", 2, BookManager.totalOrdersAcrossSymbols mgr);
    TestFramework.assert ("Found order 101 in AAPL", Option.isSome (BookManager.findOrder mgr "AAPL" 101));
    TestFramework.assert ("Order 101 not in GOOGL", not (Option.isSome (BookManager.findOrder mgr "GOOGL" 101)))
  end);

val _ = TestFramework.reportSummary ();
