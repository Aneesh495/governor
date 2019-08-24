(* audit_trail.sig
 * Consolidated Audit Trail (CAT) regulatory-grade event recording and query journal.
 *)

signature AUDIT_TRAIL =
sig
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

  type trail

  val create : unit -> trail
  val record : trail -> cat_event_type -> timestamp_ns -> (trail * cat_record)

  val totalRecords : trail -> int
  val lookupBySequence : trail -> seq_num -> cat_record option
  val getRange : trail -> seq_num -> seq_num -> cat_record list
  val filterByOrder : trail -> Types.order_id -> cat_record list
  val formatRecord : cat_record -> string
end
