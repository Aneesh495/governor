(* price_level.sml
 * Implementation of PriceLevel aggregation and FIFO queue manipulation.
 *)

structure PriceLevel :> PRICE_LEVEL =
struct
  type price_level = {
    price : Types.price,
    total_qty : Types.qty,
    order_count : int,
    orders : Order.order FifoQueue.queue
  }

  fun create (p : Types.price) : price_level =
      {
        price = p,
        total_qty = 0,
        order_count = 0,
        orders = FifoQueue.empty
      }

  fun isEmpty ({ order_count = 0, ... } : price_level) = true
    | isEmpty _ = false

  fun addOrder (lvl : price_level) (ord : Order.order) : price_level =
      {
        price = #price lvl,
        total_qty = #total_qty lvl + #leaves_qty ord,
        order_count = #order_count lvl + 1,
        orders = FifoQueue.pushBack (#orders lvl) ord
      }

  fun peekFront (lvl : price_level) : Order.order option =
      FifoQueue.peekFront (#orders lvl)

  fun popFront (lvl : price_level) : (Order.order * price_level) option =
      case FifoQueue.popFront (#orders lvl) of
          NONE => NONE
        | SOME (ord, rest) =>
            SOME (ord, {
              price = #price lvl,
              total_qty = #total_qty lvl - #leaves_qty ord,
              order_count = #order_count lvl - 1,
              orders = rest
            })

  fun removeOrder (lvl : price_level) (targetId : Types.order_id) : (Order.order * price_level) option =
      let
        val allOrders = FifoQueue.toList (#orders lvl)
        fun findAndFilter ([], _) = NONE
          | findAndFilter (ord :: rest, acc) =
              if #id ord = targetId then
                let
                  val remainingList = List.rev acc @ rest
                  val newTotal = #total_qty lvl - #leaves_qty ord
                  val newLvl = {
                    price = #price lvl,
                    total_qty = if newTotal < 0 then 0 else newTotal,
                    order_count = #order_count lvl - 1,
                    orders = FifoQueue.fromList remainingList
                  }
                in
                  SOME (ord, newLvl)
                end
              else
                findAndFilter (rest, ord :: acc)
      in
        findAndFilter (allOrders, [])
      end

  fun updateFrontOrder (lvl : price_level) (updatedOrd : Order.order) : price_level =
      case FifoQueue.popFront (#orders lvl) of
          NONE => addOrder lvl updatedOrd
        | SOME (oldOrd, restQueue) =>
            let
              val oldLeaves = #leaves_qty oldOrd
              val newLeaves = #leaves_qty updatedOrd
              val newTotal = #total_qty lvl - oldLeaves + newLeaves
            in
              if newLeaves > 0 then
                {
                  price = #price lvl,
                  total_qty = newTotal,
                  order_count = #order_count lvl,
                  (* Push back to front by rebuilding or prepending *)
                  orders = FifoQueue.fromList (updatedOrd :: FifoQueue.toList restQueue)
                }
              else
                {
                  price = #price lvl,
                  total_qty = #total_qty lvl - oldLeaves,
                  order_count = #order_count lvl - 1,
                  orders = restQueue
                }
            end

  fun getOrders (lvl : price_level) : Order.order list =
      FifoQueue.toList (#orders lvl)

  fun toString (lvl : price_level) : string =
      "PriceLevel(price=" ^ Types.priceToString (#price lvl) ^
      ",qty=" ^ LargeInt.toString (#total_qty lvl) ^
      ",orders=" ^ Int.toString (#order_count lvl) ^ ")"
end
