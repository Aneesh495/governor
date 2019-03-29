(* book_manager.sig
 * Multi-instrument order book registry managing isolated symbols.
 *)

signature BOOK_MANAGER =
sig
  type manager

  val create : unit -> manager
  val addSymbol : manager -> Types.symbol_id -> manager
  val hasSymbol : manager -> Types.symbol_id -> bool
  val listSymbols : manager -> Types.symbol_id list

  (* Book access and modification *)
  val getBook : manager -> Types.symbol_id -> OrderBook.book option
  val updateBook : manager -> OrderBook.book -> manager

  (* Global order routing *)
  val insertOrder : manager -> Order.order -> (manager, string) Result.result
  val cancelOrder : manager -> Types.symbol_id -> Types.order_id -> Types.timestamp_ns -> (Order.order * manager, string) Result.result
  val findOrder : manager -> Types.symbol_id -> Types.order_id -> Order.order option

  val totalVolumeAcrossSymbols : manager -> Types.qty
  val totalOrdersAcrossSymbols : manager -> int
end
