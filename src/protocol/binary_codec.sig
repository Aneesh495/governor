(* binary_codec.sig
 * High-speed binary framing and serialization for order entry and market reports.
 *)

signature BINARY_CODEC =
sig
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

  val encodeNewOrder : binary_new_order -> ByteBuffer.buffer
  val decodeNewOrder : ByteBuffer.buffer -> (binary_new_order, string) Result.result

  val encodeExecutionReport : binary_execution_report -> ByteBuffer.buffer
  val decodeExecutionReport : ByteBuffer.buffer -> (binary_execution_report, string) Result.result
end
