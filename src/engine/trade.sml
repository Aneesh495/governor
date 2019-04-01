(* trade.sml
 * Implementation of Trade execution record.
 *)

structure Trade :> TRADE =
struct
  type trade = {
    match_id : Types.match_id,
    symbol : Types.symbol_id,
    price : Types.price,
    qty : Types.qty,
    maker_order_id : Types.order_id,
    taker_order_id : Types.order_id,
    maker_client_id : Types.client_id,
    taker_client_id : Types.client_id,
    aggressor_side : Types.side,
    timestamp : Types.timestamp_ns
  }

  fun create params = params

  fun notionalValue ({ price, qty, ... } : trade) : LargeInt.int =
      (price * qty) div Types.priceScale

  fun toString (t : trade) : string =
      "Trade(match_id=" ^ LargeInt.toString (#match_id t) ^
      ",sym=" ^ #symbol t ^
      ",price=" ^ Types.priceToString (#price t) ^
      ",qty=" ^ LargeInt.toString (#qty t) ^
      ",maker=" ^ LargeInt.toString (#maker_order_id t) ^ "(" ^ #maker_client_id t ^ ")" ^
      ",taker=" ^ LargeInt.toString (#taker_order_id t) ^ "(" ^ #taker_client_id t ^ ")" ^
      ",side=" ^ Types.sideToString (#aggressor_side t) ^
      ",ts=" ^ LargeInt.toString (#timestamp t) ^ ")"
end
