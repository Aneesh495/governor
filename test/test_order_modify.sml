(* test_order_modify.sml
 * Unit tests for OrderModify Cancel-Replace semantics and FIFO queue priority preservation.
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
val _ = use "src/book/order.sig";
val _ = use "src/book/order.sml";
val _ = use "src/book/price_level.sig";
val _ = use "src/book/price_level.sml";
val _ = use "src/book/order_book.sig";
val _ = use "src/book/order_book.sml";
val _ = use "src/book/order_modify.sig";
val _ = use "src/book/order_modify.sml";

structure TestOrderModify =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("OrderModify Cancel-Replace Semantics Tests", fn () =>
        let
          val book = OrderBook.create "AAPL"
          val p100 = toPrice 100

          (* Add two orders at the same price: Order 1 (100 lots), then Order 2 (200 lots) *)
          val ord1 = Order.create {
            id = 1,
            client_id = "C1",
            symbol = "AAPL",
            side = Types.Buy,
            order_type = Types.Limit { price = p100 },
            time_in_force = Types.GTC,
            price = p100,
            qty = 100,
            timestamp = 1000
          }
          val ord2 = Order.create {
            id = 2,
            client_id = "C2",
            symbol = "AAPL",
            side = Types.Buy,
            order_type = Types.Limit { price = p100 },
            time_in_force = Types.GTC,
            price = p100,
            qty = 200,
            timestamp = 1010
          }

          val book = OrderBook.insertOrder book ord1
          val book = OrderBook.insertOrder book ord2

          val (_, initialQty) = valOf (OrderBook.bestBid book)
          val _ = TestFramework.assertEqualLargeInt ("Initial bid quantity is 300", 300, initialQty)

          (* Case 1: Quantity reduction (100 -> 60) at same price -> PriorityPreserved *)
          val res1 = OrderModify.modifyOrder {
            book = book,
            order_id = 1,
            new_price = NONE,
            new_qty = SOME 60,
            timestamp = 2000
          }
          val _ = TestFramework.assert ("Modify 1 succeeds", Result.isOk res1)
          val mod1 = Result.unwrap res1
          val _ = TestFramework.assert ("Priority preserved on size reduction",
                    #effect mod1 = OrderModify.PriorityPreserved)
          val _ = TestFramework.assertEqualLargeInt ("Updated order leaves qty is 60", 60, #leaves_qty (#updated_order mod1))

          val bookAfterMod1 = #book mod1
          val (_, qtyAfterMod1) = valOf (OrderBook.bestBid bookAfterMod1)
          val _ = TestFramework.assertEqualLargeInt ("Total bid quantity updated to 260 (60 + 200)", 260, qtyAfterMod1)

          (* Case 2: Quantity increase (60 -> 150) -> PriorityLost (re-queued to back of level) *)
          val res2 = OrderModify.modifyOrder {
            book = bookAfterMod1,
            order_id = 1,
            new_price = NONE,
            new_qty = SOME 150,
            timestamp = 3000
          }
          val _ = TestFramework.assert ("Modify 2 succeeds", Result.isOk res2)
          val mod2 = Result.unwrap res2
          val _ = TestFramework.assert ("Priority lost on size increase",
                    #effect mod2 = OrderModify.PriorityLost)
          val _ = TestFramework.assertEqualLargeInt ("Updated order leaves qty is 150", 150, #leaves_qty (#updated_order mod2))

          (* Case 3: Price change ($100 -> $101) -> PriorityLost (moves to new price level) *)
          val p101 = toPrice 101
          val res3 = OrderModify.modifyOrder {
            book = #book mod2,
            order_id = 1,
            new_price = SOME p101,
            new_qty = SOME 50,
            timestamp = 4000
          }
          val _ = TestFramework.assert ("Modify 3 succeeds", Result.isOk res3)
          val mod3 = Result.unwrap res3
          val _ = TestFramework.assert ("Priority lost on price change",
                    #effect mod3 = OrderModify.PriorityLost)

          val bookAfterMod3 = #book mod3
          val (bestP, bestQ) = valOf (OrderBook.bestBid bookAfterMod3)
          val _ = TestFramework.assertEqualLargeInt ("New best bid price is $101", p101, bestP)
          val _ = TestFramework.assertEqualLargeInt ("New best bid quantity is 50", 50, bestQ)

          (* Case 4: Non-existent order ID returns error *)
          val res4 = OrderModify.modifyOrder {
            book = bookAfterMod3,
            order_id = 9999,
            new_price = NONE,
            new_qty = SOME 10,
            timestamp = 5000
          }
          val _ = TestFramework.assert ("Unknown order modification rejected with Err", Result.isErr res4)
        in
          ()
        end
      )
end;

val _ = TestOrderModify.run ();
