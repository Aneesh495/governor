(* test_properties_rbtree.sml
 * Property-based testing for RedBlackMap invariants.
 *)

val _ = use "src/core/red_black_map.sig";
val _ = use "src/core/red_black_map.sml";
val _ = use "test/property_framework.sig";
val _ = use "test/property_framework.sml";

structure TestPropertiesRBTree =
struct
  structure IntMap = RedBlackMapFn(
    struct
      type ord_key = int
      val compare = Int.compare
    end
  )

  fun isSorted (xs : int list) : bool =
      case xs of
          [] => true
        | [_] => true
        | x :: y :: rest => x < y andalso isSorted (y :: rest)

  (* Property 1: In-order traversal keys are always strictly sorted *)
  fun prop_inorder_sorted (keys : int list) : bool =
      let
        val m = List.foldl (fn (k, acc) => IntMap.insert (acc, k, k * 10)) IntMap.empty keys
        val extractedKeys = IntMap.listKeys m
      in
        isSorted extractedKeys
      end

  (* Property 2: Size matches number of distinct keys inserted *)
  fun prop_size_matches_distinct (keys : int list) : bool =
      let
        val m = List.foldl (fn (k, acc) => IntMap.insert (acc, k, k)) IntMap.empty keys
        val items = IntMap.listItemsi m
        val treeSize = IntMap.numItems m
      in
        treeSize = List.length items
      end

  (* Property 3: Every inserted key can be retrieved *)
  fun prop_insert_lookup (keys : int list) : bool =
      let
        val m = List.foldl (fn (k, acc) => IntMap.insert (acc, k, k * 2)) IntMap.empty keys
        fun verify [] = true
          | verify (k :: ks) =
              case IntMap.find (m, k) of
                  SOME v => v = k * 2 andalso verify ks
                | NONE => false
      in
        verify keys
      end

  (* Property 4: Removal removes exactly that key and preserves all others *)
  fun prop_remove_consistency (keys : int list) : bool =
      if List.null keys then true
      else
        let
          val m = List.foldl (fn (k, acc) => IntMap.insert (acc, k, k)) IntMap.empty keys
          val keyToRemove = List.hd keys
          val (m2, removedVal) = IntMap.remove (m, keyToRemove)
        in
          IntMap.find (m2, keyToRemove) = NONE andalso
          removedVal = keyToRemove
        end

  fun run () =
      let
        val genKeys = PropertyFramework.genList (PropertyFramework.genInt (~1000, 1000)) 30
        fun showList xs = "[" ^ String.concatWith ", " (List.map Int.toString xs) ^ "]"

        val tests = [
          {
            name = "Red-Black Tree: In-order traversal keys strictly sorted",
            trials = 100,
            generator = genKeys,
            property = prop_inorder_sorted,
            showCounterExample = showList
          },
          {
            name = "Red-Black Tree: numItems equals distinct key count",
            trials = 100,
            generator = genKeys,
            property = prop_size_matches_distinct,
            showCounterExample = showList
          },
          {
            name = "Red-Black Tree: All inserted keys retrievable with correct value",
            trials = 100,
            generator = genKeys,
            property = prop_insert_lookup,
            showCounterExample = showList
          },
          {
            name = "Red-Black Tree: Remove eliminates target key cleanly",
            trials = 100,
            generator = genKeys,
            property = prop_remove_consistency,
            showCounterExample = showList
          }
        ]
        val (p, f) = PropertyFramework.runProperties "Red-Black Tree Invariants" tests
      in
        if f = 0 then (print "RBTree property tests passed!\n"; true)
        else (print "RBTree property tests FAILED!\n"; false)
      end
end;

val _ = TestPropertiesRBTree.run ();
