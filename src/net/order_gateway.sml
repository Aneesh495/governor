(* order_gateway.sml
 * Implementation of Network Order Entry Gateway.
 *)

structure OrderGateway :> ORDER_GATEWAY =
struct
  type gateway = {
    sim : ExchangeSim.sim
  }

  fun create (initialSim : ExchangeSim.sim) : gateway =
      { sim = initialSim }

  fun getSim (gw : gateway) = #sim gw

  fun handleBinaryPacket (gw : gateway) (sess : GatewaySession.session) (buf : ByteBuffer.buffer) (now : Types.timestamp_ns) =
      case BinaryCodec.decodeNewOrder buf of
          Result.Err e => Result.err ("Binary decoding error: " ^ e)
        | Result.Ok req =>
            case GatewaySession.verifyInSeq sess (#seq req) of
                Result.Err seqErr => Result.err seqErr
              | Result.Ok () =>
                  let
                    val ord = Order.create {
                      id = #order_id req,
                      client_id = #client_id req,
                      symbol = #symbol req,
                      side = #side req,
                      order_type = #order_type req,
                      time_in_force = #time_in_force req,
                      price = #price req,
                      qty = #qty req,
                      timestamp = now
                    }
                  in
                    case ExchangeSim.submitOrder (#sim gw) ord of
                        Result.Err riskErr => Result.err ("Risk rejection: " ^ riskErr)
                      | Result.Ok (updatedSim, trades) =>
                          let
                            val outSeq1 = GatewaySession.nextOutSeq sess
                            val acceptReport : BinaryCodec.binary_execution_report = {
                              seq = outSeq1,
                              timestamp = now,
                              client_id = #client_id req,
                              symbol = #symbol req,
                              order_id = #order_id req,
                              match_id = 0,
                              status = Types.Accepted,
                              price = #price req,
                              qty = #qty req,
                              leaves_qty = #qty req,
                              cum_qty = 0
                            }
                            val acceptBuf = BinaryCodec.encodeExecutionReport acceptReport

                            val tradeReports =
                                List.map (fn (t : Trade.trade) =>
                                  let
                                    val tSeq = GatewaySession.nextOutSeq sess
                                    val rep : BinaryCodec.binary_execution_report = {
                                      seq = tSeq,
                                      timestamp = now,
                                      client_id = #client_id req,
                                      symbol = #symbol t,
                                      order_id = #order_id req,
                                      match_id = #match_id t,
                                      status = Types.PartiallyFilled,
                                      price = #price t,
                                      qty = #qty t,
                                      leaves_qty = 0,
                                      cum_qty = #qty t
                                    }
                                  in
                                    BinaryCodec.encodeExecutionReport rep
                                  end) trades

                            val updatedGw = { sim = updatedSim }
                          in
                            Result.ok (updatedGw, sess, acceptBuf :: tradeReports)
                          end
                  end

  fun handleFixMessage (gw : gateway) (sess : GatewaySession.session) (rawMsg : string) (now : Types.timestamp_ns) =
      case FixMessage.parse rawMsg #"|" of
          Result.Err e => Result.err ("FIX parsing error: " ^ e)
        | Result.Ok fixMsg =>
            let
              val msgType = #msg_type fixMsg
            in
              if msgType <> "D" then
                Result.err ("Unsupported FIX MsgType: " ^ msgType)
              else
                case (FixMessage.getRequiredField fixMsg 55, (* Symbol *)
                      FixMessage.getRequiredField fixMsg 54, (* Side *)
                      FixMessage.getLargeIntField fixMsg 38, (* Qty *)
                      FixMessage.getRequiredField fixMsg 44, (* Price *)
                      FixMessage.getLargeIntField fixMsg 11) of (* ClOrdID *)
                    (Result.Ok sym, Result.Ok sideStr, Result.Ok qty, Result.Ok priceStr, Result.Ok clOrdId) =>
                      (case (Types.sideFromString sideStr, Types.priceFromString priceStr) of
                           (SOME side, SOME p) =>
                             let
                               val inSeq = #msg_seq_num fixMsg
                             in
                               case GatewaySession.verifyInSeq sess inSeq of
                                   Result.Err seqErr => Result.err seqErr
                                 | Result.Ok () =>
                                     let
                                       val ord = Order.create {
                                         id = clOrdId,
                                         client_id = #sender_comp_id fixMsg,
                                         symbol = sym,
                                         side = side,
                                         order_type = Types.Limit { price = p },
                                         time_in_force = Types.GTC,
                                         price = p,
                                         qty = qty,
                                         timestamp = now
                                       }
                                     in
                                       case ExchangeSim.submitOrder (#sim gw) ord of
                                           Result.Err riskErr => Result.err riskErr
                                         | Result.Ok (updatedSim, _) =>
                                             let
                                               val outSeq = GatewaySession.nextOutSeq sess
                                               val replyFix = FixMessage.create "8" "EXCHANGE" (#sender_comp_id fixMsg) outSeq "20261118-12:00:00.000" [
                                                 (37, LargeInt.toString clOrdId), (* OrderID *)
                                                 (11, LargeInt.toString clOrdId), (* ClOrdID *)
                                                 (150, "0"),                       (* ExecType: New *)
                                                 (39, "0"),                        (* OrdStatus: New *)
                                                 (55, sym),
                                                 (54, sideStr),
                                                 (38, LargeInt.toString qty),
                                                 (44, priceStr)
                                               ]
                                               val serializedReply = FixMessage.serialize replyFix #"|"
                                             in
                                               Result.ok ({ sim = updatedSim }, sess, [serializedReply])
                                             end
                                     end
                             end
                         | _ => Result.err "Invalid Side or Price in FIX message")
                  | _ => Result.err "Missing mandatory FIX tags for NewOrderSingle"
            end
end
