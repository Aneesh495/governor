(* trader_state.sml
 * Implementation of TraderState accounting and sliding rate limiter.
 *)

structure TraderState :> TRADER_STATE =
struct
  structure SymbolKey = struct
    type ord_key = Types.symbol_id
    val compare = String.compare
  end

  structure PositionMap = RedBlackMapFn (SymbolKey)

  type state = {
    client_id : Types.client_id,
    cash_balance : LargeInt.int,
    realized_pnl : LargeInt.int,
    positions : Types.qty PositionMap.map,
    open_exposure : LargeInt.int,
    recent_messages : Types.timestamp_ns list
  }

  fun create (clientId : Types.client_id) (initialCash : LargeInt.int) : state =
      {
        client_id = clientId,
        cash_balance = initialCash,
        realized_pnl = 0,
        positions = PositionMap.empty,
        open_exposure = 0,
        recent_messages = []
      }

  fun clientId (s : state) = #client_id s
  fun cashBalance (s : state) = #cash_balance s
  fun realizedPnL (s : state) = #realized_pnl s
  fun openExposure (s : state) = #open_exposure s

  fun getPosition (s : state) (sym : Types.symbol_id) : Types.qty =
      case PositionMap.find (#positions s, sym) of
          SOME q => q
        | NONE => 0

  fun updatePositionOnTrade (s : state) (sym : Types.symbol_id) (side : Types.side) (q : Types.qty) (p : Types.price) : state =
      let
        val curPos = getPosition s sym
        val tradeNotional = (p * q) div Types.priceScale
        val (newPos, newCash) =
            case side of
                Types.Buy => (curPos + q, #cash_balance s - tradeNotional)
              | Types.Sell => (curPos - q, #cash_balance s + tradeNotional)
        val newPositions = PositionMap.insert (#positions s, sym, newPos)
      in
        {
          client_id = #client_id s,
          cash_balance = newCash,
          realized_pnl = #realized_pnl s,
          positions = newPositions,
          open_exposure = #open_exposure s,
          recent_messages = #recent_messages s
        }
      end

  fun addOpenExposure (s : state) (exp : LargeInt.int) : state =
      {
        client_id = #client_id s,
        cash_balance = #cash_balance s,
        realized_pnl = #realized_pnl s,
        positions = #positions s,
        open_exposure = #open_exposure s + exp,
        recent_messages = #recent_messages s
      }

  fun removeOpenExposure (s : state) (exp : LargeInt.int) : state =
      let
        val curExp = #open_exposure s
        val newExp = if curExp >= exp then curExp - exp else 0
      in
        {
          client_id = #client_id s,
          cash_balance = #cash_balance s,
          realized_pnl = #realized_pnl s,
          positions = #positions s,
          open_exposure = newExp,
          recent_messages = #recent_messages s
        }
      end

  fun recordMessage (s : state) (ts : Types.timestamp_ns) : state =
      let
        val cutoff = ts - 1000000000 (* 1 second *)
        val filtered = List.filter (fn t => t >= cutoff) (#recent_messages s)
      in
        {
          client_id = #client_id s,
          cash_balance = #cash_balance s,
          realized_pnl = #realized_pnl s,
          positions = #positions s,
          open_exposure = #open_exposure s,
          recent_messages = ts :: filtered
        }
      end

  fun messageRateInLastSecond (s : state) (ts : Types.timestamp_ns) : int =
      let
        val cutoff = ts - 1000000000
        val count = List.length (List.filter (fn t => t >= cutoff) (#recent_messages s))
      in
        count
      end
end
