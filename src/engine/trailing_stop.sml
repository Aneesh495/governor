(* trailing_stop.sml
 * Implementation of trailing stop manager.
 *)

structure TrailingStop :> TRAILING_STOP =
struct
  type order_id = Types.order_id
  type price = Types.price
  type qty = Types.qty
  type symbol_id = Types.symbol_id

  datatype trail_mode =
      FixedDistance of price
    | Percentage of real

  type trailing_order = {
    order : Order.order,
    mode : trail_mode,
    water_mark : price ref,
    current_stop : price ref
  }

  structure OrderIdKey = struct
    type ord_key = order_id
    val compare = LargeInt.compare
  end

  structure TrailMap = RedBlackMapFn (OrderIdKey)

  type manager = {
    orders : trailing_order TrailMap.map
  }

  fun create () : manager =
      { orders = TrailMap.empty }

  fun calculateStop (side : Types.side) (wm : price) (mode : trail_mode) : price =
      case mode of
          FixedDistance dist =>
            (case side of
                 Types.Sell => wm - dist
               | Types.Buy => wm + dist)
        | Percentage pct =>
            let
              val wmReal = Real.fromLargeInt (LargeInt.toLarge wm)
              val offsetReal = wmReal * (pct / 100.0)
              val offset = LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST offsetReal)
            in
              case side of
                  Types.Sell => wm - offset
                | Types.Buy => wm + offset
            end

  fun addTrailingStop (mgr : manager) (ord : Order.order) (mode : trail_mode) : manager =
      let
        val initPrice = #price ord
        val wm = ref initPrice
        val initStop = calculateStop (#side ord) initPrice mode
        val entry : trailing_order = {
          order = ord,
          mode = mode,
          water_mark = wm,
          current_stop = ref initStop
        }
      in
        { orders = TrailMap.insert (#orders mgr, #id ord, entry) }
      end

  fun cancelTrailingStop (mgr : manager) (id : order_id) : (trailing_order * manager) option =
      case TrailMap.find (#orders mgr, id) of
          NONE => NONE
        | SOME entry =>
            let
              val (newMap, _) = TrailMap.remove (#orders mgr, id)
            in
              SOME (entry, { orders = newMap })
            end

  fun getStopInfo (mgr : manager) (id : order_id) : (price * price) option =
      case TrailMap.find (#orders mgr, id) of
          NONE => NONE
        | SOME entry => SOME (! (#water_mark entry), ! (#current_stop entry))

  fun pendingCount (mgr : manager) : int =
      TrailMap.numItems (#orders mgr)

  fun convertToMarket (ord : Order.order) (ts : Types.timestamp_ns) : Order.order =
      {
        id = #id ord,
        client_id = #client_id ord,
        symbol = #symbol ord,
        side = #side ord,
        order_type = Types.Market,
        time_in_force = Types.IOC,
        price = 0,
        initial_qty = #initial_qty ord,
        leaves_qty = #leaves_qty ord,
        cum_qty = #cum_qty ord,
        peak_qty = #peak_qty ord,
        hidden_qty = #hidden_qty ord,
        status = Types.Accepted,
        created_at = #created_at ord,
        updated_at = ts
      }

  fun updatePrice (mgr : manager) (sym : symbol_id) (currentPrice : price) (ts : Types.timestamp_ns)
      : (manager * Order.order list) =
      let
        val allEntries = TrailMap.listItems (#orders mgr)

        fun process ([], kept, triggered) = (kept, triggered)
          | process (entry :: rest, kept, triggered) =
              let
                val ord = #order entry
              in
                if #symbol ord <> sym then
                  process (rest, entry :: kept, triggered)
                else
                  let
                    val side = #side ord
                    val wmRef = #water_mark entry
                    val stopRef = #current_stop entry
                    val mode = #mode entry
                  in
                    case side of
                        Types.Sell =>
                          if currentPrice > !wmRef then
                            (* New high water mark: ratchets stop upwards *)
                            (wmRef := currentPrice;
                             stopRef := calculateStop Types.Sell currentPrice mode;
                             process (rest, entry :: kept, triggered))
                          else if currentPrice <= !stopRef then
                            (* Triggered stop loss *)
                            process (rest, kept, convertToMarket ord ts :: triggered)
                          else
                            process (rest, entry :: kept, triggered)
                      | Types.Buy =>
                          if currentPrice < !wmRef then
                            (* New low water mark: drags buy stop downwards *)
                            (wmRef := currentPrice;
                             stopRef := calculateStop Types.Buy currentPrice mode;
                             process (rest, entry :: kept, triggered))
                          else if currentPrice >= !stopRef then
                            (* Triggered buy stop *)
                            process (rest, kept, convertToMarket ord ts :: triggered)
                          else
                            process (rest, entry :: kept, triggered)
                  end
              end

        val (keptEntries, triggeredOrders) = process (allEntries, [], [])
        val newMap = List.foldl (fn (entry : trailing_order, m) =>
                                   TrailMap.insert (m, #id (#order entry), entry))
                                TrailMap.empty keptEntries
      in
        ({ orders = newMap }, List.rev triggeredOrders)
      end
end
