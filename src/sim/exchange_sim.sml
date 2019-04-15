(* exchange_sim.sml
 * Implementation of multi-symbol simulated market environment.
 *)

structure ExchangeSim :> EXCHANGE_SIM =
struct
  type sim = {
    books : BookManager.manager,
    risk : RiskEngine.engine,
    l1_feed : Level1Feed.feed,
    journal : EventJournal.journal,
    traders : SyntheticTrader.trader list,
    order_id_counter : Types.order_id ref,
    match_id_counter : Types.match_id ref,
    seq_counter : Types.sequence_num ref,
    total_trades_count : int ref,
    total_volume_executed : Types.qty ref
  }

  fun create () : sim =
      {
        books = BookManager.create (),
        risk = RiskEngine.create (),
        l1_feed = Level1Feed.create (),
        journal = EventJournal.create 50000,
        traders = [],
        order_id_counter = ref 1,
        match_id_counter = ref 1,
        seq_counter = ref 1,
        total_trades_count = ref 0,
        total_volume_executed = ref 0
      }

  fun nextOrderId (s : sim) () : Types.order_id =
      let val id = !(#order_id_counter s) in #order_id_counter s := id + 1; id end

  fun nextMatchId (s : sim) () : Types.match_id =
      let val id = !(#match_id_counter s) in #match_id_counter s := id + 1; id end

  fun nextSeq (s : sim) () : Types.sequence_num =
      let val seq = !(#seq_counter s) in #seq_counter s := seq + 1; seq end

  fun addSymbol (s : sim) (sym : Types.symbol_id) : sim =
      {
        books = BookManager.addSymbol (#books s) sym,
        risk = #risk s,
        l1_feed = #l1_feed s,
        journal = #journal s,
        traders = #traders s,
        order_id_counter = #order_id_counter s,
        match_id_counter = #match_id_counter s,
        seq_counter = #seq_counter s,
        total_trades_count = #total_trades_count s,
        total_volume_executed = #total_volume_executed s
      }

  fun registerTrader (s : sim) (t : SyntheticTrader.trader) : sim =
      let
        val clientId = #client_id t
        val lim = RiskLimits.defaultLimits clientId
        val updatedRisk = RiskEngine.registerClient (#risk s) clientId lim 100000000
      in
        {
          books = #books s,
          risk = updatedRisk,
          l1_feed = #l1_feed s,
          journal = #journal s,
          traders = t :: #traders s,
          order_id_counter = #order_id_counter s,
          match_id_counter = #match_id_counter s,
          seq_counter = #seq_counter s,
          total_trades_count = #total_trades_count s,
          total_volume_executed = #total_volume_executed s
        }
      end

  fun submitOrder (s : sim) (ord : Order.order) : (sim * Trade.trade list, string) Result.result =
      let
        val sym = #symbol ord
        val ts = #created_at ord
      in
        case BookManager.getBook (#books s) sym of
            NONE => Result.err ("Symbol " ^ sym ^ " not registered")
          | SOME b =>
              case RiskEngine.validateOrder { engine = #risk s, book = b, order = ord, timestamp = ts } of
                  Result.Err err => Result.err err
                | Result.Ok riskAfterPreTrade =>
                    let
                      val matchRes = Matcher.processOrder {
                        book = b,
                        order = ord,
                        policy = MatchingPolicy.Fifo,
                        nextMatchId = nextMatchId s,
                        timestamp = ts
                      }
                      val updatedBook = #book matchRes
                      val trades = #trades matchRes
                      val finalOrd = #order matchRes

                      (* Record events in journal *)
                      val seq1 = nextSeq s ()
                      val () = EventJournal.record (#journal s) (MarketDataEvent.OrderAdded {
                        seq = seq1,
                        symbol = sym,
                        order_id = #id ord,
                        side = #side ord,
                        price = #price ord,
                        qty = #initial_qty ord,
                        timestamp = ts
                      })

                      val () = List.app (fn (t : Trade.trade) =>
                        let
                          val tSeq = nextSeq s ()
                        in
                          #total_trades_count s := !(#total_trades_count s) + 1;
                          #total_volume_executed s := !(#total_volume_executed s) + #qty t;
                          EventJournal.record (#journal s) (MarketDataEvent.OrderExecuted {
                            seq = tSeq,
                            symbol = sym,
                            match_id = #match_id t,
                            maker_order_id = #maker_order_id t,
                            taker_order_id = #taker_order_id t,
                            price = #price t,
                            qty = #qty t,
                            timestamp = ts
                          })
                        end) trades

                      (* Update Risk Engine with trade fills *)
                      val riskAfterTrades = List.foldl (fn (t, r) => RiskEngine.recordTradeExecution r t) riskAfterPreTrade trades

                      (* Update L1 feed *)
                      val (updatedL1, _) = Level1Feed.updateBook (#l1_feed s) updatedBook ts

                      (* Update BookManager *)
                      val updatedMgr = BookManager.updateBook (#books s) updatedBook

                      val updatedSim : sim = {
                        books = updatedMgr,
                        risk = riskAfterTrades,
                        l1_feed = updatedL1,
                        journal = #journal s,
                        traders = #traders s,
                        order_id_counter = #order_id_counter s,
                        match_id_counter = #match_id_counter s,
                        seq_counter = #seq_counter s,
                        total_trades_count = #total_trades_count s,
                        total_volume_executed = #total_volume_executed s
                      }
                    in
                      Result.ok (updatedSim, trades)
                    end
      end

  fun step (s : sim) (now : Types.timestamp_ns) : sim =
      let
        val traders = #traders s
        fun runTraders ([], curSim, accTraders) =
              {
                books = #books curSim,
                risk = #risk curSim,
                l1_feed = #l1_feed curSim,
                journal = #journal curSim,
                traders = List.rev accTraders,
                order_id_counter = #order_id_counter curSim,
                match_id_counter = #match_id_counter curSim,
                seq_counter = #seq_counter curSim,
                total_trades_count = #total_trades_count curSim,
                total_volume_executed = #total_volume_executed curSim
              }
          | runTraders (t :: rest, curSim, accTraders) =
              let
                (* Use first registered symbol for trader tick *)
                val symList = BookManager.listSymbols (#books curSim)
              in
                case symList of
                    [] => runTraders (rest, curSim, t :: accTraders)
                  | sym :: _ =>
                      let
                        val b = valOf (BookManager.getBook (#books curSim) sym)
                        val inv = case RiskEngine.getTraderState (#risk curSim) (#client_id t) of
                                      SOME ts => TraderState.getPosition ts sym
                                    | NONE => 0
                        val (updatedT, orders) = SyntheticTrader.tickTrader t {
                          book = b,
                          current_time = now,
                          inventory = inv,
                          nextOrderId = nextOrderId curSim
                        }

                        fun submitAll ([], simState) = simState
                          | submitAll (ord :: ords, simState) =
                              case submitOrder simState ord of
                                  Result.Ok (nextSim, _) => submitAll (ords, nextSim)
                                | Result.Err _ => submitAll (ords, simState)

                        val nextSim = submitAll (orders, curSim)
                      in
                        runTraders (rest, nextSim, updatedT :: accTraders)
                      end
              end
      in
        runTraders (traders, s, [])
      end

  fun getBook (s : sim) sym = BookManager.getBook (#books s) sym
  fun getL1Feed (s : sim) = #l1_feed s
  fun getJournal (s : sim) = #journal s
  fun totalTrades (s : sim) = !(#total_trades_count s)
  fun totalVolume (s : sim) = !(#total_volume_executed s)
end
