(* market_data_event.sml
 * Implementation of market data events and formatting.
 *)

structure MarketDataEvent :> MARKET_DATA_EVENT =
struct
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

  fun sequenceNumber (OrderAdded { seq, ... }) = seq
    | sequenceNumber (OrderExecuted { seq, ... }) = seq
    | sequenceNumber (OrderCancelled { seq, ... }) = seq
    | sequenceNumber (BboUpdated { seq, ... }) = seq
    | sequenceNumber (CircuitBreakerTriggered { seq, ... }) = seq

  fun timestamp (OrderAdded { timestamp = ts, ... }) = ts
    | timestamp (OrderExecuted { timestamp = ts, ... }) = ts
    | timestamp (OrderCancelled { timestamp = ts, ... }) = ts
    | timestamp (BboUpdated { timestamp = ts, ... }) = ts
    | timestamp (CircuitBreakerTriggered { timestamp = ts, ... }) = ts

  fun symbol (OrderAdded { symbol = s, ... }) = s
    | symbol (OrderExecuted { symbol = s, ... }) = s
    | symbol (OrderCancelled { symbol = s, ... }) = s
    | symbol (BboUpdated { symbol = s, ... }) = s
    | symbol (CircuitBreakerTriggered { symbol = s, ... }) = s

  fun toString (OrderAdded { seq, symbol, order_id, side, price, qty, timestamp }) =
      "ADD#" ^ LargeInt.toString seq ^ "[" ^ symbol ^ "]: id=" ^ LargeInt.toString order_id ^
      " " ^ Types.sideToString side ^ " " ^ LargeInt.toString qty ^ "@" ^ Types.priceToString price
    | toString (OrderExecuted { seq, symbol, match_id, maker_order_id, taker_order_id, price, qty, timestamp }) =
      "EXEC#" ^ LargeInt.toString seq ^ "[" ^ symbol ^ "]: match=" ^ LargeInt.toString match_id ^
      " " ^ LargeInt.toString qty ^ "@" ^ Types.priceToString price ^
      " (maker=" ^ LargeInt.toString maker_order_id ^ ",taker=" ^ LargeInt.toString taker_order_id ^ ")"
    | toString (OrderCancelled { seq, symbol, order_id, timestamp }) =
      "CANCEL#" ^ LargeInt.toString seq ^ "[" ^ symbol ^ "]: id=" ^ LargeInt.toString order_id
    | toString (BboUpdated { seq, symbol, bid_price, bid_qty, ask_price, ask_qty, timestamp }) =
      let
        val bStr = case (bid_price, bid_qty) of (SOME p, SOME q) => Types.priceToString p ^ "@" ^ LargeInt.toString q | _ => "NONE"
        val aStr = case (ask_price, ask_qty) of (SOME p, SOME q) => Types.priceToString p ^ "@" ^ LargeInt.toString q | _ => "NONE"
      in
        "BBO#" ^ LargeInt.toString seq ^ "[" ^ symbol ^ "]: " ^ bStr ^ " / " ^ aStr
      end
    | toString (CircuitBreakerTriggered { seq, symbol, reason, timestamp }) =
      "HALT#" ^ LargeInt.toString seq ^ "[" ^ symbol ^ "]: " ^ reason
end
