(* level1_feed.sml
 * Implementation of Level 1 BBO feed publisher.
 *)

structure Level1Feed :> LEVEL1_FEED =
struct
  structure SymbolKey = struct
    type ord_key = Types.symbol_id
    val compare = String.compare
  end

  structure BboMap = RedBlackMapFn (SymbolKey)

  type bbo = {
    symbol : Types.symbol_id,
    bid_price : Types.price option,
    bid_qty : Types.qty option,
    ask_price : Types.price option,
    ask_qty : Types.qty option,
    last_trade_price : Types.price option,
    last_trade_qty : Types.qty option,
    total_volume : Types.qty,
    timestamp : Types.timestamp_ns
  }

  type feed = {
    cache : bbo BboMap.map
  }

  fun create () : feed =
      { cache = BboMap.empty }

  fun getBBO (f : feed) (sym : Types.symbol_id) =
      BboMap.find (#cache f, sym)

  fun hasChanged (oldBBO : bbo) (newBBO : bbo) : bool =
      #bid_price oldBBO <> #bid_price newBBO orelse
      #bid_qty oldBBO <> #bid_qty newBBO orelse
      #ask_price oldBBO <> #ask_price newBBO orelse
      #ask_qty oldBBO <> #ask_qty newBBO orelse
      #last_trade_price oldBBO <> #last_trade_price newBBO orelse
      #total_volume oldBBO <> #total_volume newBBO

  fun updateBook (f : feed) (b : OrderBook.book) (ts : Types.timestamp_ns) : (feed * bbo option) =
      let
        val sym = OrderBook.symbol b
        val (curBidP, curBidQ) = case OrderBook.bestBid b of
                                     SOME (p, q) => (SOME p, SOME q)
                                   | NONE => (NONE, NONE)
        val (curAskP, curAskQ) = case OrderBook.bestAsk b of
                                     SOME (p, q) => (SOME p, SOME q)
                                   | NONE => (NONE, NONE)
        val (lastP, lastQ) = case OrderBook.lastTrade b of
                                 SOME (p, q) => (SOME p, SOME q)
                               | NONE => (NONE, NONE)
        val vol = OrderBook.totalVolume b

        val newBbo : bbo = {
          symbol = sym,
          bid_price = curBidP,
          bid_qty = curBidQ,
          ask_price = curAskP,
          ask_qty = curAskQ,
          last_trade_price = lastP,
          last_trade_qty = lastQ,
          total_volume = vol,
          timestamp = ts
        }

        val (updatedFeed, emitOpt) =
            case getBBO f sym of
                NONE =>
                  let val newCache = BboMap.insert (#cache f, sym, newBbo) in
                    ({ cache = newCache }, SOME newBbo)
                  end
              | SOME oldBbo =>
                  if hasChanged oldBbo newBbo then
                    let val newCache = BboMap.insert (#cache f, sym, newBbo) in
                      ({ cache = newCache }, SOME newBbo)
                    end
                  else
                    (f, NONE)
      in
        (updatedFeed, emitOpt)
      end

  fun bboToString (b : bbo) : string =
      let
        val bStr = case (#bid_price b, #bid_qty b) of (SOME p, SOME q) => Types.priceToString p ^ "@" ^ LargeInt.toString q | _ => "NONE"
        val aStr = case (#ask_price b, #ask_qty b) of (SOME p, SOME q) => Types.priceToString p ^ "@" ^ LargeInt.toString q | _ => "NONE"
        val ltStr = case #last_trade_price b of SOME p => " last=" ^ Types.priceToString p | NONE => ""
      in
        "BBO[" ^ #symbol b ^ "]: " ^ bStr ^ " / " ^ aStr ^ ltStr ^ " vol=" ^ LargeInt.toString (#total_volume b)
      end
end
