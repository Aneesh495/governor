(* order_book.sml
 * Implementation of Central Limit Order Book with dual Red-Black Trees.
 *)

structure OrderBook :> ORDER_BOOK =
struct
  structure PriceKey = struct
    type ord_key = Types.price
    val compare = LargeInt.compare
  end

  structure OrderIdKey = struct
    type ord_key = Types.order_id
    val compare = LargeInt.compare
  end

  structure PriceMap = RedBlackMapFn (PriceKey)
  structure OrderMap = RedBlackMapFn (OrderIdKey)

  type book = {
    symbol : Types.symbol_id,
    bids : PriceLevel.price_level PriceMap.map,
    asks : PriceLevel.price_level PriceMap.map,
    order_index : (Types.price * Types.side) OrderMap.map,
    last_trade_price : Types.price option,
    last_trade_qty : Types.qty option,
    total_volume : Types.qty,
    last_update_ts : Types.timestamp_ns
  }

  fun create (sym : Types.symbol_id) : book =
      {
        symbol = sym,
        bids = PriceMap.empty,
        asks = PriceMap.empty,
        order_index = OrderMap.empty,
        last_trade_price = NONE,
        last_trade_qty = NONE,
        total_volume = 0,
        last_update_ts = 0
      }

  fun symbol (b : book) = #symbol b

  fun bestBid (b : book) : (Types.price * Types.qty) option =
      case PriceMap.maxItem (#bids b) of
          NONE => NONE
        | SOME (p, lvl) => SOME (p, #total_qty lvl)

  fun bestAsk (b : book) : (Types.price * Types.qty) option =
      case PriceMap.minItem (#asks b) of
          NONE => NONE
        | SOME (p, lvl) => SOME (p, #total_qty lvl)

  fun spread (b : book) : Types.price option =
      case (bestAsk b, bestBid b) of
          (SOME (askP, _), SOME (bidP, _)) => SOME (askP - bidP)
        | _ => NONE

  fun midPrice (b : book) : Types.price option =
      case (bestAsk b, bestBid b) of
          (SOME (askP, _), SOME (bidP, _)) => SOME ((askP + bidP) div 2)
        | _ => NONE

  fun bidDepth (b : book) = PriceMap.numItems (#bids b)
  fun askDepth (b : book) = PriceMap.numItems (#asks b)
  fun totalOrders (b : book) = OrderMap.numItems (#order_index b)

  fun topBids (b : book) (n : int) : (Types.price * Types.qty * int) list =
      let
        val items = List.rev (PriceMap.listItemsi (#bids b))
        fun takeN ([], _) = []
          | takeN (_, 0) = []
          | takeN ((p, lvl) :: xs, k) =
              (p, #total_qty lvl, #order_count lvl) :: takeN (xs, k - 1)
      in
        takeN (items, n)
      end

  fun topAsks (b : book) (n : int) : (Types.price * Types.qty * int) list =
      let
        val items = PriceMap.listItemsi (#asks b)
        fun takeN ([], _) = []
          | takeN (_, 0) = []
          | takeN ((p, lvl) :: xs, k) =
              (p, #total_qty lvl, #order_count lvl) :: takeN (xs, k - 1)
      in
        takeN (items, n)
      end

  fun insertOrder (b : book) (ord : Order.order) : book =
      let
        val p = #price ord
        val side = #side ord
        val id = #id ord
        val newIndex = OrderMap.insert (#order_index b, id, (p, side))
      in
        case side of
            Types.Buy =>
              let
                val lvl = case PriceMap.find (#bids b, p) of
                              SOME l => l
                            | NONE => PriceLevel.create p
                val updatedLvl = PriceLevel.addOrder lvl ord
                val newBids = PriceMap.insert (#bids b, p, updatedLvl)
              in
                {
                  symbol = #symbol b,
                  bids = newBids,
                  asks = #asks b,
                  order_index = newIndex,
                  last_trade_price = #last_trade_price b,
                  last_trade_qty = #last_trade_qty b,
                  total_volume = #total_volume b,
                  last_update_ts = #updated_at ord
                }
              end
          | Types.Sell =>
              let
                val lvl = case PriceMap.find (#asks b, p) of
                              SOME l => l
                            | NONE => PriceLevel.create p
                val updatedLvl = PriceLevel.addOrder lvl ord
                val newAsks = PriceMap.insert (#asks b, p, updatedLvl)
              in
                {
                  symbol = #symbol b,
                  bids = #bids b,
                  asks = newAsks,
                  order_index = newIndex,
                  last_trade_price = #last_trade_price b,
                  last_trade_qty = #last_trade_qty b,
                  total_volume = #total_volume b,
                  last_update_ts = #updated_at ord
                }
              end
      end

  fun cancelOrder (b : book) (targetId : Types.order_id) (ts : Types.timestamp_ns)
      : (Order.order * book) option =
      case OrderMap.find (#order_index b, targetId) of
          NONE => NONE
        | SOME (p, side) =>
            let
              val (newIndex, _) = OrderMap.remove (#order_index b, targetId)
            in
              case side of
                  Types.Buy =>
                    (case PriceMap.find (#bids b, p) of
                         NONE => NONE
                       | SOME lvl =>
                           case PriceLevel.removeOrder lvl targetId of
                               NONE => NONE
                             | SOME (ord, updatedLvl) =>
                                 let
                                   val cancelledOrd = Order.cancel ord ts
                                   val newBids =
                                       if PriceLevel.isEmpty updatedLvl then
                                         PriceMap.delete (#bids b, p)
                                       else
                                         PriceMap.insert (#bids b, p, updatedLvl)
                                   val updatedBook = {
                                     symbol = #symbol b,
                                     bids = newBids,
                                     asks = #asks b,
                                     order_index = newIndex,
                                     last_trade_price = #last_trade_price b,
                                     last_trade_qty = #last_trade_qty b,
                                     total_volume = #total_volume b,
                                     last_update_ts = ts
                                   }
                                 in
                                   SOME (cancelledOrd, updatedBook)
                                 end)
                | Types.Sell =>
                    (case PriceMap.find (#asks b, p) of
                         NONE => NONE
                       | SOME lvl =>
                           case PriceLevel.removeOrder lvl targetId of
                               NONE => NONE
                             | SOME (ord, updatedLvl) =>
                                 let
                                   val cancelledOrd = Order.cancel ord ts
                                   val newAsks =
                                       if PriceLevel.isEmpty updatedLvl then
                                         PriceMap.delete (#asks b, p)
                                       else
                                         PriceMap.insert (#asks b, p, updatedLvl)
                                   val updatedBook = {
                                     symbol = #symbol b,
                                     bids = #bids b,
                                     asks = newAsks,
                                     order_index = newIndex,
                                     last_trade_price = #last_trade_price b,
                                     last_trade_qty = #last_trade_qty b,
                                     total_volume = #total_volume b,
                                     last_update_ts = ts
                                   }
                                 in
                                   SOME (cancelledOrd, updatedBook)
                                 end)
            end

  fun findOrder (b : book) (targetId : Types.order_id) : Order.order option =
      case OrderMap.find (#order_index b, targetId) of
          NONE => NONE
        | SOME (p, side) =>
            let
              val tree = case side of Types.Buy => #bids b | Types.Sell => #asks b
            in
              case PriceMap.find (tree, p) of
                  NONE => NONE
                | SOME lvl =>
                    List.find (fn (ord : Order.order) => #id ord = targetId) (PriceLevel.getOrders lvl)
            end

  fun getBestBidLevel (b : book) : PriceLevel.price_level option =
      case PriceMap.maxItem (#bids b) of
          SOME (_, lvl) => SOME lvl
        | NONE => NONE

  fun getBestAskLevel (b : book) : PriceLevel.price_level option =
      case PriceMap.minItem (#asks b) of
          SOME (_, lvl) => SOME lvl
        | NONE => NONE

  fun updateBidLevel (b : book) (lvl : PriceLevel.price_level) : book =
      let
        val p = #price lvl
        val newBids =
            if PriceLevel.isEmpty lvl then
              PriceMap.delete (#bids b, p)
            else
              PriceMap.insert (#bids b, p, lvl)
      in
        {
          symbol = #symbol b,
          bids = newBids,
          asks = #asks b,
          order_index = #order_index b,
          last_trade_price = #last_trade_price b,
          last_trade_qty = #last_trade_qty b,
          total_volume = #total_volume b,
          last_update_ts = #last_update_ts b
        }
      end

  fun updateAskLevel (b : book) (lvl : PriceLevel.price_level) : book =
      let
        val p = #price lvl
        val newAsks =
            if PriceLevel.isEmpty lvl then
              PriceMap.delete (#asks b, p)
            else
              PriceMap.insert (#asks b, p, lvl)
      in
        {
          symbol = #symbol b,
          bids = #bids b,
          asks = newAsks,
          order_index = #order_index b,
          last_trade_price = #last_trade_price b,
          last_trade_qty = #last_trade_qty b,
          total_volume = #total_volume b,
          last_update_ts = #last_update_ts b
        }
      end

  fun removeBidLevel (b : book) (p : Types.price) : book =
      {
        symbol = #symbol b,
        bids = PriceMap.delete (#bids b, p),
        asks = #asks b,
        order_index = #order_index b,
        last_trade_price = #last_trade_price b,
        last_trade_qty = #last_trade_qty b,
        total_volume = #total_volume b,
        last_update_ts = #last_update_ts b
      }

  fun removeAskLevel (b : book) (p : Types.price) : book =
      {
        symbol = #symbol b,
        bids = #bids b,
        asks = PriceMap.delete (#asks b, p),
        order_index = #order_index b,
        last_trade_price = #last_trade_price b,
        last_trade_qty = #last_trade_qty b,
        total_volume = #total_volume b,
        last_update_ts = #last_update_ts b
      }

  fun removeOrderIndex (b : book) (targetId : Types.order_id) : book =
      case OrderMap.find (#order_index b, targetId) of
          NONE => b
        | SOME _ =>
            let val (newIndex, _) = OrderMap.remove (#order_index b, targetId) in
              {
                symbol = #symbol b,
                bids = #bids b,
                asks = #asks b,
                order_index = newIndex,
                last_trade_price = #last_trade_price b,
                last_trade_qty = #last_trade_qty b,
                total_volume = #total_volume b,
                last_update_ts = #last_update_ts b
              }
            end

  fun recordTrade (b : book) (p : Types.price) (q : Types.qty) (ts : Types.timestamp_ns) : book =
      {
        symbol = #symbol b,
        bids = #bids b,
        asks = #asks b,
        order_index = #order_index b,
        last_trade_price = SOME p,
        last_trade_qty = SOME q,
        total_volume = #total_volume b + q,
        last_update_ts = ts
      }

  fun lastTrade (b : book) =
      case (#last_trade_price b, #last_trade_qty b) of
          (SOME p, SOME q) => SOME (p, q)
        | _ => NONE

  fun totalVolume (b : book) = #total_volume b

  fun toString (b : book) : string =
      let
        val bboBid = case bestBid b of SOME (p, q) => Types.priceToString p ^ "@" ^ LargeInt.toString q | NONE => "NONE"
        val bboAsk = case bestAsk b of SOME (p, q) => Types.priceToString p ^ "@" ^ LargeInt.toString q | NONE => "NONE"
        val sp = case spread b of SOME s => Types.priceToString s | NONE => "N/A"
      in
        "OrderBook(" ^ #symbol b ^ ",BBO=" ^ bboBid ^ " / " ^ bboAsk ^ ",spread=" ^ sp ^ ",orders=" ^ Int.toString (totalOrders b) ^ ")"
      end

  fun formatLadder (b : book) (depth : int) : string =
      let
        val asks = List.rev (topAsks b depth)
        val bids = topBids b depth
        fun fmtLevel (p, q, cnt) side =
            let
              val pStr = StringCvt.padLeft #" " 12 (Types.priceToString p)
              val qStr = StringCvt.padLeft #" " 8 (LargeInt.toString q)
              val cntStr = "(" ^ Int.toString cnt ^ ")"
            in
              if side = "ASK" then
                "  [ASK] " ^ pStr ^ " | " ^ qStr ^ " " ^ cntStr ^ "\n"
              else
                "  [BID] " ^ pStr ^ " | " ^ qStr ^ " " ^ cntStr ^ "\n"
            end
        val askStrs = String.concat (List.map (fn lvl => fmtLevel lvl "ASK") asks)
        val spreadStr =
            case spread b of
                SOME s => "  --- SPREAD: " ^ Types.priceToString s ^ " ---\n"
              | NONE => "  --- EMPTY SPREAD ---\n"
        val bidStrs = String.concat (List.map (fn lvl => fmtLevel lvl "BID") bids)
      in
        "=== Depth Ladder for " ^ #symbol b ^ " ===\n" ^
        askStrs ^ spreadStr ^ bidStrs ^
        "====================================\n"
      end
end
