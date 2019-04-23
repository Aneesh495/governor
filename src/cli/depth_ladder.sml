(* depth_ladder.sml
 * Implementation of ANSI graphical depth ladder.
 *)

structure DepthLadder :> DEPTH_LADDER =
struct
  fun renderVolumeBar (q : Types.qty) (maxQ : Types.qty) (barWidth : int) : string =
      if maxQ <= 0 then ""
      else
        let
          val filled = LargeInt.toInt ((q * (LargeInt.fromInt barWidth)) div maxQ)
          val clampedFilled = if filled > barWidth then barWidth else if filled < 1 then 1 else filled
          val empty = barWidth - clampedFilled
          val barStr = CharVector.tabulate (clampedFilled, fn _ => #"#")
          val emptyStr = CharVector.tabulate (empty, fn _ => #" ")
        in
          "[" ^ barStr ^ emptyStr ^ "]"
        end

  fun renderLadder (b : OrderBook.book) (maxLevels : int) : string =
      let
        val asks = List.rev (OrderBook.topAsks b maxLevels)
        val bids = OrderBook.topBids b maxLevels

        val maxBidQ = List.foldl (fn ((_, q, _), acc) => if q > acc then q else acc) 0 bids
        val maxAskQ = List.foldl (fn ((_, q, _), acc) => if q > acc then q else acc) 0 asks
        val maxQ = if maxBidQ > maxAskQ then maxBidQ else maxAskQ

        val header =
            Ansi.colorize Ansi.bold ("+========================================================================+\n") ^
            Ansi.colorize Ansi.brightCyan ("|  GOVERNOR ORDER BOOK DEPTH LADDER: " ^ StringCvt.padRight #" " 34 (OrderBook.symbol b) ^ "|\n") ^
            Ansi.colorize Ansi.bold ("+------------------------------------------------------------------------+\n") ^
            "| SIDE |    PRICE    |   SIZE   | ORDERS | VOLUME BAR                    |\n" ^
            "+------+-------------+----------+--------+-------------------------------+\n"

        fun fmtAsk (p, q, cnt) =
            let
              val pStr = Ansi.colorize Ansi.brightRed (StringCvt.padLeft #" " 11 (Types.priceToString p))
              val qStr = StringCvt.padLeft #" " 8 (LargeInt.toString q)
              val cntStr = StringCvt.padLeft #" " 6 (Int.toString cnt)
              val bar = Ansi.colorize Ansi.red (renderVolumeBar q maxQ 29)
            in
              "| ASK  | " ^ pStr ^ " | " ^ qStr ^ " | " ^ cntStr ^ " | " ^ bar ^ " |\n"
            end

        fun fmtBid (p, q, cnt) =
            let
              val pStr = Ansi.colorize Ansi.brightGreen (StringCvt.padLeft #" " 11 (Types.priceToString p))
              val qStr = StringCvt.padLeft #" " 8 (LargeInt.toString q)
              val cntStr = StringCvt.padLeft #" " 6 (Int.toString cnt)
              val bar = Ansi.colorize Ansi.green (renderVolumeBar q maxQ 29)
            in
              "| BID  | " ^ pStr ^ " | " ^ qStr ^ " | " ^ cntStr ^ " | " ^ bar ^ " |\n"
            end

        val askRows = String.concat (List.map fmtAsk asks)

        val spreadStr =
            case OrderBook.spread b of
                SOME s =>
                  let
                    val mid = case OrderBook.midPrice b of SOME m => Types.priceToString m | NONE => "N/A"
                  in
                    "+------------------------------------------------------------------------+\n" ^
                    "| SPREAD: " ^ StringCvt.padRight #" " 10 (Types.priceToString s) ^
                    " MID: " ^ StringCvt.padRight #" " 12 mid ^
                    " TOTAL ORDERS: " ^ StringCvt.padRight #" " 8 (Int.toString (OrderBook.totalOrders b)) ^ "|\n" ^
                    "+------------------------------------------------------------------------+\n"
                  end
              | NONE =>
                  "+------------------------------------------------------------------------+\n" ^
                  "|                             NO ACTIVE SPREAD                           |\n" ^
                  "+------------------------------------------------------------------------+\n"

        val bidRows = String.concat (List.map fmtBid bids)
        val footer = "+========================================================================+\n"
      in
        header ^ askRows ^ spreadStr ^ bidRows ^ footer
      end
end
