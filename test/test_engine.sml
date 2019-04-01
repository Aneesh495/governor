(* test_engine.sml
 * Comprehensive test cases for Matching Engine, Allocations, and Call Auctions.
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

val matchIdCounter = ref (1 : LargeInt.int)
fun nextMatchId () : LargeInt.int =
    let val id = !matchIdCounter in matchIdCounter := id + 1; id end;

val _ = TestFramework.runSuite ("Matching Engine FIFO Execution Tests", fn () =>
  let
    val b = OrderBook.create "AAPL"
    val pAsk = valOf (Types.priceFromString "100.00")
    val pAskHigh = valOf (Types.priceFromString "100.50")
    val pBid = valOf (Types.priceFromString "100.00")

    (* Populate asks: 50 lots from C1, 100 lots from C2 at 100.00 *)
    val ask1 = Order.create { id = 1, client_id = "C1", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 50, timestamp = 10 }
    val ask2 = Order.create { id = 2, client_id = "C2", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 100, timestamp = 20 }
    val ask3 = Order.create { id = 3, client_id = "C3", symbol = "AAPL", side = Types.Sell, order_type = Types.Limit { price = pAskHigh }, time_in_force = Types.GTC, price = pAskHigh, qty = 200, timestamp = 30 }

    val b = OrderBook.insertOrder b ask1
    val b = OrderBook.insertOrder b ask2
    val b = OrderBook.insertOrder b ask3

    (* Aggressive buy order: 120 lots at 100.00 *)
    val aggBuy = Order.create { id = 10, client_id = "TAKER", symbol = "AAPL", side = Types.Buy, order_type = Types.Limit { price = pBid }, time_in_force = Types.GTC, price = pBid, qty = 120, timestamp = 100 }

    val res = Matcher.processOrder {
      book = b,
      order = aggBuy,
      policy = MatchingPolicy.Fifo,
      nextMatchId = nextMatchId,
      timestamp = 100
    }
  in
    TestFramework.assertEqualInt ("Number of trades generated", 2, List.length (#trades res));
    TestFramework.assertEqualLargeInt ("Taker remaining leaves", 0, #leaves_qty (#order res));
    TestFramework.assert ("Taker is filled", Order.isFilled (#order res));

    let
      val t1 = List.nth (#trades res, 0)
      val t2 = List.nth (#trades res, 1)
    in
      TestFramework.assertEqualLargeInt ("Trade 1 fills C1 entirely (50)", 50, #qty t1);
      TestFramework.assertEqualLargeInt ("Trade 1 maker ID is 1", 1, #maker_order_id t1);
      TestFramework.assertEqualLargeInt ("Trade 2 partially fills C2 (70)", 70, #qty t2);
      TestFramework.assertEqualLargeInt ("Trade 2 maker ID is 2", 2, #maker_order_id t2)
    end;

    (* Verify remaining book depth *)
    let
      val (bestAskP, bestAskQ) = valOf (OrderBook.bestAsk (#book res))
    in
      TestFramework.assertEqualLargeInt ("Best ask price remains 100.00", pAsk, bestAskP);
      TestFramework.assertEqualLargeInt ("Best ask qty has 30 remaining (100 - 70)", 30, bestAskQ)
    end
  end);

val _ = TestFramework.runSuite ("Time-in-Force IOC, FOK, and PostOnly Tests", fn () =>
  let
    val b = OrderBook.create "MSFT"
    val pAsk = valOf (Types.priceFromString "200.00")
    val ask = Order.create { id = 1, client_id = "C1", symbol = "MSFT", side = Types.Sell, order_type = Types.Limit { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 50, timestamp = 10 }
    val b = OrderBook.insertOrder b ask

    (* Test IOC: Buy 100 at 200.00. Should fill 50, cancel remaining 50 *)
    val iocBuy = Order.create { id = 2, client_id = "IOC_USER", symbol = "MSFT", side = Types.Buy, order_type = Types.Limit { price = pAsk }, time_in_force = Types.IOC, price = pAsk, qty = 100, timestamp = 100 }
    val iocRes = Matcher.processOrder { book = b, order = iocBuy, policy = MatchingPolicy.Fifo, nextMatchId = nextMatchId, timestamp = 100 }
  in
    TestFramework.assertEqualInt ("IOC generated 1 trade", 1, List.length (#trades iocRes));
    TestFramework.assertEqualLargeInt ("IOC trade filled 50", 50, #qty (hd (#trades iocRes)));
    TestFramework.assert ("IOC unfilled portion cancelled", Order.isCancelled (#order iocRes));
    TestFramework.assert ("Book asks now empty", not (Option.isSome (OrderBook.bestAsk (#book iocRes))));

    (* Reset book with 40 shares *)
    let
      val b2 = OrderBook.create "MSFT"
      val b2 = OrderBook.insertOrder b2 (Order.create { id = 3, client_id = "C1", symbol = "MSFT", side = Types.Sell, order_type = Types.Limit { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 40, timestamp = 200 })

      (* Test FOK: Buy 50 at 200.00. Available is only 40. Must KILL with zero trades *)
      val fokBuy = Order.create { id = 4, client_id = "FOK_USER", symbol = "MSFT", side = Types.Buy, order_type = Types.Limit { price = pAsk }, time_in_force = Types.FOK, price = pAsk, qty = 50, timestamp = 210 }
      val fokRes = Matcher.processOrder { book = b2, order = fokBuy, policy = MatchingPolicy.Fifo, nextMatchId = nextMatchId, timestamp = 210 }
    in
      TestFramework.assertEqualInt ("FOK generated 0 trades", 0, List.length (#trades fokRes));
      TestFramework.assert ("FOK order is cancelled", Order.isCancelled (#order fokRes));
      TestFramework.assertEqualLargeInt ("Book asks untouched (40)", 40, #2 (valOf (OrderBook.bestAsk (#book fokRes))))
    end;

    (* Test PostOnly: crosses spread -> must be cancelled *)
    let
      val b3 = OrderBook.create "MSFT"
      val b3 = OrderBook.insertOrder b3 (Order.create { id = 5, client_id = "C1", symbol = "MSFT", side = Types.Sell, order_type = Types.Limit { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 100, timestamp = 300 })
      val postOnlyBuy = Order.create { id = 6, client_id = "MAKER", symbol = "MSFT", side = Types.Buy, order_type = Types.PostOnly { price = pAsk }, time_in_force = Types.GTC, price = pAsk, qty = 50, timestamp = 310 }
      val postRes = Matcher.processOrder { book = b3, order = postOnlyBuy, policy = MatchingPolicy.Fifo, nextMatchId = nextMatchId, timestamp = 310 }
    in
      TestFramework.assertEqualInt ("PostOnly generated 0 trades", 0, List.length (#trades postRes));
      TestFramework.assert ("PostOnly order is cancelled", Order.isCancelled (#order postRes))
    end
  end);

val _ = TestFramework.runSuite ("Call Auction Price Discovery Tests", fn () =>
  let
    val b = OrderBook.create "XYZ"
    val p98 = valOf (Types.priceFromString "98.00")
    val p99 = valOf (Types.priceFromString "99.00")
    val p100 = valOf (Types.priceFromString "100.00")
    val p101 = valOf (Types.priceFromString "101.00")
    val p102 = valOf (Types.priceFromString "102.00")

    (* Buyers willing to buy high *)
    val b = OrderBook.insertOrder b (Order.create { id = 1, client_id = "B1", symbol = "XYZ", side = Types.Buy, order_type = Types.Limit { price = p102 }, time_in_force = Types.GTC, price = p102, qty = 100, timestamp = 10 })
    val b = OrderBook.insertOrder b (Order.create { id = 2, client_id = "B2", symbol = "XYZ", side = Types.Buy, order_type = Types.Limit { price = p101 }, time_in_force = Types.GTC, price = p101, qty = 150, timestamp = 20 })
    val b = OrderBook.insertOrder b (Order.create { id = 3, client_id = "B3", symbol = "XYZ", side = Types.Buy, order_type = Types.Limit { price = p100 }, time_in_force = Types.GTC, price = p100, qty = 200, timestamp = 30 })

    (* Sellers willing to sell low *)
    val b = OrderBook.insertOrder b (Order.create { id = 4, client_id = "S1", symbol = "XYZ", side = Types.Sell, order_type = Types.Limit { price = p98 }, time_in_force = Types.GTC, price = p98, qty = 120, timestamp = 40 })
    val b = OrderBook.insertOrder b (Order.create { id = 5, client_id = "S2", symbol = "XYZ", side = Types.Sell, order_type = Types.Limit { price = p99 }, time_in_force = Types.GTC, price = p99, qty = 100, timestamp = 50 })
    val b = OrderBook.insertOrder b (Order.create { id = 6, client_id = "S3", symbol = "XYZ", side = Types.Sell, order_type = Types.Limit { price = p100 }, time_in_force = Types.GTC, price = p100, qty = 180, timestamp = 60 })

    val refPrice = p100
    val uncrossRes = Auction.uncross {
      book = b,
      reference_price = refPrice,
      nextMatchId = nextMatchId,
      timestamp = 500
    }
  in
    TestFramework.assertEqualLargeInt ("Auction clearing price is 100.00", p100, valOf (#clearing_price uncrossRes));
    TestFramework.assertEqualLargeInt ("Auction cleared max volume 400", 400, #cleared_volume uncrossRes);
    TestFramework.assert ("Auction generated trades", List.length (#trades uncrossRes) > 0);
    TestFramework.assert ("Residual orders remain cleanly in book", OrderBook.totalOrders (#book uncrossRes) > 0)
  end);

val _ = TestFramework.reportSummary ();
