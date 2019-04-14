(* binary_codec.sml
 * Implementation of binary protocol encoding and decoding.
 *)

structure BinaryCodec :> BINARY_CODEC =
struct
  datatype msg_type =
      MsgNewOrder
    | MsgCancelOrder
    | MsgExecutionReport
    | MsgReject

  type binary_new_order = {
    seq : Types.sequence_num,
    timestamp : Types.timestamp_ns,
    client_id : Types.client_id,
    symbol : Types.symbol_id,
    order_id : Types.order_id,
    side : Types.side,
    order_type : Types.order_type,
    time_in_force : Types.time_in_force,
    price : Types.price,
    qty : Types.qty
  }

  type binary_execution_report = {
    seq : Types.sequence_num,
    timestamp : Types.timestamp_ns,
    client_id : Types.client_id,
    symbol : Types.symbol_id,
    order_id : Types.order_id,
    match_id : Types.match_id,
    status : Types.order_status,
    price : Types.price,
    qty : Types.qty,
    leaves_qty : Types.qty,
    cum_qty : Types.qty
  }

  val magicByte : Word8.word = 0wx47 (* 'G' *)

  fun padString (s : string) (len : int) : Word8.word list =
      let
        val raw = Byte.stringToBytes s
        val sz = Word8Vector.length raw
      in
        if sz >= len then
          Word8Vector.foldr (fn (b, acc) => b :: acc) [] (Word8VectorSlice.vector (Word8VectorSlice.slice (raw, 0, SOME len)))
        else
          let
            val padLen = len - sz
            val pad = List.tabulate (padLen, fn _ => 0wx00 : Word8.word)
            val bytes = Word8Vector.foldr (fn (b, acc) => b :: acc) [] raw
          in
            bytes @ pad
          end
      end

  fun unpadString (bs : Word8.word list) : string =
      let
        val nonZero = List.filter (fn b => b <> 0wx00) bs
      in
        Byte.bytesToString (Word8Vector.fromList nonZero)
      end

  fun encodeNewOrder ({ seq, timestamp, client_id, symbol, order_id, side, order_type, time_in_force, price, qty } : binary_new_order) : ByteBuffer.buffer =
      let
        val msgTypeByte : Word8.word = 0wx01
        val sideByte : Word8.word = case side of Types.Buy => 0wx01 | Types.Sell => 0wx02
        val ordTypeByte : Word8.word = case order_type of Types.Market => 0wx01 | _ => 0wx02
        val tifByte : Word8.word = case time_in_force of
                                       Types.GTC => 0wx01
                                     | Types.IOC => 0wx02
                                     | Types.FOK => 0wx03
                                     | _ => 0wx04

        val seqBytes = WordUtil.packU64BE (Word64.fromLargeInt seq)
        val tsBytes = WordUtil.packU64BE (Word64.fromLargeInt timestamp)
        val ordIdBytes = WordUtil.packU64BE (Word64.fromLargeInt order_id)
        val priceBytes = WordUtil.packU64BE (Word64.fromLargeInt price)
        val qtyBytes = WordUtil.packU64BE (Word64.fromLargeInt qty)

        val clientBytes = padString client_id 16
        val symBytes = padString symbol 8

        val allBytes = [magicByte, msgTypeByte] @
                       seqBytes @ tsBytes @ clientBytes @ symBytes @
                       ordIdBytes @ [sideByte, ordTypeByte, tifByte] @
                       priceBytes @ qtyBytes
      in
        ByteBuffer.fromBytes allBytes
      end

  fun decodeNewOrder (buf : ByteBuffer.buffer) : (binary_new_order, string) Result.result =
      let
        val bytes = ByteBuffer.toBytes buf
      in
        if List.length bytes < 69 then
          Result.err "Buffer underflow: message too short for BinaryNewOrder"
        else
          let
            val magic = List.nth (bytes, 0)
            val msgType = List.nth (bytes, 1)
          in
            if magic <> magicByte then
              Result.err "Invalid magic byte in binary frame"
            else if msgType <> 0wx01 then
              Result.err "Expected MsgNewOrder (0x01)"
            else
              let
                val rest = List.drop (bytes, 2)
                val (seqW, rest) = WordUtil.unpackU64BE rest
                val (tsW, rest) = WordUtil.unpackU64BE rest
                val clientBs = List.take (rest, 16)
                val rest = List.drop (rest, 16)
                val symBs = List.take (rest, 8)
                val rest = List.drop (rest, 8)
                val (ordIdW, rest) = WordUtil.unpackU64BE rest
                val sideByte = hd rest
                val rest = tl rest
                val ordTypeByte = hd rest
                val rest = tl rest
                val tifByte = hd rest
                val rest = tl rest
                val (priceW, rest) = WordUtil.unpackU64BE rest
                val (qtyW, _) = WordUtil.unpackU64BE rest

                val side = if sideByte = 0wx01 then Types.Buy else Types.Sell
                val p = Word64.toLargeInt priceW
                val ordType = if ordTypeByte = 0wx01 then Types.Market else Types.Limit { price = p }
                val tif = case tifByte of
                              0wx01 => Types.GTC
                            | 0wx02 => Types.IOC
                            | 0wx03 => Types.FOK
                            | _ => Types.Day
              in
                Result.ok {
                  seq = Word64.toLargeInt seqW,
                  timestamp = Word64.toLargeInt tsW,
                  client_id = unpadString clientBs,
                  symbol = unpadString symBs,
                  order_id = Word64.toLargeInt ordIdW,
                  side = side,
                  order_type = ordType,
                  time_in_force = tif,
                  price = p,
                  qty = Word64.toLargeInt qtyW
                }
              end
          end
      end

  fun encodeExecutionReport ({ seq, timestamp, client_id, symbol, order_id, match_id, status, price, qty, leaves_qty, cum_qty } : binary_execution_report) : ByteBuffer.buffer =
      let
        val msgTypeByte : Word8.word = 0wx03
        val statusByte : Word8.word = case status of
                                          Types.Accepted => 0wx01
                                        | Types.PartiallyFilled => 0wx02
                                        | Types.Filled => 0wx03
                                        | Types.Cancelled => 0wx04
                                        | _ => 0wx05

        val seqBytes = WordUtil.packU64BE (Word64.fromLargeInt seq)
        val tsBytes = WordUtil.packU64BE (Word64.fromLargeInt timestamp)
        val clientBytes = padString client_id 16
        val symBytes = padString symbol 8
        val ordIdBytes = WordUtil.packU64BE (Word64.fromLargeInt order_id)
        val matchIdBytes = WordUtil.packU64BE (Word64.fromLargeInt match_id)
        val priceBytes = WordUtil.packU64BE (Word64.fromLargeInt price)
        val qtyBytes = WordUtil.packU64BE (Word64.fromLargeInt qty)
        val leavesBytes = WordUtil.packU64BE (Word64.fromLargeInt leaves_qty)
        val cumBytes = WordUtil.packU64BE (Word64.fromLargeInt cum_qty)

        val allBytes = [magicByte, msgTypeByte] @
                       seqBytes @ tsBytes @ clientBytes @ symBytes @
                       ordIdBytes @ matchIdBytes @ [statusByte] @
                       priceBytes @ qtyBytes @ leavesBytes @ cumBytes
      in
        ByteBuffer.fromBytes allBytes
      end

  fun decodeExecutionReport (buf : ByteBuffer.buffer) : (binary_execution_report, string) Result.result =
      let
        val bytes = ByteBuffer.toBytes buf
      in
        if List.length bytes < 83 then
          Result.err "Buffer underflow: message too short for BinaryExecutionReport"
        else
          let
            val magic = List.nth (bytes, 0)
            val msgType = List.nth (bytes, 1)
          in
            if magic <> magicByte then
              Result.err "Invalid magic byte in binary frame"
            else if msgType <> 0wx03 then
              Result.err "Expected MsgExecutionReport (0x03)"
            else
              let
                val rest = List.drop (bytes, 2)
                val (seqW, rest) = WordUtil.unpackU64BE rest
                val (tsW, rest) = WordUtil.unpackU64BE rest
                val clientBs = List.take (rest, 16)
                val rest = List.drop (rest, 16)
                val symBs = List.take (rest, 8)
                val rest = List.drop (rest, 8)
                val (ordIdW, rest) = WordUtil.unpackU64BE rest
                val (matchIdW, rest) = WordUtil.unpackU64BE rest
                val statusByte = hd rest
                val rest = tl rest
                val (priceW, rest) = WordUtil.unpackU64BE rest
                val (qtyW, rest) = WordUtil.unpackU64BE rest
                val (leavesW, rest) = WordUtil.unpackU64BE rest
                val (cumW, _) = WordUtil.unpackU64BE rest

                val status = case statusByte of
                                 0wx01 => Types.Accepted
                               | 0wx02 => Types.PartiallyFilled
                               | 0wx03 => Types.Filled
                               | 0wx04 => Types.Cancelled
                               | _ => Types.Rejected "Unknown"
              in
                Result.ok {
                  seq = Word64.toLargeInt seqW,
                  timestamp = Word64.toLargeInt tsW,
                  client_id = unpadString clientBs,
                  symbol = unpadString symBs,
                  order_id = Word64.toLargeInt ordIdW,
                  match_id = Word64.toLargeInt matchIdW,
                  status = status,
                  price = Word64.toLargeInt priceW,
                  qty = Word64.toLargeInt qtyW,
                  leaves_qty = Word64.toLargeInt leavesW,
                  cum_qty = Word64.toLargeInt cumW
                }
              end
          end
      end
end
