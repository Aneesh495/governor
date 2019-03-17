(* types.sml
 * Implementations of core financial numerical and identifier types.
 *)

structure Types :> TYPES =
struct
  type price = LargeInt.int
  type qty = LargeInt.int
  type order_id = LargeInt.int
  type client_id = string
  type symbol_id = string
  type match_id = LargeInt.int
  type sequence_num = LargeInt.int
  type timestamp_ns = LargeInt.int

  datatype side =
      Buy
    | Sell

  datatype time_in_force =
      GTC
    | IOC
    | FOK
    | GTD of timestamp_ns
    | Day

  datatype order_type =
      Limit of { price : price }
    | Market
    | StopLoss of { stop_price : price }
    | StopLimit of { stop_price : price, limit_price : price }
    | Iceberg of { price : price, peak_qty : qty }
    | PostOnly of { price : price }

  datatype order_status =
      PendingNew
    | Accepted
    | PartiallyFilled
    | Filled
    | Cancelled
    | Rejected of string
    | Expired

  datatype liquidity_indicator =
      Maker
    | Taker

  datatype smp_mode =
      CancelNewest
    | CancelOldest
    | CancelBoth
    | DecrementAndCancel

  val priceScale : LargeInt.int = 100000000

  fun fromDollars (d : real) : price =
      LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST (d * 100000000.0))

  fun toDollars (p : price) : real =
      (Real.fromLargeInt (LargeInt.toLarge p)) / 100000000.0

  fun priceToString (p : price) : string =
      let
        val sign = if p < 0 then "-" else ""
        val absP = LargeInt.abs p
        val dollars = absP div priceScale
        val frac = absP mod priceScale
        val fracStr = LargeInt.toString frac
        val paddedFrac = StringCvt.padLeft #"0" 8 fracStr
      in
        sign ^ LargeInt.toString dollars ^ "." ^ paddedFrac
      end

  fun priceFromString (s : string) : price option =
      case String.fields (fn c => c = #".") s of
          [dollarsStr] =>
            (case LargeInt.fromString dollarsStr of
                 SOME d => SOME (d * priceScale)
               | NONE => NONE)
        | [dollarsStr, fracStr] =>
            let
              val dOpt = LargeInt.fromString dollarsStr
              val fracLen = String.size fracStr
            in
              case dOpt of
                  NONE => NONE
                | SOME d =>
                    if fracLen > 8 then
                      NONE
                    else
                      let
                        val padded = fracStr ^ CharVector.tabulate (8 - fracLen, fn _ => #"0")
                      in
                        case LargeInt.fromString padded of
                            SOME f =>
                              if d >= 0 then
                                SOME (d * priceScale + f)
                              else
                                SOME (d * priceScale - f)
                          | NONE => NONE
                      end
            end
        | _ => NONE

  fun qtyToString (q : qty) : string = LargeInt.toString q

  fun qtyFromString (s : string) : qty option = LargeInt.fromString s

  fun sideToString Buy = "BUY"
    | sideToString Sell = "SELL"

  fun sideFromString s =
      case String.map Char.toUpper s of
          "BUY" => SOME Buy
        | "B" => SOME Buy
        | "SELL" => SOME Sell
        | "S" => SOME Sell
        | _ => NONE

  fun oppositeSide Buy = Sell
    | oppositeSide Sell = Buy

  fun orderTypeToString (Limit { price }) = "LIMIT(" ^ priceToString price ^ ")"
    | orderTypeToString Market = "MARKET"
    | orderTypeToString (StopLoss { stop_price }) = "STOP_LOSS(" ^ priceToString stop_price ^ ")"
    | orderTypeToString (StopLimit { stop_price, limit_price }) =
        "STOP_LIMIT(" ^ priceToString stop_price ^ "," ^ priceToString limit_price ^ ")"
    | orderTypeToString (Iceberg { price, peak_qty }) =
        "ICEBERG(" ^ priceToString price ^ ",peak=" ^ qtyToString peak_qty ^ ")"
    | orderTypeToString (PostOnly { price }) = "POST_ONLY(" ^ priceToString price ^ ")"

  fun statusToString PendingNew = "PENDING_NEW"
    | statusToString Accepted = "ACCEPTED"
    | statusToString PartiallyFilled = "PARTIALLY_FILLED"
    | statusToString Filled = "FILLED"
    | statusToString Cancelled = "CANCELLED"
    | statusToString (Rejected reason) = "REJECTED(" ^ reason ^ ")"
    | statusToString Expired = "EXPIRED"
end
