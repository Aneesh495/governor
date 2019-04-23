(* trade_blotter.sml
 * Implementation of ANSI trade blotter renderer.
 *)

structure TradeBlotter :> TRADE_BLOTTER =
struct
  fun renderBlotter (trades : Trade.trade list) (maxTrades : int) : string =
      let
        val recent = List.take (trades, if List.length trades < maxTrades then List.length trades else maxTrades)
        val header =
            Ansi.colorize Ansi.bold ("+=============================================================================+\n") ^
            Ansi.colorize Ansi.brightYellow ("|  RECENT TRADES BLOTTER                                                      |\n") ^
            Ansi.colorize Ansi.bold ("+-------+--------+-------------+--------+---------------+---------------+-----+\n") ^
            "| MATCH | SYMBOL |    PRICE    |  SIZE  |     MAKER     |     TAKER     | AGG |\n" ^
            "+-------+--------+-------------+--------+---------------+---------------+-----+\n"

        fun fmtTrade (t : Trade.trade) =
            let
              val mId = StringCvt.padLeft #" " 5 (LargeInt.toString (#match_id t))
              val sym = StringCvt.padRight #" " 6 (#symbol t)
              val sideColor = case #aggressor_side t of Types.Buy => Ansi.green | Types.Sell => Ansi.red
              val pStr = Ansi.colorize sideColor (StringCvt.padLeft #" " 11 (Types.priceToString (#price t)))
              val qStr = StringCvt.padLeft #" " 6 (LargeInt.toString (#qty t))
              val makerStr = StringCvt.padRight #" " 13 (#maker_client_id t)
              val takerStr = StringCvt.padRight #" " 13 (#taker_client_id t)
              val aggSideStr = case #aggressor_side t of Types.Buy => "BUY " | Types.Sell => "SELL"
            in
              "| " ^ mId ^ " | " ^ sym ^ " | " ^ pStr ^ " | " ^ qStr ^ " | " ^ makerStr ^ " | " ^ takerStr ^ " | " ^ aggSideStr ^ "|\n"
            end

        val rows = String.concat (List.map fmtTrade recent)
        val footer = "+=============================================================================+\n"
      in
        header ^ rows ^ footer
      end
end
