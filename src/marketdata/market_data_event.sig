(* market_data_event.sig
 * Canonical market data events emitted by matching engine and order books.
 *)

signature MARKET_DATA_EVENT =
sig
  datatype event =
      OrderAdded of {
        seq : Types.sequence_num,
        symbol : Types.symbol_id,
        order_id : Types.order_id,
        side : Types.side,
        price : Types.price,
        qty : Types.qty,
        timestamp : Types.timestamp_ns
      }
    | OrderExecuted of {
        seq : Types.sequence_num,
        symbol : Types.symbol_id,
        match_id : Types.match_id,
        maker_order_id : Types.order_id,
        taker_order_id : Types.order_id,
        price : Types.price,
        qty : Types.qty,
        timestamp : Types.timestamp_ns
      }
    | OrderCancelled of {
        seq : Types.sequence_num,
        symbol : Types.symbol_id,
        order_id : Types.order_id,
        timestamp : Types.timestamp_ns
      }
    | BboUpdated of {
        seq : Types.sequence_num,
        symbol : Types.symbol_id,
        bid_price : Types.price option,
        bid_qty : Types.qty option,
        ask_price : Types.price option,
        ask_qty : Types.qty option,
        timestamp : Types.timestamp_ns
      }
    | CircuitBreakerTriggered of {
        seq : Types.sequence_num,
        symbol : Types.symbol_id,
        reason : string,
        timestamp : Types.timestamp_ns
      }

  val sequenceNumber : event -> Types.sequence_num
  val timestamp : event -> Types.timestamp_ns
  val symbol : event -> Types.symbol_id
  val toString : event -> string
end
