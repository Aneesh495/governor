(* test_net.sml
 * Comprehensive test cases for GatewaySession and OrderGateway network protocol handlers.
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
val _ = use "src/protocol/binary_codec.sig";
val _ = use "src/protocol/binary_codec.sml";
val _ = use "src/protocol/fix_message.sig";
val _ = use "src/protocol/fix_message.sml";
val _ = use "src/net/gateway_session.sig";
val _ = use "src/net/gateway_session.sml";
val _ = use "src/net/order_gateway.sig";
val _ = use "src/net/order_gateway.sml";

val _ = TestFramework.runSuite ("Gateway Session Sequence & Heartbeat Tests", fn () =>
  let
    val s = GatewaySession.create 1
    val s = GatewaySession.logon s "CLIENT_XYZ" 1000
    val res1 = GatewaySession.verifyInSeq s 1
    val resGap = GatewaySession.verifyInSeq s 5
  in
    TestFramework.assert ("Seq 1 accepted", Result.isOk res1);
    TestFramework.assert ("Seq 5 gap rejected", Result.isErr resGap);
    TestFramework.assertEqualLargeInt ("Next out seq is 1", 1, GatewaySession.nextOutSeq s);
    TestFramework.assertEqualLargeInt ("Next out seq is 2", 2, GatewaySession.nextOutSeq s)
  end);

val _ = TestFramework.runSuite ("Order Gateway Binary Order Ingestion Tests", fn () =>
  let
    val sim = ExchangeSim.create ()
    val sim = ExchangeSim.addSymbol sim "AAPL"
    val gw = OrderGateway.create sim
    val sess = GatewaySession.create 10

    val p = valOf (Types.priceFromString "150.00")
    val req : BinaryCodec.binary_new_order = {
      seq = 1,
      timestamp = 5000,
      client_id = "BROKER_A",
      symbol = "AAPL",
      order_id = 777,
      side = Types.Buy,
      order_type = Types.Limit { price = p },
      time_in_force = Types.GTC,
      price = p,
      qty = 100
    }
    val buf = BinaryCodec.encodeNewOrder req
    val handleRes = OrderGateway.handleBinaryPacket gw sess buf 5000
  in
    TestFramework.assert ("Binary packet processed successfully", Result.isOk handleRes);
    let
      val (_, _, replies) = Result.unwrap handleRes
    in
      TestFramework.assert ("Execution report generated", List.length replies > 0)
    end
  end);

val _ = TestFramework.reportSummary ();
