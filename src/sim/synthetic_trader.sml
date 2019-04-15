(* synthetic_trader.sml
 * Implementation of algorithmic trader strategies.
 *)

structure SyntheticTrader :> SYNTHETIC_TRADER =
struct
  datatype strategy =
      MarketMaker of {
        half_spread : Types.price,
        quote_qty : Types.qty,
        inventory_skew_factor : real
      }
    | Momentum of {
        momentum_threshold : real,
        order_qty : Types.qty
      }
    | Noise of {
        arrival_rate : real,
        typical_qty : Types.qty
      }
    | VwapSlicer of {
        parent_qty : Types.qty,
        slices_remaining : int,
        interval_ns : Types.timestamp_ns,
        side : Types.side
      }

  type trader = {
    client_id : Types.client_id,
    strategy : strategy,
    next_action_time : Types.timestamp_ns
  }

  fun createMarketMaker clientId halfSpread qty skew : trader =
      {
        client_id = clientId,
        strategy = MarketMaker {
          half_spread = halfSpread,
          quote_qty = qty,
          inventory_skew_factor = skew
        },
        next_action_time = 0
      }

  fun createMomentumTrader clientId thresh qty : trader =
      {
        client_id = clientId,
        strategy = Momentum {
          momentum_threshold = thresh,
          order_qty = qty
        },
        next_action_time = 0
      }

  fun createNoiseTrader clientId rate qty : trader =
      {
        client_id = clientId,
        strategy = Noise {
          arrival_rate = rate,
          typical_qty = qty
        },
        next_action_time = 0
      }

  fun createVwapSlicer clientId parentQty slices interval side : trader =
      {
        client_id = clientId,
        strategy = VwapSlicer {
          parent_qty = parentQty,
          slices_remaining = slices,
          interval_ns = interval,
          side = side
        },
        next_action_time = 0
      }

  fun tickTrader (t : trader) { book, current_time = now, inventory, nextOrderId } =
      if now < #next_action_time t then (t, [])
      else
        let
          val sym = OrderBook.symbol book
          val clientId = #client_id t
        in
          case #strategy t of
              MarketMaker { half_spread, quote_qty, inventory_skew_factor } =>
                let
                  val refPrice = case OrderBook.midPrice book of
                                     SOME mp => mp
                                   | NONE =>
                                       case OrderBook.lastTrade book of
                                           SOME (p, _) => p
                                         | NONE => valOf (Types.priceFromString "100.00")

                  (* Inventory skew: if inventory > 0 (long), skew quotes lower *)
                  val skewTicks = LargeInt.fromLarge (Real.toLargeInt IEEEReal.TO_NEAREST (Real.fromLargeInt (LargeInt.toLarge inventory) * inventory_skew_factor))
                  val reservationPrice = refPrice - (skewTicks * (Types.priceScale div 100))

                  val bidPrice = reservationPrice - half_spread
                  val askPrice = reservationPrice + half_spread

                  val bidOrd = Order.create {
                    id = nextOrderId (),
                    client_id = clientId,
                    symbol = sym,
                    side = Types.Buy,
                    order_type = Types.Limit { price = bidPrice },
                    time_in_force = Types.GTC,
                    price = bidPrice,
                    qty = quote_qty,
                    timestamp = now
                  }

                  val askOrd = Order.create {
                    id = nextOrderId (),
                    client_id = clientId,
                    symbol = sym,
                    side = Types.Sell,
                    order_type = Types.Limit { price = askPrice },
                    time_in_force = Types.GTC,
                    price = askPrice,
                    qty = quote_qty,
                    timestamp = now
                  }

                  val nextT : trader = {
                    client_id = clientId,
                    strategy = #strategy t,
                    next_action_time = now + 100000000 (* 100ms interval *)
                  }
                in
                  (nextT, [bidOrd, askOrd])
                end

            | Momentum { momentum_threshold, order_qty } =>
                (* Simple momentum based on spread direction *)
                let
                  val orderOpt =
                      case (OrderBook.bestBid book, OrderBook.bestAsk book) of
                          (SOME (bidP, _), SOME (askP, _)) =>
                            let
                              val mid = (bidP + askP) div 2
                            in
                              SOME (Order.create {
                                id = nextOrderId (),
                                client_id = clientId,
                                symbol = sym,
                                side = Types.Buy,
                                order_type = Types.Limit { price = askP },
                                time_in_force = Types.IOC,
                                price = askP,
                                qty = order_qty,
                                timestamp = now
                              })
                            end
                        | _ => NONE

                  val nextT : trader = {
                    client_id = clientId,
                    strategy = #strategy t,
                    next_action_time = now + 500000000 (* 500ms interval *)
                  }
                in
                  case orderOpt of
                      SOME ord => (nextT, [ord])
                    | NONE => (nextT, [])
                end

            | Noise { arrival_rate, typical_qty } =>
                let
                  val side = if LargeInt.mod (now, 2) = 0 then Types.Buy else Types.Sell
                  val pOpt = case side of
                                 Types.Buy =>
                                   (case OrderBook.bestBid book of SOME (p, _) => SOME p | NONE => Types.priceFromString "100.00")
                               | Types.Sell =>
                                   (case OrderBook.bestAsk book of SOME (p, _) => SOME p | NONE => Types.priceFromString "100.05")

                  val ordOpt =
                      case pOpt of
                          SOME p =>
                            SOME (Order.create {
                              id = nextOrderId (),
                              client_id = clientId,
                              symbol = sym,
                              side = side,
                              order_type = Types.Limit { price = p },
                              time_in_force = Types.GTC,
                              price = p,
                              qty = typical_qty,
                              timestamp = now
                            })
                        | NONE => NONE

                  val nextT : trader = {
                    client_id = clientId,
                    strategy = #strategy t,
                    next_action_time = now + 200000000 (* 200ms interval *)
                  }
                in
                  case ordOpt of
                      SOME ord => (nextT, [ord])
                    | NONE => (nextT, [])
                end

            | VwapSlicer { parent_qty, slices_remaining, interval_ns, side } =>
                if slices_remaining <= 0 orelse parent_qty <= 0 then
                  (t, [])
                else
                  let
                    val sliceQty = parent_qty div (LargeInt.fromInt slices_remaining)
                    val pOpt = case side of
                                   Types.Buy =>
                                     (case OrderBook.bestAsk book of SOME (p, _) => SOME p | NONE => NONE)
                                 | Types.Sell =>
                                     (case OrderBook.bestBid book of SOME (p, _) => SOME p | NONE => NONE)

                    val ordOpt =
                        case pOpt of
                            SOME p =>
                              SOME (Order.create {
                                id = nextOrderId (),
                                client_id = clientId,
                                symbol = sym,
                                side = side,
                                order_type = Types.Limit { price = p },
                                time_in_force = Types.IOC,
                                price = p,
                                qty = sliceQty,
                                timestamp = now
                              })
                          | NONE => NONE

                    val updatedStrategy = VwapSlicer {
                      parent_qty = parent_qty - sliceQty,
                      slices_remaining = slices_remaining - 1,
                      interval_ns = interval_ns,
                      side = side
                    }

                    val nextT : trader = {
                      client_id = clientId,
                      strategy = updatedStrategy,
                      next_action_time = now + interval_ns
                    }
                  in
                    case ordOpt of
                        SOME ord => (nextT, [ord])
                      | NONE => (nextT, [])
                  end
        end
end
