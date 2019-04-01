(* matching_policy.sig
 * Order allocation policies at a price level: Price-Time (FIFO) and Pro-Rata.
 *)

signature MATCHING_POLICY =
sig
  datatype policy =
      Fifo
    | ProRata

  (* Computes allocation for incoming aggressive quantity against resting orders at a price level *)
  val allocate : policy -> Types.qty -> Order.order list -> (Order.order * Types.qty) list
  val policyToString : policy -> string
end
