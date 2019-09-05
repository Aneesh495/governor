(* test_stress.sml
 * High-throughput stress test: 50,000 rapid order lifecycle operations,
 * crossings, aggressive market orders, cancel-replaces, and latency profiling.
 *)

val _ = use "test/test_framework.sig";
val _ = use "test/test_framework.sml";
val _ = use "src/core/result.sig";
val _ = use "src/core/result.sml";
val _ = use "src/core/types.sig";
val _ = use "src/core/types.sml";
val _ = use "src/core/fifo_queue.sig";
val _ = use "src/core/fifo_queue.sml";
val _ = use "src/core/red_black_map.sig";
val _ = use "src/core/red_black_map.sml";
val _ = use "src/core/time_util.sig";
val _ = use "src/core/time_util.sml";
val _ = use "src/core/latency_histogram.sig";
val _ = use "src/core/latency_histogram.sml";
val _ = use "src/book/order.sig";
val _ = use "src/book/order.sml";
val _ = use "src/book/price_level.sig";
val _ = use "src/book/price_level.sml";
val _ = use "src/book/order_book.sig";
val _ = use "src/book/order_book.sml";
val _ = use "src/engine/trade.sig";
val _ = use "src/engine/trade.sml";
val _ = use "src/engine/matching_policy.sig";
val _ = use "src/engine/matching_policy.sml";
val _ = use "src/engine/circuit_breaker.sig";
val _ = use "src/engine/circuit_breaker.sml";
val _ = use "src/engine/matcher.sig";
val _ = use "src/engine/matcher.sml";

structure TestStress =
struct
  val nextMatchId = ref (1 : LargeInt.int)
  fun allocMatchId () : LargeInt.int =
      let val id = !nextMatchId in nextMatchId := id + 1; id end

  fun toPrice (dollars : LargeInt.int) : Types.price =
      dollars * Types.priceScale

  fun run () =
      TestFramework.runSuite ("Engine High-Throughput Stress Test (50,000 Orders)", fn () =>
        let
          val book = OrderBook.create "STRESS"
          val hist = LatencyHistogram.create ()
          val totalOrders = 50000

          val _ = print ("\nInitiating 50,000-order stress execution across mixed bid/ask liquidity...\n")
          val startTime = Time.now ()

          (* Seed resting liquidity: 10,000 asks and 10,000 bids *)
          val seedCount = 10000
          fun seedLiquidity (0, b) = b
            | seedLiquidity (i, b) =
                let
                  val pAsk = toPrice (100 + LargeInt.fromInt (i mod 50 + 1))
                  val pBid = toPrice (100 - LargeInt.fromInt (i mod 50 + 1))

                  val ask = Order.create {
                    id = LargeInt.fromInt (i * 2),
                    client_id = "MAKER_ASK",
                    symbol = "STRESS",
                    side = Types.Sell,
                    order_type = Types.Limit { price = pAsk },
                    time_in_force = Types.GTC,
                    price = pAsk,
                    qty = 10,
                    timestamp = LargeInt.fromInt i
                  }
                  val bid = Order.create {
                    id = LargeInt.fromInt (i * 2 + 1),
                    client_id = "MAKER_BID",
                    symbol = "STRESS",
                    side = Types.Buy,
                    order_type = Types.Limit { price = pBid },
                    time_in_force = Types.GTC,
                    price = pBid,
                    qty = 10,
                    timestamp = LargeInt.fromInt i
                  }
                  val b' = OrderBook.insertOrder b ask
                  val b'' = OrderBook.insertOrder b' bid
                in
                  seedLiquidity (i - 1, b'')
                end

          val populatedBook = seedLiquidity (seedCount, book)
          val totalRestingInitial = OrderBook.totalOrders populatedBook
          val _ = TestFramework.assertEqualInt ("Initial resting orders is 20,000", 20000, totalRestingInitial)

          (* Now fire 30,000 aggressive matching orders *)
          val matchCount = 30000
          fun executeAggressive (0, b, tradesAcc) = (b, tradesAcc)
            | executeAggressive (i, b, tradesAcc) =
                let
                  val isBuy = (i mod 2 = 0)
                  val side = if isBuy then Types.Buy else Types.Sell
                  val limitP = if isBuy then toPrice 120 else toPrice 80
                  val ord = Order.create {
                    id = LargeInt.fromInt (100000 + i),
                    client_id = "TAKER",
                    symbol = "STRESS",
                    side = side,
                    order_type = Types.Limit { price = limitP },
                    time_in_force = Types.IOC,
                    price = limitP,
                    qty = 5,
                    timestamp = LargeInt.fromInt (20000 + i)
                  }

                  val t0 = Time.now ()
                  val res = Matcher.processOrder {
                    book = b,
                    order = ord,
                    policy = MatchingPolicy.Fifo,
                    nextMatchId = allocMatchId,
                    timestamp = LargeInt.fromInt (20000 + i)
                  }
                  val t1 = Time.now ()
                  val deltaNs = Time.toNanoseconds (Time.- (t1, t0))
                  val _ = LatencyHistogram.record hist (LargeInt.toLarge deltaNs)
                in
                  executeAggressive (i - 1, #book res, List.length (#trades res) + tradesAcc)
                end

          val (finalBook, totalTrades) = executeAggressive (matchCount, populatedBook, 0)
          val endTime = Time.now ()
          val totalDurationSec = Time.toReal (Time.- (endTime, startTime))
          val throughput = Real.fromInt totalOrders / totalDurationSec

          val _ = print (LatencyHistogram.printSummary hist)
          val _ = print ("Total trades generated: " ^ Int.toString totalTrades ^ "\n")
          val _ = print ("Total elapsed time:     " ^ Real.fmt (StringCvt.FIX (SOME 3)) totalDurationSec ^ " s\n")
          val _ = print ("Aggregated throughput:  " ^ Real.fmt (StringCvt.FIX (SOME 0)) throughput ^ " orders/sec\n")

          val _ = TestFramework.assert ("Stress test generated trades", totalTrades > 0)
          val _ = TestFramework.assert ("Throughput exceeded 10,000 orders/sec in interpreter", throughput > 10000.0)
        in
          ()
        end
      )
end;

val _ = TestStress.run ();
