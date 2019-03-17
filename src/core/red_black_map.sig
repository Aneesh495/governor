(* red_black_map.sig
 * Pure functional Red-Black tree map with guaranteed O(log N) operations.
 *)

signature ORDERED_KEY =
sig
  type ord_key
  val compare : ord_key * ord_key -> order
end

signature RED_BLACK_MAP =
sig
  type ord_key
  type 'a map

  val empty : 'a map
  val isEmpty : 'a map -> bool
  val numItems : 'a map -> int

  val insert : 'a map * ord_key * 'a -> 'a map
  val insertWith : ('a * 'a -> 'a) -> 'a map * ord_key * 'a -> 'a map

  val find : 'a map * ord_key -> 'a option
  val lookup : 'a map * ord_key -> 'a
  val inDomain : 'a map * ord_key -> bool

  val remove : 'a map * ord_key -> 'a map * 'a
  val delete : 'a map * ord_key -> 'a map

  val minKey : 'a map -> ord_key option
  val maxKey : 'a map -> ord_key option

  val minItem : 'a map -> (ord_key * 'a) option
  val maxItem : 'a map -> (ord_key * 'a) option

  val listItemsi : 'a map -> (ord_key * 'a) list
  val listItems : 'a map -> 'a list
  val listKeys : 'a map -> ord_key list

  val foldli : (ord_key * 'a * 'b -> 'b) -> 'b -> 'a map -> 'b
  val foldri : (ord_key * 'a * 'b -> 'b) -> 'b -> 'a map -> 'b
  val mapi : (ord_key * 'a -> 'b) -> 'a map -> 'b map
  val appi : (ord_key * 'a -> unit) -> 'a map -> unit
end
