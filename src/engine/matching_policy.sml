(* matching_policy.sml
 * Implementation of matching allocation policies.
 *)

structure MatchingPolicy :> MATCHING_POLICY =
struct
  datatype policy =
      Fifo
    | ProRata

  fun allocate Fifo (neededQty : Types.qty) (orders : Order.order list) =
      let
        fun loop ([], _) = []
          | loop (ord :: rest, rem) =
              if rem <= 0 then []
              else
                let
                  val avail = #leaves_qty ord
                  val fill = if avail <= rem then avail else rem
                in
                  (ord, fill) :: loop (rest, rem - fill)
                end
      in
        loop (orders, neededQty)
      end
    | allocate ProRata (neededQty : Types.qty) (orders : Order.order list) =
      let
        val totalAvail = List.foldl (fn (ord, acc) => #leaves_qty ord + acc) 0 orders
      in
        if totalAvail <= neededQty then
          List.map (fn ord => (ord, #leaves_qty ord)) orders
        else
          let
            (* Initial proportional shares *)
            val rawShares =
                List.map (fn ord =>
                  let
                    val avail = #leaves_qty ord
                    val share = (neededQty * avail) div totalAvail
                  in
                    (ord, share)
                  end) orders

            val allocatedTotal = List.foldl (fn ((_, q), acc) => q + acc) 0 rawShares
            val remainder = neededQty - allocatedTotal

            (* Distribute remainder 1 lot at a time in FIFO arrival order *)
            fun distributeRemainder ([], _) = []
              | distributeRemainder (items, rem) =
                  if rem <= 0 then items
                  else
                    case items of
                        [] => []
                      | (ord, q) :: xs =>
                          let
                            val avail = #leaves_qty ord
                            val canAdd = if q < avail then 1 else 0
                          in
                            (ord, q + canAdd) :: distributeRemainder (xs, rem - canAdd)
                          end
          in
            distributeRemainder (rawShares, remainder)
          end
      end

  fun policyToString Fifo = "FIFO"
    | policyToString ProRata = "PRO_RATA"
end
