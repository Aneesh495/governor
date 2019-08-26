(* audit_trail.sml
 * Implementation of Consolidated Audit Trail (CAT) event logging.
 *)

structure AuditTrail :> AUDIT_TRAIL =
struct
  type seq_num = LargeInt.int
  type timestamp_ns = Types.timestamp_ns

  datatype cat_event_type =
      CatOrderAccepted of {
        order_id : Types.order_id,
        client_id : Types.client_id,
        symbol : Types.symbol_id,
        side : Types.side,
        price : Types.price,
        qty : Types.qty
      }
    | CatOrderModified of {
        order_id : Types.order_id,
        old_qty : Types.qty,
        new_qty : Types.qty,
        old_price : Types.price,
        new_price : Types.price
      }
    | CatOrderCancelled of {
        order_id : Types.order_id,
        cancelled_qty : Types.qty,
        reason : string
      }
    | CatTradeExecuted of {
        match_id : Types.match_id,
        maker_order_id : Types.order_id,
        taker_order_id : Types.order_id,
        symbol : Types.symbol_id,
        price : Types.price,
        qty : Types.qty
      }
    | CatHaltTriggered of {
        symbol : Types.symbol_id,
        trigger_price : Types.price,
        state : string
      }

  type cat_record = {
    sequence_number : seq_num,
    timestamp : timestamp_ns,
    event : cat_event_type
  }

  structure SeqKey = struct
    type ord_key = seq_num
    val compare = LargeInt.compare
  end

  structure SeqMap = RedBlackMapFn (SeqKey)

  type trail = {
    records : cat_record SeqMap.map,
    next_seq : seq_num ref
  }

  fun create () : trail =
      {
        records = SeqMap.empty,
        next_seq = ref (1 : seq_num)
      }

  fun record (t : trail) (ev : cat_event_type) (ts : timestamp_ns) : (trail * cat_record) =
      let
        val seq = !(#next_seq t)
        val _ = #next_seq t := seq + 1
        val recItem : cat_record = {
          sequence_number = seq,
          timestamp = ts,
          event = ev
        }
        val records' = SeqMap.insert (#records t, seq, recItem)
        val t' = {
          records = records',
          next_seq = #next_seq t
        }
      in
        (t', recItem)
      end

  fun totalRecords (t : trail) : int =
      SeqMap.numItems (#records t)

  fun lookupBySequence (t : trail) (seq : seq_num) : cat_record option =
      SeqMap.find (#records t, seq)

  fun getRange (t : trail) (startSeq : seq_num) (endSeq : seq_num) : cat_record list =
      let
        val allRecs = SeqMap.listItems (#records t)
      in
        List.filter (fn r => #sequence_number r >= startSeq andalso #sequence_number r <= endSeq) allRecs
      end

  fun filterByOrder (t : trail) (targetId : Types.order_id) : cat_record list =
      let
        val allRecs = SeqMap.listItems (#records t)
        fun matchesEvent ev =
            case ev of
                CatOrderAccepted { order_id, ... } => order_id = targetId
              | CatOrderModified { order_id, ... } => order_id = targetId
              | CatOrderCancelled { order_id, ... } => order_id = targetId
              | CatTradeExecuted { maker_order_id, taker_order_id, ... } =>
                  maker_order_id = targetId orelse taker_order_id = targetId
              | CatHaltTriggered _ => false
      in
        List.filter (fn r => matchesEvent (#event r)) allRecs
      end

  fun formatRecord (r : cat_record) : string =
      let
        val seqStr = LargeInt.toString (#sequence_number r)
        val tsStr = LargeInt.toString (#timestamp r)
        val evDesc =
            case #event r of
                CatOrderAccepted { order_id, client_id, symbol, side, price, qty } =>
                  "ACCEPTED ord=" ^ LargeInt.toString order_id ^ " client=" ^ client_id ^
                  " sym=" ^ symbol ^ " side=" ^ Types.sideToString side ^
                  " p=" ^ Types.priceToString price ^ " q=" ^ LargeInt.toString qty
              | CatOrderModified { order_id, old_qty, new_qty, old_price, new_price } =>
                  "MODIFIED ord=" ^ LargeInt.toString order_id ^
                  " q=" ^ LargeInt.toString old_qty ^ "->" ^ LargeInt.toString new_qty ^
                  " p=" ^ Types.priceToString old_price ^ "->" ^ Types.priceToString new_price
              | CatOrderCancelled { order_id, cancelled_qty, reason } =>
                  "CANCELLED ord=" ^ LargeInt.toString order_id ^ " q=" ^ LargeInt.toString cancelled_qty ^ " reason=" ^ reason
              | CatTradeExecuted { match_id, maker_order_id, taker_order_id, symbol, price, qty } =>
                  "TRADE match=" ^ LargeInt.toString match_id ^ " maker=" ^ LargeInt.toString maker_order_id ^
                  " taker=" ^ LargeInt.toString taker_order_id ^ " sym=" ^ symbol ^
                  " p=" ^ Types.priceToString price ^ " q=" ^ LargeInt.toString qty
              | CatHaltTriggered { symbol, trigger_price, state } =>
                  "HALT sym=" ^ symbol ^ " state=" ^ state ^ " p=" ^ Types.priceToString trigger_price
      in
        "[CAT #" ^ seqStr ^ " @ " ^ tsStr ^ "] " ^ evDesc
      end
end
