(* microprice.sml
 * Implementation of Microprice estimator and Order Flow Imbalance.
 *)

structure Microprice :> MICROPRICE =
struct
  type estimator = unit

  fun create () = ()

  fun calculateMicroprice (b : OrderBook.book) : Types.price option =
      case (OrderBook.bestBid b, OrderBook.bestAsk b) of
          (SOME (bidP, bidQ), SOME (askP, askQ)) =>
            let
              val totalQ = bidQ + askQ
            in
              if totalQ <= 0 then NONE
              else
                let
                  (* (bidQ * askP + askQ * bidP) / totalQ *)
                  val weightedSum = (bidQ * askP) + (askQ * bidP)
                in
                  SOME (weightedSum div totalQ)
                end
            end
        | _ => NONE

  fun calculateImbalanceRatio (b : OrderBook.book) : real option =
      case (OrderBook.bestBid b, OrderBook.bestAsk b) of
          (SOME (_, bidQ), SOME (_, askQ)) =>
            let
              val diff = Real.fromLargeInt (LargeInt.toLarge (bidQ - askQ))
              val sum = Real.fromLargeInt (LargeInt.toLarge (bidQ + askQ))
            in
              if sum > 0.0 then SOME (diff / sum)
              else NONE
            end
        | _ => NONE

  fun calculateMultiLevelMicroprice (b : OrderBook.book) (levels : int) : Types.price option =
      let
        val bids = OrderBook.topBids b levels
        val asks = OrderBook.topAsks b levels

        (* Inverse distance weight: 1.0, 0.5, 0.33, etc. *)
        fun foldLevels ([], _, numAcc, denAcc) = (numAcc, denAcc)
          | foldLevels ((p, q, _) :: rest, rank, numAcc, denAcc) =
              let
                val weight = 1.0 / (Real.fromInt rank)
                val weightedQ = Real.fromLargeInt (LargeInt.toLarge q) * weight
                val pVal = Real.fromLargeInt (LargeInt.toLarge p)
              in
                foldLevels (rest, rank + 1, numAcc + (pVal * weightedQ), denAcc + weightedQ)
              end

        val (bidNum, bidDen) = foldLevels (bids, 1, 0.0, 0.0)
        val (askNum, askDen) = foldLevels (asks, 1, 0.0, 0.0)
        val totalDen = bidDen + askDen
      in
        if totalDen > 0.0 then
          let
            (* Microprice weights opposite: bid volume pulls price towards ask, ask volume pulls price towards bid *)
            val microVal = (bidDen * (askNum / (if askDen > 0.0 then askDen else 1.0)) +
                            askDen * (bidNum / (if bidDen > 0.0 then bidDen else 1.0))) / totalDen
          in
            SOME (LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST microVal))
          end
        else NONE
      end
end
