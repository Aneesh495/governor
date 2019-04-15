(* order_book.sig
 * Limit order book maintaining price-ordered trees of bids and asks.
 *)

signature ORDER_BOOK =
sig
  type book

  val create : Types.symbol_id -> book
  val symbol : book -> Types.symbol_id

  (* Top of Book (BBO) inspection *)
  val bestBid : book -> (Types.price * Types.qty) option
  val bestAsk : book -> (Types.price * Types.qty) option
  val spread : book -> Types.price option
  val midPrice : book -> Types.price option

  (* Book depth queries *)
  val bidDepth : book -> int
  val askDepth : book -> int
  val totalOrders : book -> int

  (* Top N levels for Market Data L2 *)
  val topBids : book -> int -> (Types.price * Types.qty * int) list
  val topAsks : book -> int -> (Types.price * Types.qty * int) list

  (* Direct order insertion, cancellation, and retrieval *)
  val insertOrder : book -> Order.order -> book
  val cancelOrder : book -> Types.order_id -> Types.timestamp_ns -> (Order.order * book) option
  val findOrder : book -> Types.order_id -> Order.order option

  (* Level extraction for matching *)
  val getBestBidLevel : book -> PriceLevel.price_level option
  val getBestAskLevel : book -> PriceLevel.price_level option
  val updateBidLevel : book -> PriceLevel.price_level -> book
  val updateAskLevel : book -> PriceLevel.price_level -> book
  val removeBidLevel : book -> Types.price -> book
  val removeAskLevel : book -> Types.price -> book
  val removeOrderIndex : book -> Types.order_id -> book

  (* Trade recording *)
  val recordTrade : book -> Types.price -> Types.qty -> Types.timestamp_ns -> book
  val lastTrade : book -> (Types.price * Types.qty) option
  val totalVolume : book -> Types.qty

  (* String and diagnostic rendering *)
  val toString : book -> string
  val formatLadder : book -> int -> string
end
