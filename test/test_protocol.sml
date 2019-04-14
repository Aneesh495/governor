(* test_protocol.sml
 * Comprehensive test cases for binary protocol, FIX tag-value, and JSON serialization.
 *)

val _ = use "test/test_framework.sig";
val _ = use "test/test_framework.sml";
val _ = use "src/core/result.sig";
val _ = use "src/core/result.sml";
val _ = use "src/core/types.sig";
val _ = use "src/core/types.sml";
val _ = use "src/core/word_util.sig";
val _ = use "src/core/word_util.sml";
val _ = use "src/core/byte_buffer.sig";
val _ = use "src/core/byte_buffer.sml";
val _ = use "src/protocol/binary_codec.sig";
val _ = use "src/protocol/binary_codec.sml";
val _ = use "src/protocol/fix_message.sig";
val _ = use "src/protocol/fix_message.sml";
val _ = use "src/protocol/json_codec.sig";
val _ = use "src/protocol/json_codec.sml";

val _ = TestFramework.runSuite ("Binary Codec Serialization Tests", fn () =>
  let
    val p = valOf (Types.priceFromString "175.50")
    val inOrder : BinaryCodec.binary_new_order = {
      seq = 42,
      timestamp = 1700000000000,
      client_id = "QUANT_FIRM",
      symbol = "NVDA",
      order_id = 9999,
      side = Types.Buy,
      order_type = Types.Limit { price = p },
      time_in_force = Types.GTC,
      price = p,
      qty = 500
    }

    val encoded = BinaryCodec.encodeNewOrder inOrder
    val decodedRes = BinaryCodec.decodeNewOrder encoded
  in
    TestFramework.assert ("Decode success", Result.isOk decodedRes);
    let
      val decoded = Result.unwrap decodedRes
    in
      TestFramework.assertEqualLargeInt ("Decoded seq matches 42", 42, #seq decoded);
      TestFramework.assertEqualString ("Decoded client_id matches", "QUANT_FIRM", #client_id decoded);
      TestFramework.assertEqualString ("Decoded symbol matches", "NVDA", #symbol decoded);
      TestFramework.assertEqualLargeInt ("Decoded order_id matches", 9999, #order_id decoded);
      TestFramework.assertEqualLargeInt ("Decoded price matches", p, #price decoded);
      TestFramework.assertEqualLargeInt ("Decoded qty matches 500", 500, #qty decoded);
      TestFramework.assert ("Decoded side is Buy", #side decoded = Types.Buy)
    end
  end);

val _ = TestFramework.runSuite ("FIX Message Parsing & Checksum Tests", fn () =>
  let
    val msg = FixMessage.create "D" "CLIENT1" "EXCHANGE" 1 "20261118-12:00:00.000" [
      (11, "ORD1001"),
      (55, "AAPL"),
      (54, "1"),      (* Buy *)
      (38, "100"),    (* 100 shares *)
      (40, "2"),      (* Limit *)
      (44, "150.25")
    ]

    val serialized = FixMessage.serialize msg #"|"
    val parsedRes = FixMessage.parse serialized #"|"
  in
    TestFramework.assert ("FIX parse success", Result.isOk parsedRes);
    let
      val parsed = Result.unwrap parsedRes
    in
      TestFramework.assertEqualString ("MsgType is D", "D", #msg_type parsed);
      TestFramework.assertEqualString ("Sender is CLIENT1", "CLIENT1", #sender_comp_id parsed);
      TestFramework.assertEqualString ("Target is EXCHANGE", "EXCHANGE", #target_comp_id parsed);
      TestFramework.assertEqualString ("Symbol is AAPL", "AAPL", valOf (FixMessage.getField parsed 55));
      TestFramework.assertEqualString ("Price is 150.25", "150.25", valOf (FixMessage.getField parsed 44))
    end
  end);

val _ = TestFramework.runSuite ("JSON Codec Roundtrip Tests", fn () =>
  let
    val jsonAst = JsonCodec.JObject [
      ("symbol", JsonCodec.JString "GOOGL"),
      ("price", JsonCodec.JString "180.50"),
      ("qty", JsonCodec.JInt 100),
      ("active", JsonCodec.JBool true),
      ("tags", JsonCodec.JArray [JsonCodec.JString "tech", JsonCodec.JString "large-cap"])
    ]

    val str = JsonCodec.stringify jsonAst
    val parsedRes = JsonCodec.parse str
  in
    TestFramework.assert ("JSON parse success", Result.isOk parsedRes);
    let
      val parsed = Result.unwrap parsedRes
    in
      TestFramework.assertEqualString ("Parsed symbol is GOOGL", "GOOGL", valOf (JsonCodec.getStringField parsed "symbol"));
      TestFramework.assertEqualLargeInt ("Parsed qty is 100", 100, valOf (JsonCodec.getIntField parsed "qty"));
      TestFramework.assert ("Parsed active is true", valOf (JsonCodec.getBoolField parsed "active"))
    end
  end);

val _ = TestFramework.reportSummary ();
