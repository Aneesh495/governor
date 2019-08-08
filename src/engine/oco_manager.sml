(* oco_manager.sml
 * Implementation of One-Cancels-the-Other (OCO) order pairs.
 *)

structure OcoManager :> OCO_MANAGER =
struct
  type oco_id = LargeInt.int
  type order_id = Types.order_id

  type oco_pair = {
    id : oco_id,
    first_order_id : order_id,
    second_order_id : order_id,
    symbol : Types.symbol_id,
    created_at : Types.timestamp_ns
  }

  structure IdKey = struct
    type ord_key = LargeInt.int
    val compare = LargeInt.compare
  end

  structure IdMap = RedBlackMapFn (IdKey)

  type manager = {
    pairs : oco_pair IdMap.map,
    order_to_pair : oco_id IdMap.map
  }

  fun create () : manager =
      {
        pairs = IdMap.empty,
        order_to_pair = IdMap.empty
      }

  fun registerPair (mgr : manager) (id : oco_id) (ord1 : order_id) (ord2 : order_id) (sym : Types.symbol_id) (ts : Types.timestamp_ns) : manager =
      let
        val pair : oco_pair = {
          id = id,
          first_order_id = ord1,
          second_order_id = ord2,
          symbol = sym,
          created_at = ts
        }
        val pairs' = IdMap.insert (#pairs mgr, id, pair)
        val m1 = IdMap.insert (#order_to_pair mgr, ord1, id)
        val m2 = IdMap.insert (m1, ord2, id)
      in
        {
          pairs = pairs',
          order_to_pair = m2
        }
      end

  fun findSibling (mgr : manager) (ordId : order_id) : order_id option =
      case IdMap.find (#order_to_pair mgr, ordId) of
          NONE => NONE
        | SOME pairId =>
            (case IdMap.find (#pairs mgr, pairId) of
                 NONE => NONE
               | SOME pair =>
                   if #first_order_id pair = ordId then
                     SOME (#second_order_id pair)
                   else
                     SOME (#first_order_id pair))

  fun removePair (mgr : manager) (pairId : oco_id) : manager =
      case IdMap.find (#pairs mgr, pairId) of
          NONE => mgr
        | SOME pair =>
            let
              val (pairs', _) = IdMap.remove (#pairs mgr, pairId)
              val (m1, _) = IdMap.remove (#order_to_pair mgr, #first_order_id pair)
              val (m2, _) = IdMap.remove (m1, #second_order_id pair)
            in
              {
                pairs = pairs',
                order_to_pair = m2
              }
            end

  fun onOrderFilled (mgr : manager) (ordId : order_id) : (manager * order_id option) =
      case findSibling mgr ordId of
          NONE => (mgr, NONE)
        | SOME siblingId =>
            let
              val pairId = valOf (IdMap.find (#order_to_pair mgr, ordId))
              val mgr' = removePair mgr pairId
            in
              (mgr', SOME siblingId)
            end

  fun onOrderCancelled (mgr : manager) (ordId : order_id) : (manager * order_id option) =
      onOrderFilled mgr ordId

  fun activePairsCount (mgr : manager) : int =
      IdMap.numItems (#pairs mgr)
end
