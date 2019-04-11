(* risk_engine.sml
 * Implementation of RiskEngine pre-trade checks.
 *)

structure RiskEngine :> RISK_ENGINE =
struct
  structure ClientKey = struct
    type ord_key = Types.client_id
    val compare = String.compare
  end

  structure ClientMap = RedBlackMapFn (ClientKey)

  type engine = {
    limits_map : RiskLimits.limits ClientMap.map,
    state_map : TraderState.state ClientMap.map
  }

  fun create () : engine =
      {
        limits_map = ClientMap.empty,
        state_map = ClientMap.empty
      }

  fun registerClient (eng : engine) (clientId : Types.client_id) (lim : RiskLimits.limits) (initialCash : LargeInt.int) : engine =
      {
        limits_map = ClientMap.insert (#limits_map eng, clientId, lim),
        state_map = ClientMap.insert (#state_map eng, clientId, TraderState.create clientId initialCash)
      }

  fun getLimits (eng : engine) (clientId : Types.client_id) =
      ClientMap.find (#limits_map eng, clientId)

  fun getTraderState (eng : engine) (clientId : Types.client_id) =
      ClientMap.find (#state_map eng, clientId)

  fun validateOrder { engine = eng, book, order = ord, timestamp } : (engine, string) Result.result =
      let
        val clientId = #client_id ord
        val lim = case getLimits eng clientId of
                      SOME l => l
                    | NONE => RiskLimits.defaultLimits clientId
        val state = case getTraderState eng clientId of
                        SOME s => s
                      | NONE => TraderState.create clientId 1000000000

        val qty = #leaves_qty ord
        val p = #price ord
        val notional = (p * qty) div Types.priceScale
      in
        (* 1. Max Order Quantity Check *)
        if qty > #max_order_qty lim then
          Result.err ("Order quantity " ^ LargeInt.toString qty ^ " exceeds max limit " ^ LargeInt.toString (#max_order_qty lim))
        (* 2. Max Order Notional Check *)
        else if notional > #max_order_notional lim then
          Result.err ("Order notional " ^ LargeInt.toString notional ^ " exceeds max limit " ^ LargeInt.toString (#max_order_notional lim))
        (* 3. Message Rate Throttle Check *)
        else if TraderState.messageRateInLastSecond state timestamp >= #max_orders_per_second lim then
          Result.err ("Message rate exceeded: maximum " ^ Int.toString (#max_orders_per_second lim) ^ " orders/sec allowed")
        (* 4. Position Limit Check *)
        else
          let
            val curPos = TraderState.getPosition state (#symbol ord)
            val projectedPos = case #side ord of
                                   Types.Buy => curPos + qty
                                 | Types.Sell => curPos - qty
          in
            if projectedPos > #max_long_position lim then
              Result.err ("Projected long position " ^ LargeInt.toString projectedPos ^ " exceeds limit " ^ LargeInt.toString (#max_long_position lim))
            else if projectedPos < ~ (#max_short_position lim) then
              Result.err ("Projected short position " ^ LargeInt.toString projectedPos ^ " exceeds short limit -" ^ LargeInt.toString (#max_short_position lim))
            (* 5. Self-Match Prevention Check *)
            else
              case SelfMatch.evaluateSMP { book = book, order = ord, mode = #smp_mode lim } of
                  SelfMatch.CancelIncoming reason => Result.err ("Self-Match Prevention triggered: " ^ reason)
                | _ =>
                    let
                      val updatedState = TraderState.recordMessage state timestamp
                      val updatedState = TraderState.addOpenExposure updatedState notional
                      val newEng = {
                        limits_map = #limits_map eng,
                        state_map = ClientMap.insert (#state_map eng, clientId, updatedState)
                      }
                    in
                      Result.ok newEng
                    end
          end
      end

  fun recordTradeExecution (eng : engine) (t : Trade.trade) : engine =
      let
        val makerClient = #maker_client_id t
        val takerClient = #taker_client_id t
        val sym = #symbol t
        val p = #price t
        val q = #qty t

        fun updateClient clientId side (curEng : engine) =
            case getTraderState curEng clientId of
                NONE => curEng
              | SOME s =>
                  let
                    val updatedS = TraderState.updatePositionOnTrade s sym side q p
                    val notional = (p * q) div Types.priceScale
                    val finalS = TraderState.removeOpenExposure updatedS notional
                  in
                    {
                      limits_map = #limits_map curEng,
                      state_map = ClientMap.insert (#state_map curEng, clientId, finalS)
                    }
                  end

        val makerSide = case #aggressor_side t of Types.Buy => Types.Sell | Types.Sell => Types.Buy
        val takerSide = #aggressor_side t

        val eng1 = updateClient makerClient makerSide eng
        val eng2 = updateClient takerClient takerSide eng1
      in
        eng2
      end
end
