(* sbe_codec.sig
 * Simple Binary Encoding (SBE) fixed-offset high-throughput wire protocol codec.
 *)

signature SBE_CODEC =
sig
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

  val templateIdTrade : Word32.word
  val schemaIdGovernor : Word32.word

  val encodeTrade : sbe_trade_event -> ByteBuffer.buffer
  val decodeTrade : ByteBuffer.buffer -> (sbe_trade_event, string) Result.result
end
