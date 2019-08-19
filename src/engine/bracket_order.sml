(* bracket_order.sml
 * Implementation of bracket order manager.
 *)

structure BracketOrder :> BRACKET_ORDER =
struct
  type bracket_id = LargeInt.int
  type order_id = Types.order_id

  type bracket_order = {
    id : bracket_id,
    entry_order : Order.order,
    take_profit_price : Types.price,
    stop_loss_price : Types.price,
    active : bool ref
  }

  structure IdKey = struct
    type ord_key = LargeInt.int
    val compare = LargeInt.compare
  end

  structure IdMap = RedBlackMapFn (IdKey)

  type manager = {
    brackets : bracket_order IdMap.map,
    entry_to_bracket : bracket_id IdMap.map,
    next_exit_order_id : LargeInt.int ref
  }

  fun create () : manager =
      {
        brackets = IdMap.empty,
        entry_to_bracket = IdMap.empty,
        next_exit_order_id = ref 900000
      }

  fun registerBracket (mgr : manager) (id : bracket_id) (entry : Order.order) (tp : Types.price) (sl : Types.price) : manager =
      let
        val bracket : bracket_order = {
          id = id,
          entry_order = entry,
          take_profit_price = tp,
          stop_loss_price = sl,
          active = ref true
        }
        val brackets' = IdMap.insert (#brackets mgr, id, bracket)
        val entryMap' = IdMap.insert (#entry_to_bracket mgr, #id entry, id)
      in
        {
          brackets = brackets',
          entry_to_bracket = entryMap',
          next_exit_order_id = #next_exit_order_id mgr
        }
      end

  fun allocExitId (mgr : manager) : order_id =
      let
        val cur = !(#next_exit_order_id mgr)
      in
        #next_exit_order_id mgr := cur + 1;
        cur
      end

  fun onEntryFilled (mgr : manager) (entryId : order_id) (ts : Types.timestamp_ns)
      : (manager * (Order.order * Order.order) option) =
      case IdMap.find (#entry_to_bracket mgr, entryId) of
          NONE => (mgr, NONE)
        | SOME bracketId =>
            (case IdMap.find (#brackets mgr, bracketId) of
                 NONE => (mgr, NONE)
               | SOME bracket =>
                   let
                     val entry = #entry_order bracket
                     val exitSide = Types.oppositeSide (#side entry)
                     val exitQty = #initial_qty entry

                     val tpId = allocExitId mgr
                     val slId = allocExitId mgr

                     val tpOrder = Order.create {
                       id = tpId,
                       client_id = #client_id entry,
                       symbol = #symbol entry,
                       side = exitSide,
                       order_type = Types.Limit { price = #take_profit_price bracket },
                       time_in_force = Types.GTC,
                       price = #take_profit_price bracket,
                       qty = exitQty,
                       timestamp = ts
                     }

                     val slOrder = Order.create {
                       id = slId,
                       client_id = #client_id entry,
                       symbol = #symbol entry,
                       side = exitSide,
                       order_type = Types.StopLoss { stop_price = #stop_loss_price bracket },
                       time_in_force = Types.GTC,
                       price = #stop_loss_price bracket,
                       qty = exitQty,
                       timestamp = ts
                     }

                     val (brackets', _) = IdMap.remove (#brackets mgr, bracketId)
                     val (entryMap', _) = IdMap.remove (#entry_to_bracket mgr, entryId)
                     val mgr' = {
                       brackets = brackets',
                       entry_to_bracket = entryMap',
                       next_exit_order_id = #next_exit_order_id mgr
                     }
                   in
                     (mgr', SOME (tpOrder, slOrder))
                   end)

  fun onEntryCancelled (mgr : manager) (entryId : order_id) : manager =
      case IdMap.find (#entry_to_bracket mgr, entryId) of
          NONE => mgr
        | SOME bracketId =>
            let
              val (brackets', _) = IdMap.remove (#brackets mgr, bracketId)
              val (entryMap', _) = IdMap.remove (#entry_to_bracket mgr, entryId)
            in
              {
                brackets = brackets',
                entry_to_bracket = entryMap',
                next_exit_order_id = #next_exit_order_id mgr
              }
            end

  fun activeBracketCount (mgr : manager) : int =
      IdMap.numItems (#brackets mgr)
end
