(* test_core.sml
 * Comprehensive test cases for Governor Core modules.
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

val _ = TestFramework.runSuite ("Core Result Tests", fn () =>
  let
    val r1 = Result.ok 10
    val r2 = Result.map (fn x => x * 2) r1
    val r3 = Result.err "failed"
  in
    TestFramework.assert ("Result isOk on Ok", Result.isOk r1);
    TestFramework.assert ("Result isErr on Err", Result.isErr r3);
    TestFramework.assertEqualInt ("Result map value", 20, Result.unwrap r2);
    TestFramework.assertEqualInt ("Result getOrElse on Ok", 10, Result.getOrElse 999 r1);
    TestFramework.assertEqualInt ("Result getOrElse on Err", 999, Result.getOrElse 999 r3);
    case Result.sequence [Result.ok 1, Result.ok 2, Result.ok 3] of
        Result.Ok [1, 2, 3] => TestFramework.assert ("Result sequence all Ok", true)
      | _ => TestFramework.assert ("Result sequence all Ok", false)
  end);

val _ = TestFramework.runSuite ("Core Types & Price Precision Tests", fn () =>
  let
    val p1 = valOf (Types.priceFromString "150.25000000")
    val p2 = valOf (Types.priceFromString "150.25")
    val p3 = valOf (Types.priceFromString "0.00000001")
    val p4 = valOf (Types.priceFromString "-10.50")
  in
    TestFramework.assertEqualLargeInt ("Price equality on padding", p1, p2);
    TestFramework.assertEqualLargeInt ("Price 1 tick", 1, p3);
    TestFramework.assertEqualString ("Price formatting exact", "150.25000000", Types.priceToString p1);
    TestFramework.assertEqualString ("Price formatting negative", "-10.50000000", Types.priceToString p4);
    TestFramework.assertEqualString ("Side string Buy", "BUY", Types.sideToString Types.Buy);
    TestFramework.assertEqualString ("Side string Sell", "SELL", Types.sideToString Types.Sell);
    TestFramework.assert ("Opposite side", Types.oppositeSide Types.Buy = Types.Sell andalso Types.oppositeSide Types.Sell = Types.Buy)
  end);

val _ = TestFramework.runSuite ("Core WordUtil & Bitwise Tests", fn () =>
  let
    val w16 = 0wx1234 : Word32.word
    val swapped16 = WordUtil.swap16 w16
    val packed16 = WordUtil.packU16BE w16
    val (unpacked16, _) = WordUtil.unpackU16BE packed16

    val w32 = 0wx12345678 : Word32.word
    val swapped32 = WordUtil.swap32 w32
    val packed32 = WordUtil.packU32BE w32
    val (unpacked32, _) = WordUtil.unpackU32BE packed32

    val h1 = WordUtil.hashString "AAPL"
    val h2 = WordUtil.hashString "AAPL"
    val h3 = WordUtil.hashString "MSFT"
  in
    TestFramework.assert ("Swap16 correct", swapped16 = 0wx3412);
    TestFramework.assert ("Pack and unpack U16BE matches", unpacked16 = w16);
    TestFramework.assert ("Swap32 correct", swapped32 = 0wx78563412);
    TestFramework.assert ("Pack and unpack U32BE matches", unpacked32 = w32);
    TestFramework.assert ("String hash deterministic", h1 = h2);
    TestFramework.assert ("Different strings have distinct hashes", h1 <> h3)
  end);

val _ = TestFramework.runSuite ("Core FifoQueue Tests", fn () =>
  let
    val q = FifoQueue.empty
    val q = FifoQueue.pushBack q "order1"
    val q = FifoQueue.pushBack q "order2"
    val q = FifoQueue.pushBack q "order3"
  in
    TestFramework.assertEqualInt ("Queue size 3", 3, FifoQueue.length q);
    TestFramework.assertEqualString ("Peek front", "order1", valOf (FifoQueue.peekFront q));
    let
      val (item1, q) = valOf (FifoQueue.popFront q)
      val (item2, q) = valOf (FifoQueue.popFront q)
      val (item3, q) = valOf (FifoQueue.popFront q)
    in
      TestFramework.assertEqualString ("Pop 1", "order1", item1);
      TestFramework.assertEqualString ("Pop 2", "order2", item2);
      TestFramework.assertEqualString ("Pop 3", "order3", item3);
      TestFramework.assert ("Queue empty after pops", FifoQueue.isEmpty q)
    end
  end);

structure TestPriceKey = struct
  type ord_key = LargeInt.int
  val compare = LargeInt.compare
end;
structure TestPriceMap = RedBlackMapFn (TestPriceKey);

val _ = TestFramework.runSuite ("Core RedBlackMap Tests", fn () =>
  let
    val m = TestPriceMap.empty
    val m = TestPriceMap.insert (m, 100, "hundred")
    val m = TestPriceMap.insert (m, 50, "fifty")
    val m = TestPriceMap.insert (m, 200, "two hundred")
    val m = TestPriceMap.insert (m, 75, "seventy-five")
    val m = TestPriceMap.insert (m, 25, "twenty-five")
  in
    TestFramework.assertEqualInt ("Tree size 5", 5, TestPriceMap.numItems m);
    TestFramework.assertEqualLargeInt ("Min key", 25, valOf (TestPriceMap.minKey m));
    TestFramework.assertEqualLargeInt ("Max key", 200, valOf (TestPriceMap.maxKey m));
    TestFramework.assertEqualString ("Find 75", "seventy-five", valOf (TestPriceMap.find (m, 75)));
    let
      val (m', removed) = TestPriceMap.remove (m, 50)
    in
      TestFramework.assertEqualInt ("Size after remove", 4, TestPriceMap.numItems m');
      TestFramework.assertEqualString ("Removed item", "fifty", removed);
      TestFramework.assert ("50 not in domain", not (TestPriceMap.inDomain (m', 50)));
      TestFramework.assert ("75 still in domain", TestPriceMap.inDomain (m', 75))
    end
  end);

val _ = TestFramework.runSuite ("Core ByteBuffer Tests", fn () =>
  let
    val b1 = ByteBuffer.fromString "HELLO"
    val b2 = ByteBuffer.fromString " WORLD"
    val b3 = ByteBuffer.append b1 b2
    val hex = ByteBuffer.toHex b1
    val parsed = valOf (ByteBuffer.fromHex hex)
  in
    TestFramework.assertEqualInt ("Buffer length", 11, ByteBuffer.length b3);
    TestFramework.assertEqualString ("Buffer toString", "HELLO WORLD", ByteBuffer.toString b3);
    TestFramework.assertEqualString ("Hex roundtrip", "HELLO", ByteBuffer.toString parsed)
  end);

val _ = TestFramework.runSuite ("Core RingBuffer Tests", fn () =>
  let
    val rb = RingBuffer.create 3
  in
    TestFramework.assert ("Initially empty", RingBuffer.isEmpty rb);
    RingBuffer.push rb 1;
    RingBuffer.push rb 2;
    RingBuffer.push rb 3;
    TestFramework.assert ("Full at 3 items", RingBuffer.isFull rb);
    TestFramework.assertEqualInt ("Latest item 3", 3, valOf (RingBuffer.latest rb));
    RingBuffer.push rb 4;
    TestFramework.assertEqualInt ("Latest item 4 after overwrite", 4, valOf (RingBuffer.latest rb));
    TestFramework.assertEqualInt ("Ring buffer size still 3", 3, RingBuffer.size rb)
  end);

val _ = TestFramework.reportSummary ();
