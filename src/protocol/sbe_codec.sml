(* sbe_codec.sml
 * Implementation of Simple Binary Encoding (SBE) serializer.
 *)

structure SbeCodec :> SBE_CODEC =
struct
  type sbe_header = {
    block_length : Word32.word,
    template_id : Word32.word,
    schema_id : Word32.word,
    version : Word32.word
  }

  type sbe_trade_event = {
    header : sbe_header,
    match_id : Types.match_id,
    order_id : Types.order_id,
    price : Types.price,
    qty : Types.qty,
    timestamp : Types.timestamp_ns
  }

  val templateIdTrade : Word32.word = 0wx0064 (* 100 *)
  val schemaIdGovernor : Word32.word = 0wx0001
  val sbeVersion : Word32.word = 0wx0001
  val tradeBlockLength : Word32.word = 0wx0028 (* 40 bytes body *)

  fun encodeTrade ({ header, match_id, order_id, price, qty, timestamp } : sbe_trade_event) : ByteBuffer.buffer =
      let
        val hBlock = WordUtil.packU16BE (#block_length header)
        val hTmpl = WordUtil.packU16BE (#template_id header)
        val hSchema = WordUtil.packU16BE (#schema_id header)
        val hVer = WordUtil.packU16BE (#version header)

        val matchBytes = WordUtil.packU64BE (Word64.fromLargeInt match_id)
        val ordBytes = WordUtil.packU64BE (Word64.fromLargeInt order_id)
        val pBytes = WordUtil.packU64BE (Word64.fromLargeInt price)
        val qBytes = WordUtil.packU64BE (Word64.fromLargeInt qty)
        val tsBytes = WordUtil.packU64BE (Word64.fromLargeInt timestamp)

        val allBytes = hBlock @ hTmpl @ hSchema @ hVer @
                       matchBytes @ ordBytes @ pBytes @ qBytes @ tsBytes
      in
        ByteBuffer.fromBytes allBytes
      end

  fun decodeTrade (buf : ByteBuffer.buffer) : (sbe_trade_event, string) Result.result =
      let
        val bytes = ByteBuffer.toBytes buf
      in
        if List.length bytes < 48 then
          Result.err "SBE buffer underflow: minimum 48 bytes required"
        else
          let
            val (blockW, rest) = WordUtil.unpackU16BE bytes
            val (tmplW, rest) = WordUtil.unpackU16BE rest
            val (schemaW, rest) = WordUtil.unpackU16BE rest
            val (verW, rest) = WordUtil.unpackU16BE rest

            val (matchW, rest) = WordUtil.unpackU64BE rest
            val (ordW, rest) = WordUtil.unpackU64BE rest
            val (priceW, rest) = WordUtil.unpackU64BE rest
            val (qtyW, rest) = WordUtil.unpackU64BE rest
            val (tsW, _) = WordUtil.unpackU64BE rest

            val hdr : sbe_header = {
              block_length = blockW,
              template_id = tmplW,
              schema_id = schemaW,
              version = verW
            }
          in
            Result.ok {
              header = hdr,
              match_id = Word64.toLargeInt matchW,
              order_id = Word64.toLargeInt ordW,
              price = Word64.toLargeInt priceW,
              qty = Word64.toLargeInt qtyW,
              timestamp = Word64.toLargeInt tsW
            }
          end
      end
end
