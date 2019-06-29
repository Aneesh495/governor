(* test_properties_matching.sml
 * Property-based testing for Matching Engine invariants:
 * 1. Volume conservation
 * 2. Price priority monotonicity
 * 3. Limit price bounds
 *)

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
val _ = use "test/property_framework.sig";
val _ = use "test/property_framework.sml";

structure TestPropertiesMatching =
struct
  val nextOrderId = ref (1000 : LargeInt.int)
  val nextMatchId = ref (5000 : LargeInt.int)

  fun allocOrderId () : Types.order_id =
      let val id = !nextOrderId in nextOrderId := id + 1; id end

  fun allocMatchId () : LargeInt.int =
      let val id = !nextMatchId in nextMatchId := id + 1; id end

  fun toPrice (dollars : LargeInt.int) : Types.price =
      dollars * Types.priceScale

  fun createRestingAsk (priceVal : LargeInt.int, qtyVal : LargeInt.int) : Order.order =
      let
        val p = toPrice priceVal
      in
        Order.create {
          id = allocOrderId (),
          client_id = "MAKER",
          symbol = "PROP",
          side = Types.Sell,
          order_type = Types.Limit { price = p },
          time_in_force = Types.GTC,
          price = p,
          qty = qtyVal,
          timestamp = 1000
        }
      end

  fun createTakerBuy (priceVal : LargeInt.int, qtyVal : LargeInt.int) : Order.order =
      let
        val p = toPrice priceVal
      in
        Order.create {
          id = allocOrderId (),
          client_id = "TAKER",
          symbol = "PROP",
          side = Types.Buy,
          order_type = Types.Limit { price = p },
          time_in_force = Types.GTC,
          price = p,
          qty = qtyVal,
          timestamp = 2000
        }
      end

  (* Property 1: Volume Conservation: sum(trade.qty) + taker.leaves_qty = taker.initial_qty *)
  fun prop_volume_conservation (pricesAndQtys : (int * int) list) : bool =
      let
        val book = OrderBook.create "PROP"
        val populatedBook = List.foldl (fn ((p, q), b) =>
          let
            val ask = createRestingAsk (LargeInt.fromInt (abs p + 100), LargeInt.fromInt (abs q + 1))
          in
            OrderBook.insertOrder b ask
          end) book pricesAndQtys

        val taker = createTakerBuy (150, 250)
        val initialQty = #initial_qty taker

        val res = Matcher.processOrder {
          book = populatedBook,
          order = taker,
          policy = MatchingPolicy.Fifo,
          nextMatchId = allocMatchId,
          timestamp = 3000
        }

        val tradedQty = List.foldl (fn (t : Trade.trade, acc) => acc + #qty t) 0 (#trades res)
        val leavesQty = #leaves_qty (#order res)
      in
        tradedQty + leavesQty = initialQty
      end

  (* Property 2: Price Priority: Matched asks must have non-decreasing prices *)
  fun prop_price_priority (pricesAndQtys : (int * int) list) : bool =
      let
        val book = OrderBook.create "PROP"
        val populatedBook = List.foldl (fn ((p, q), b) =>
          let
            val ask = createRestingAsk (LargeInt.fromInt (abs p + 100), LargeInt.fromInt (abs q + 1))
          in
            OrderBook.insertOrder b ask
          end) book pricesAndQtys

        val taker = createTakerBuy (200, 1000)
        val res = Matcher.processOrder {
          book = populatedBook,
          order = taker,
          policy = MatchingPolicy.Fifo,
          nextMatchId = allocMatchId,
          timestamp = 3000
        }

        fun checkMonotonic [] = true
          | checkMonotonic [_] = true
          | checkMonotonic (t1 :: t2 :: rest) =
              (#price t1 <= #price t2) andalso checkMonotonic (t2 :: rest)
      in
        checkMonotonic (#trades res)
      end

  (* Property 3: Taker never matches at price worse than taker limit *)
  fun prop_no_price_violation (pricesAndQtys : (int * int) list) : bool =
      let
        val book = OrderBook.create "PROP"
        val populatedBook = List.foldl (fn ((p, q), b) =>
          let
            val ask = createRestingAsk (LargeInt.fromInt (abs p + 100), LargeInt.fromInt (abs q + 1))
          in
            OrderBook.insertOrder b ask
          end) book pricesAndQtys

        val takerLimit = toPrice 120
        val taker = createTakerBuy (120, 500)
        val res = Matcher.processOrder {
          book = populatedBook,
          order = taker,
          policy = MatchingPolicy.Fifo,
          nextMatchId = allocMatchId,
          timestamp = 3000
        }
      in
        List.all (fn t => #price t <= takerLimit) (#trades res)
      end

  fun run () =
      let
        val genPricesAndQtys = PropertyFramework.genList
          (fn r => (PropertyFramework.genInt (0, 40) r, PropertyFramework.genInt (1, 100) r)) 10

        fun showInput xs = Int.toString (List.length xs) ^ " orders"

        val tests = [
          {
            name = "Matching: Volume conservation (sum(trades) + leaves = initial)",
            trials = 100,
            generator = genPricesAndQtys,
            property = prop_volume_conservation,
            showCounterExample = showInput
          },
          {
            name = "Matching: Price priority (matched asks strictly non-decreasing)",
            trials = 100,
            generator = genPricesAndQtys,
            property = prop_price_priority,
            showCounterExample = showInput
          },
          {
            name = "Matching: Limit price bounds respected (no trades above taker limit)",
            trials = 100,
            generator = genPricesAndQtys,
            property = prop_no_price_violation,
            showCounterExample = showInput
          }
        ]
        val (p, f) = PropertyFramework.runProperties "Matching Engine Invariants" tests
      in
        if f = 0 then (print "Matching property tests passed!\n"; true)
        else (print "Matching property tests FAILED!\n"; false)
      end
end;

val _ = TestPropertiesMatching.run ();
