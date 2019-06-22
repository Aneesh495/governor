(* property_framework.sig
 * Lightweight QuickCheck-style property-based testing engine for Standard ML.
 *)

signature PROPERTY_FRAMEWORK =
sig
  type rng

  val initRng : Word32.word -> rng
  val nextWord32 : rng -> Word32.word
  val nextIntRange : rng -> int * int -> int
  val nextLargeIntRange : rng -> LargeInt.int * LargeInt.int -> LargeInt.int
  val nextBool : rng -> bool

  (* Generators *)
  type 'a gen = rng -> 'a

  val genInt : int * int -> int gen
  val genLargeInt : LargeInt.int * LargeInt.int -> LargeInt.int gen
  val genBool : bool gen
  val genList : 'a gen -> int -> ('a list) gen
  val genChoose : 'a list -> 'a gen

  (* Property Testing Runner *)
  val checkProperty :
      {
        name : string,
        trials : int,
        generator : 'a gen,
        property : 'a -> bool,
        showCounterExample : 'a -> string
      } -> bool

  val runProperties :
      string ->
      ({
        name : string,
        trials : int,
        generator : 'a gen,
        property : 'a -> bool,
        showCounterExample : 'a -> string
      } list) -> int * int  (* returns (passed, failed) *)
end
