(* book_manager.sml
 * Implementation of multi-instrument BookManager.
 *)

structure BookManager :> BOOK_MANAGER =
struct
  structure SymbolKey = struct
    type ord_key = Types.symbol_id
    val compare = String.compare
  end

  structure SymbolMap = RedBlackMapFn (SymbolKey)

  type manager = {
    books : OrderBook.book SymbolMap.map
  }

  fun create () : manager =
      { books = SymbolMap.empty }

  fun addSymbol (mgr : manager) (sym : Types.symbol_id) : manager =
      if SymbolMap.inDomain (#books mgr, sym) then mgr
      else
        { books = SymbolMap.insert (#books mgr, sym, OrderBook.create sym) }

  fun hasSymbol (mgr : manager) (sym : Types.symbol_id) : bool =
      SymbolMap.inDomain (#books mgr, sym)

  fun listSymbols (mgr : manager) : Types.symbol_id list =
      SymbolMap.listKeys (#books mgr)

  fun getBook (mgr : manager) (sym : Types.symbol_id) : OrderBook.book option =
      SymbolMap.find (#books mgr, sym)

  fun updateBook (mgr : manager) (b : OrderBook.book) : manager =
      { books = SymbolMap.insert (#books mgr, OrderBook.symbol b, b) }

  fun insertOrder (mgr : manager) (ord : Order.order) : (manager, string) Result.result =
      let
        val sym = #symbol ord
      in
        case getBook mgr sym of
            NONE => Result.err ("Symbol " ^ sym ^ " not registered in BookManager")
          | SOME b =>
              let
                val updatedBook = OrderBook.insertOrder b ord
              in
                Result.ok (updateBook mgr updatedBook)
              end
      end

  fun cancelOrder (mgr : manager) (sym : Types.symbol_id) (targetId : Types.order_id) (ts : Types.timestamp_ns)
      : (Order.order * manager, string) Result.result =
      case getBook mgr sym of
          NONE => Result.err ("Symbol " ^ sym ^ " not registered")
        | SOME b =>
            case OrderBook.cancelOrder b targetId ts of
                NONE => Result.err ("Order " ^ LargeInt.toString targetId ^ " not found in book " ^ sym)
              | SOME (cancelledOrd, updatedBook) =>
                  Result.ok (cancelledOrd, updateBook mgr updatedBook)

  fun findOrder (mgr : manager) (sym : Types.symbol_id) (targetId : Types.order_id) : Order.order option =
      case getBook mgr sym of
          NONE => NONE
        | SOME b => OrderBook.findOrder b targetId

  fun totalVolumeAcrossSymbols (mgr : manager) : Types.qty =
      SymbolMap.foldli (fn (_, b, acc) => OrderBook.totalVolume b + acc) 0 (#books mgr)

  fun totalOrdersAcrossSymbols (mgr : manager) : int =
      SymbolMap.foldli (fn (_, b, acc) => OrderBook.totalOrders b + acc) 0 (#books mgr)
end
