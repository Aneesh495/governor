(* auction.sml
 * Implementation of Call Auction clearing and batch uncrossing.
 *)

structure Auction :> AUCTION =
struct
  type uncross_result = {
    clearing_price : Types.price option,
    cleared_volume : Types.qty,
    imbalance : Types.qty,
    trades : Trade.trade list,
    book : OrderBook.book
  }

  fun calculateIndicativePrice (b : OrderBook.book) (refP : Types.price)
      : (Types.price * Types.qty * Types.qty) option =
      let
        val allBids = OrderBook.topBids b 1000
        val allAsks = OrderBook.topAsks b 1000
      in
        case (allBids, allAsks) of
            ([], _) => NONE
          | (_, []) => NONE
          | _ =>
              let
                (* Collect unique candidate price levels *)
                val bidPrices = List.map #1 allBids
                val askPrices = List.map #1 allAsks
                val allPrices =
                    List.foldl (fn (p, acc) => if List.exists (fn x => x = p) acc then acc else p :: acc)
                               bidPrices askPrices

                fun evalPrice candidateP =
                    let
                      (* Cumulative demand at candidateP: all bids with price >= candidateP *)
                      val cumBid =
                          List.foldl (fn ((p, q, _), acc) => if p >= candidateP then acc + q else acc) 0 allBids

                      (* Cumulative supply at candidateP: all asks with price <= candidateP *)
                      val cumAsk =
                          List.foldl (fn ((p, q, _), acc) => if p <= candidateP then acc + q else acc) 0 allAsks

                      val execVol = if cumBid < cumAsk then cumBid else cumAsk
                      val imbalance = LargeInt.abs (cumBid - cumAsk)
                      val distFromRef = LargeInt.abs (candidateP - refP)
                    in
                      (candidateP, execVol, imbalance, distFromRef)
                    end

                val candidates = List.map evalPrice allPrices
                val validCandidates = List.filter (fn (_, vol, _, _) => vol > 0) candidates
              in
                case validCandidates of
                    [] => NONE
                  | first :: rest =>
                      let
                        fun isBetter ((p1, v1, imb1, d1), (p2, v2, imb2, d2)) =
                            if v1 > v2 then true
                            else if v1 < v2 then false
                            else if imb1 < imb2 then true
                            else if imb1 > imb2 then false
                            else if d1 < d2 then true
                            else false

                        val (bestP, bestVol, bestImb, _) =
                            List.foldl (fn (c, best) => if isBetter (c, best) then c else best) first rest
                      in
                        SOME (bestP, bestVol, bestImb)
                      end
              end
      end

  fun uncross { book, reference_price, nextMatchId, timestamp } : uncross_result =
      case calculateIndicativePrice book reference_price of
          NONE =>
            {
              clearing_price = NONE,
              cleared_volume = 0,
              imbalance = 0,
              trades = [],
              book = book
            }
        | SOME (clearP, totalVol, imb) =>
            let
              (* Collect all crossing bids and asks *)
              fun collectCrossingBids (b : OrderBook.book, acc) =
                  case OrderBook.getBestBidLevel b of
                      NONE => (b, List.concat (List.rev acc))
                    | SOME lvl =>
                        if #price lvl >= clearP then
                          let
                            val orders = PriceLevel.getOrders lvl
                            val b' = OrderBook.removeBidLevel b (#price lvl)
                          in
                            collectCrossingBids (b', orders :: acc)
                          end
                        else
                          (b, List.concat (List.rev acc))

              fun collectCrossingAsks (b : OrderBook.book, acc) =
                  case OrderBook.getBestAskLevel b of
                      NONE => (b, List.concat (List.rev acc))
                    | SOME lvl =>
                        if #price lvl <= clearP then
                          let
                            val orders = PriceLevel.getOrders lvl
                            val b' = OrderBook.removeAskLevel b (#price lvl)
                          in
                            collectCrossingAsks (b', orders :: acc)
                          end
                        else
                          (b, List.concat (List.rev acc))

              val (bWithoutBids, crossingBids) = collectCrossingBids (book, [])
              val (bEmptyCrossing, crossingAsks) = collectCrossingAsks (bWithoutBids, [])

              (* Match crossing orders against each other at clearing price clearP *)
              fun matchCross ([], asks, b, trades, volLeft) = (b, trades, [], asks)
                | matchCross (bids, [], b, trades, volLeft) = (b, trades, bids, [])
                | matchCross (bids, asks, b, trades, volLeft) =
                    if volLeft <= 0 then (b, trades, bids, asks)
                    else
                      let
                        val bOrd = hd bids
                        val aOrd = hd asks
                        val fillQty =
                            let
                              val bAvail = #leaves_qty bOrd
                              val aAvail = #leaves_qty aOrd
                              val minAvail = if bAvail < aAvail then bAvail else aAvail
                            in
                              if minAvail < volLeft then minAvail else volLeft
                            end

                        val matchId = nextMatchId ()
                        val trade = Trade.create {
                          match_id = matchId,
                          symbol = #symbol bOrd,
                          price = clearP,
                          qty = fillQty,
                          maker_order_id = #id aOrd,
                          taker_order_id = #id bOrd,
                          maker_client_id = #client_id aOrd,
                          taker_client_id = #client_id bOrd,
                          aggressor_side = Types.Buy,
                          timestamp = timestamp
                        }

                        val updatedBOrd = Order.executeFill bOrd fillQty timestamp
                        val updatedAOrd = Order.executeFill aOrd fillQty timestamp

                        val nextBids =
                            if #leaves_qty updatedBOrd > 0 then updatedBOrd :: tl bids
                            else tl bids
                        val nextAsks =
                            if #leaves_qty updatedAOrd > 0 then updatedAOrd :: tl asks
                            else tl asks

                        val updatedB = OrderBook.recordTrade b clearP fillQty timestamp
                      in
                        matchCross (nextBids, nextAsks, updatedB, trade :: trades, volLeft - fillQty)
                      end

              val (bWithTrades, generatedTrades, unfulfilledBids, unfulfilledAsks) =
                  matchCross (crossingBids, crossingAsks, bEmptyCrossing, [], totalVol)

              (* Re-insert any residual unfilled portions back into the book *)
              val finalBook = List.foldl (fn (ord, curB) => OrderBook.insertOrder curB ord) bWithTrades unfulfilledBids
              val finalBook = List.foldl (fn (ord, curB) => OrderBook.insertOrder curB ord) finalBook unfulfilledAsks
            in
              {
                clearing_price = SOME clearP,
                cleared_volume = totalVol,
                imbalance = imb,
                trades = List.rev generatedTrades,
                book = finalBook
              }
            end
end
