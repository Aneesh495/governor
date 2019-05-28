(* stop_order_manager.sml
 * Implementation of Stop-Loss and Stop-Limit trigger queue.
 *)

structure StopOrderManager :> STOP_ORDER_MANAGER =
struct
  structure OrderIdKey = struct
    type ord_key = Types.order_id
    val compare = LargeInt.compare
  end

  structure StopMap = RedBlackMapFn (OrderIdKey)

  type manager = {
    pending_stops : Order.order StopMap.map
  }

  fun create () : manager =
      { pending_stops = StopMap.empty }

  fun addStopOrder (mgr : manager) (ord : Order.order) : manager =
      { pending_stops = StopMap.insert (#pending_stops mgr, #id ord, ord) }

  fun cancelStopOrder (mgr : manager) (targetId : Types.order_id) : (Order.order * manager) option =
      case StopMap.find (#pending_stops mgr, targetId) of
          NONE => NONE
        | SOME ord =>
            let
              val (newMap, _) = StopMap.remove (#pending_stops mgr, targetId)
            in
              SOME (ord, { pending_stops = newMap })
            end

  fun shouldTrigger (ord : Order.order) (tradeP : Types.price) : bool =
      let
        val side = #side ord
      in
        case #order_type ord of
            Types.StopLoss { stop_price } =>
              (case side of
                   Types.Buy => tradeP >= stop_price   (* Buy Stop triggers on breakout *)
                 | Types.Sell => tradeP <= stop_price) (* Sell Stop triggers on breakdown *)
          | Types.StopLimit { stop_price, ... } =>
              (case side of
                   Types.Buy => tradeP >= stop_price
                 | Types.Sell => tradeP <= stop_price)
          | _ => false
      end

  fun convertToActiveOrder (ord : Order.order) (ts : Types.timestamp_ns) : Order.order =
      let
        val (newType, newPrice) =
            case #order_type ord of
                Types.StopLoss _ => (Types.Market, 0)
              | Types.StopLimit { limit_price, ... } => (Types.Limit { price = limit_price }, limit_price)
              | other => (other, #price ord)
      in
        {
          id = #id ord,
          client_id = #client_id ord,
          symbol = #symbol ord,
          side = #side ord,
          order_type = newType,
          time_in_force = #time_in_force ord,
          price = newPrice,
          initial_qty = #initial_qty ord,
          leaves_qty = #leaves_qty ord,
          cum_qty = #cum_qty ord,
          peak_qty = #peak_qty ord,
          hidden_qty = #hidden_qty ord,
          status = Types.Accepted,
          created_at = #created_at ord,
          updated_at = ts
        }
      end

  fun evaluateTick (mgr : manager) (sym : Types.symbol_id) (tradeP : Types.price) (ts : Types.timestamp_ns) =
      let
        val allStops = StopMap.listItems (#pending_stops mgr)
        fun splitTriggered ([], kept, triggered) = (kept, triggered)
          | splitTriggered (ord :: rest, kept, triggered) =
              if #symbol ord = sym andalso shouldTrigger ord tradeP then
                splitTriggered (rest, kept, convertToActiveOrder ord ts :: triggered)
              else
                splitTriggered (rest, ord :: kept, triggered)

        val (keptOrders, triggeredOrders) = splitTriggered (allStops, [], [])
        val newMap = List.foldl (fn (o : Order.order, m) => StopMap.insert (m, #id o, o)) StopMap.empty keptOrders
      in
        ({ pending_stops = newMap }, List.rev triggeredOrders)
      end

  fun pendingCount (mgr : manager) = StopMap.numItems (#pending_stops mgr)
end
