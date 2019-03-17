(* result.sig
 * Monadic result type for deterministic error handling without exceptions.
 *)

signature RESULT =
sig
  datatype ('a, 'e) result =
      Ok of 'a
    | Err of 'e

  val ok : 'a -> ('a, 'e) result
  val err : 'e -> ('a, 'e) result

  val isOk : ('a, 'e) result -> bool
  val isErr : ('a, 'e) result -> bool

  val map : ('a -> 'b) -> ('a, 'e) result -> ('b, 'e) result
  val mapErr : ('e -> 'f) -> ('a, 'e) result -> ('a, 'f) result
  val bind : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result

  val getOrElse : 'a -> ('a, 'e) result -> 'a
  val unwrap : ('a, string) result -> 'a

  val fold : ('a -> 'c) -> ('e -> 'c) -> ('a, 'e) result -> 'c
  val sequence : ('a, 'e) result list -> ('a list, 'e) result
end
