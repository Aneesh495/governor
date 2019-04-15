(* matcher.sml
 * Implementation of deterministic matching engine core.
 *)

structure Matcher :> MATCHER =
struct
  type match_result = {
    book : OrderBook.book,
    trades : Trade.trade list,
    order : Order.order
  }

  fun canFulfillFOK (b : OrderBook.book) (ord : Order.order) : bool =
      let
        val needed = #leaves_qty ord
        val side = #side ord
        val limitPrice = #price ord
      in
        case side of
            Types.Buy =>
              let
                fun scanLevels ([], acc) = acc >= needed
                  | scanLevels ((p, q, _) :: rest, acc) =
                      if p <= limitPrice then
                        let val newAcc = acc + q in
                          if newAcc >= needed then true
                          else scanLevels (rest, newAcc)
                        end
                      else acc >= needed
              in
                scanLevels (OrderBook.topAsks b 1000, 0)
              end
          | Types.Sell =>
              let
                fun scanLevels ([], acc) = acc >= needed
                  | scanLevels ((p, q, _) :: rest, acc) =
                      if p >= limitPrice then
                        let val newAcc = acc + q in
                          if newAcc >= needed then true
                          else scanLevels (rest, newAcc)
                        end
                      else acc >= needed
              in
                scanLevels (OrderBook.topBids b 1000, 0)
              end
      end

  fun willCrossSpread (b : OrderBook.book) (ord : Order.order) : bool =
      case #side ord of
          Types.Buy =>
            (case OrderBook.bestAsk b of
                 SOME (bestAskP, _) => #price ord >= bestAskP
               | NONE => false)
        | Types.Sell =>
            (case OrderBook.bestBid b of
                 SOME (bestBidP, _) => #price ord <= bestBidP
               | NONE => false)

  fun processOrder { book, order = inOrd, policy, nextMatchId, timestamp } : match_result =
      let
        val isPostOnly = case #order_type inOrd of Types.PostOnly _ => true | _ => false
        val isFOK = case #time_in_force inOrd of Types.FOK => true | _ => false
        val isIOC = case #time_in_force inOrd of Types.IOC => true | _ => false
        val isMarket = case #order_type inOrd of Types.Market => true | _ => false
      in
        if isPostOnly andalso willCrossSpread book inOrd then
          {
            book = book,
            trades = [],
            order = Order.cancel inOrd timestamp
          }
        else if isFOK andalso not (canFulfillFOK book inOrd) then
          {
            book = book,
            trades = [],
            order = Order.cancel inOrd timestamp
          }
        else
          (* Execute aggressive matching loop *)
          let
            fun matchLoop (curBook : OrderBook.book, curOrd : Order.order, accTrades : Trade.trade list) =
                if #leaves_qty curOrd <= 0 then
                  (curBook, curOrd, List.rev accTrades)
                else
                  case #side curOrd of
                      Types.Buy =>
                        (case OrderBook.getBestAskLevel curBook of
                             NONE => (curBook, curOrd, List.rev accTrades)
                           | SOME askLvl =>
                               let
                                 val askP = #price askLvl
                                 val canTrade = isMarket orelse (#price curOrd >= askP)
                               in
                                 if not canTrade then
                                   (curBook, curOrd, List.rev accTrades)
                                 else
                                   let
                                     val allocations = MatchingPolicy.allocate policy (#leaves_qty curOrd) (PriceLevel.getOrders askLvl)
                                     fun processAllocations ([], b, aggOrd, trades, lvl) =
                                           let
                                             val updatedB = OrderBook.updateAskLevel b lvl
                                           in
                                             matchLoop (updatedB, aggOrd, trades)
                                           end
                                       | processAllocations ((makerOrd, fillQty) :: rest, b, aggOrd, trades, lvl) =
                                           if fillQty <= 0 then
                                             processAllocations (rest, b, aggOrd, trades, lvl)
                                           else
                                             let
                                               val matchId = nextMatchId ()
                                               val trade = Trade.create {
                                                 match_id = matchId,
                                                 symbol = #symbol aggOrd,
                                                 price = askP,
                                                 qty = fillQty,
                                                 maker_order_id = #id makerOrd,
                                                 taker_order_id = #id aggOrd,
                                                 maker_client_id = #client_id makerOrd,
                                                 taker_client_id = #client_id aggOrd,
                                                 aggressor_side = Types.Buy,
                                                 timestamp = timestamp
                                               }
                                               val updatedAggOrd = Order.executeFill aggOrd fillQty timestamp
                                               val filledMaker = Order.executeFill makerOrd fillQty timestamp
                                               val finalMaker =
                                                   if #leaves_qty filledMaker <= 0 andalso #hidden_qty filledMaker > 0 then
                                                     Order.replenishIceberg filledMaker timestamp
                                                   else filledMaker

                                               val updatedLvl =
                                                   case PriceLevel.removeOrder lvl (#id makerOrd) of
                                                       NONE => lvl
                                                     | SOME (_, lWithout) =>
                                                         if #leaves_qty finalMaker > 0 then
                                                           PriceLevel.addOrder lWithout finalMaker
                                                         else lWithout

                                               val bWithTrade = OrderBook.recordTrade b askP fillQty timestamp
                                                val updatedB =
                                                    if #leaves_qty finalMaker <= 0 then
                                                      OrderBook.removeOrderIndex bWithTrade (#id makerOrd)
                                                    else bWithTrade
                                             in
                                               processAllocations (rest, updatedB, updatedAggOrd, trade :: trades, updatedLvl)
                                             end
                                   in
                                     processAllocations (allocations, curBook, curOrd, accTrades, askLvl)
                                   end
                               end)
                    | Types.Sell =>
                        (case OrderBook.getBestBidLevel curBook of
                             NONE => (curBook, curOrd, List.rev accTrades)
                           | SOME bidLvl =>
                               let
                                 val bidP = #price bidLvl
                                 val canTrade = isMarket orelse (#price curOrd <= bidP)
                               in
                                 if not canTrade then
                                   (curBook, curOrd, List.rev accTrades)
                                 else
                                   let
                                     val allocations = MatchingPolicy.allocate policy (#leaves_qty curOrd) (PriceLevel.getOrders bidLvl)
                                     fun processAllocations ([], b, aggOrd, trades, lvl) =
                                           let
                                             val updatedB = OrderBook.updateBidLevel b lvl
                                           in
                                             matchLoop (updatedB, aggOrd, trades)
                                           end
                                       | processAllocations ((makerOrd, fillQty) :: rest, b, aggOrd, trades, lvl) =
                                           if fillQty <= 0 then
                                             processAllocations (rest, b, aggOrd, trades, lvl)
                                           else
                                             let
                                               val matchId = nextMatchId ()
                                               val trade = Trade.create {
                                                 match_id = matchId,
                                                 symbol = #symbol aggOrd,
                                                 price = bidP,
                                                 qty = fillQty,
                                                 maker_order_id = #id makerOrd,
                                                 taker_order_id = #id aggOrd,
                                                 maker_client_id = #client_id makerOrd,
                                                 taker_client_id = #client_id aggOrd,
                                                 aggressor_side = Types.Sell,
                                                 timestamp = timestamp
                                               }
                                               val updatedAggOrd = Order.executeFill aggOrd fillQty timestamp
                                               val filledMaker = Order.executeFill makerOrd fillQty timestamp
                                               val finalMaker =
                                                   if #leaves_qty filledMaker <= 0 andalso #hidden_qty filledMaker > 0 then
                                                     Order.replenishIceberg filledMaker timestamp
                                                   else filledMaker

                                               val updatedLvl =
                                                   case PriceLevel.removeOrder lvl (#id makerOrd) of
                                                       NONE => lvl
                                                     | SOME (_, lWithout) =>
                                                         if #leaves_qty finalMaker > 0 then
                                                           PriceLevel.addOrder lWithout finalMaker
                                                         else lWithout

                                               val bWithTrade = OrderBook.recordTrade b bidP fillQty timestamp
                                                val updatedB =
                                                    if #leaves_qty finalMaker <= 0 then
                                                      OrderBook.removeOrderIndex bWithTrade (#id makerOrd)
                                                    else bWithTrade
                                             in
                                               processAllocations (rest, updatedB, updatedAggOrd, trade :: trades, updatedLvl)
                                             end
                                   in
                                     processAllocations (allocations, curBook, curOrd, accTrades, bidLvl)
                                   end
                               end)

            val (bookAfterTrades, matchedOrd, allTrades) = matchLoop (book, inOrd, [])
          in
            if isIOC orelse isMarket then
              let
                val finalOrd =
                    if #leaves_qty matchedOrd > 0 then
                      Order.cancel matchedOrd timestamp
                    else matchedOrd
              in
                {
                  book = bookAfterTrades,
                  trades = allTrades,
                  order = finalOrd
                }
              end
            else
              if #leaves_qty matchedOrd > 0 then
                let
                  val restingBook = OrderBook.insertOrder bookAfterTrades matchedOrd
                in
                  {
                    book = restingBook,
                    trades = allTrades,
                    order = matchedOrd
                  }
                end
              else
                {
                  book = bookAfterTrades,
                  trades = allTrades,
                  order = matchedOrd
                }
          end
      end
end
