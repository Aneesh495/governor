(* test_sbe.sml
 * Unit tests for Simple Binary Encoding (SBE) fixed-offset wire protocol.
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
val _ = use "src/protocol/sbe_codec.sig";
val _ = use "src/protocol/sbe_codec.sml";

structure TestSbe =
struct
  val toPrice = fn d => d * Types.priceScale

  fun run () =
      TestFramework.runSuite ("Simple Binary Encoding (SBE) Wire Tests", fn () =>
        let
          val hdr : SbeCodec.sbe_header = {
            block_length = 0wx0028,
            template_id = SbeCodec.templateIdTrade,
            schema_id = SbeCodec.schemaIdGovernor,
            version = 0wx0001
          }

          val origEvent : SbeCodec.sbe_trade_event = {
            header = hdr,
            match_id = 987654321,
            order_id = 123456789,
            price = toPrice 150,
            qty = 500,
            timestamp = 1609459200000000000
          }

          (* 1. Encode event to SBE buffer *)
          val buf = SbeCodec.encodeTrade origEvent
          val _ = TestFramework.assertEqualInt ("Encoded SBE packet is exactly 48 bytes", 48, ByteBuffer.length buf)

          (* 2. Decode back and verify all fields *)
          val decRes = SbeCodec.decodeTrade buf
          val _ = TestFramework.assert ("Decode SBE succeeds", Result.isOk decRes)
          val decEvent = Result.unwrap decRes

          val _ = TestFramework.assertEqualLargeInt ("Match ID matches", 987654321, #match_id decEvent)
          val _ = TestFramework.assertEqualLargeInt ("Order ID matches", 123456789, #order_id decEvent)
          val _ = TestFramework.assertEqualLargeInt ("Price matches $150.00", toPrice 150, #price decEvent)
          val _ = TestFramework.assertEqualLargeInt ("Qty matches 500", 500, #qty decEvent)
          val _ = TestFramework.assertEqualLargeInt ("Timestamp matches", 1609459200000000000, #timestamp decEvent)

          val decHdr = #header decEvent
          val _ = TestFramework.assert ("Template ID is Trade (100)", #template_id decHdr = SbeCodec.templateIdTrade)
          val _ = TestFramework.assert ("Schema ID is Governor (1)", #schema_id decHdr = SbeCodec.schemaIdGovernor)

          (* 3. Buffer underflow check *)
          val truncatedBuf = ByteBuffer.fromBytes (List.take (ByteBuffer.toBytes buf, 30))
          val errRes = SbeCodec.decodeTrade truncatedBuf
          val _ = TestFramework.assert ("Truncated SBE packet underflow rejected with Err", Result.isErr errRes)
        in
          ()
        end
      )
end;

val _ = TestSbe.run ();
