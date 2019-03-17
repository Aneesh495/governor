(* red_black_map.sml
 * Pure functional Red-Black tree map functor implementation.
 *)

functor RedBlackMapFn (K : ORDERED_KEY) : RED_BLACK_MAP =
struct
  type ord_key = K.ord_key

  datatype color = Red | Black

  datatype 'a tree =
      Empty
    | Node of color * 'a tree * ord_key * 'a * 'a tree

  type 'a map = 'a tree * int

  val empty : 'a map = (Empty, 0)

  fun isEmpty (_, sz) = (sz = 0)

  fun numItems (_, sz) = sz

  fun balance (Black, Node (Red, Node (Red, a, xk, xv, b), yk, yv, c), zk, zv, d) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, Node (Red, a, xk, xv, Node (Red, b, yk, yv, c)), zk, zv, d) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, a, xk, xv, Node (Red, Node (Red, b, yk, yv, c), zk, zv, d)) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, a, xk, xv, Node (Red, b, yk, yv, Node (Red, c, zk, zv, d))) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (c, a, k, v, b) =
        Node (c, a, k, v, b)

  fun insertWith comb ((root, sz) : 'a map, key : ord_key, value : 'a) : 'a map =
      let
        val inserted = ref true
        fun ins Empty = (inserted := true; Node (Red, Empty, key, value, Empty))
          | ins (Node (color, left, k, v, right)) =
              case K.compare (key, k) of
                  LESS => balance (color, ins left, k, v, right)
                | GREATER => balance (color, left, k, v, ins right)
                | EQUAL => (inserted := false; Node (color, left, k, comb (value, v), right))

        val newTree =
            case ins root of
                Node (_, left, k, v, right) => Node (Black, left, k, v, right)
              | Empty => Empty
        val newSz = if !inserted then sz + 1 else sz
      in
        (newTree, newSz)
      end

  fun insert (m, k, v) = insertWith (fn (newV, _) => newV) (m, k, v)

  fun find ((root, _) : 'a map, key : ord_key) : 'a option =
      let
        fun search Empty = NONE
          | search (Node (_, left, k, v, right)) =
              case K.compare (key, k) of
                  LESS => search left
                | GREATER => search right
                | EQUAL => SOME v
      in
        search root
      end

  fun lookup (m, k) =
      case find (m, k) of
          SOME v => v
        | NONE => raise Fail "RedBlackMap.lookup: key not found"

  fun inDomain (m, k) =
      case find (m, k) of
          SOME _ => true
        | NONE => false

  fun minItem ((root, _) : 'a map) =
      let
        fun loop (Node (_, Empty, k, v, _)) = SOME (k, v)
          | loop (Node (_, left, _, _, _)) = loop left
          | loop Empty = NONE
      in
        loop root
      end

  fun minKey m =
      case minItem m of
          SOME (k, _) => SOME k
        | NONE => NONE

  fun maxItem ((root, _) : 'a map) =
      let
        fun loop (Node (_, _, k, v, Empty)) = SOME (k, v)
          | loop (Node (_, _, _, _, right)) = loop right
          | loop Empty = NONE
      in
        loop root
      end

  fun maxKey m =
      case maxItem m of
          SOME (k, _) => SOME k
        | NONE => NONE

  fun listItemsi ((root, _) : 'a map) =
      let
        fun inorder Empty acc = acc
          | inorder (Node (_, left, k, v, right)) acc =
              inorder left ((k, v) :: inorder right acc)
      in
        inorder root []
      end

  fun listItems m = List.map #2 (listItemsi m)

  fun listKeys m = List.map #1 (listItemsi m)

  fun foldli f init m =
      List.foldl (fn ((k, v), acc) => f (k, v, acc)) init (listItemsi m)

  fun foldri f init m =
      List.foldr (fn ((k, v), acc) => f (k, v, acc)) init (listItemsi m)

  fun appi f m =
      List.app f (listItemsi m)

  fun mapi f m =
      List.foldl (fn ((k, v), acc) => insert (acc, k, f (k, v))) empty (listItemsi m)

  (* Deletion helpers for functional red-black tree *)
  datatype 'a bubble =
      BTree of 'a tree
    | DoubleBlack of 'a tree

  fun remove ((root, sz) : 'a map, key : ord_key) : 'a map * 'a =
      let
        val foundVal = ref NONE

        fun delMin (Node (Red, Empty, k, v, r)) = (k, v, BTree r)
          | delMin (Node (Black, Empty, k, v, r)) =
              (case r of
                   Node (Red, rl, rk, rv, rr) => (k, v, BTree (Node (Black, rl, rk, rv, rr)))
                 | _ => (k, v, DoubleBlack r))
          | delMin (Node (c, left, k, v, right)) =
              let
                val (mk, mv, bLeft) = delMin left
              in
                case bLeft of
                    BTree l' => (mk, mv, BTree (Node (c, l', k, v, right)))
                  | DoubleBlack l' => (mk, mv, fixLeft (c, l', k, v, right))
              end
          | delMin Empty = raise Fail "delMin on Empty"

        and fixLeft (Black, l, k, v, Node (Red, rl, rk, rv, rr)) =
              (case fixLeft (Red, l, k, v, rl) of
                   BTree t => BTree (Node (Black, t, rk, rv, rr))
                 | DoubleBlack t => BTree (balance (Black, t, rk, rv, rr)))
          | fixLeft (c, l, k, v, Node (Black, rl, rk, rv, rr)) =
              (case (rl, rr) of
                   (Node (Red, rll, rlk, rlv, rlr), _) =>
                     BTree (balance (c, Node (Black, l, k, v, rll), rlk, rlv, Node (Black, rlr, rk, rv, rr)))
                 | (_, Node (Red, rrl, rrk, rrv, rrr)) =>
                     BTree (balance (c, Node (Black, l, k, v, rl), rk, rv, Node (Black, rrl, rrk, rrv, rrr)))
                 | _ =>
                     (case c of
                          Red => BTree (Node (Black, l, k, v, Node (Red, rl, rk, rv, rr)))
                        | Black => DoubleBlack (Node (Black, l, k, v, Node (Red, rl, rk, rv, rr)))))
          | fixLeft _ = raise Fail "fixLeft pattern"

        fun del Empty = (BTree Empty)
          | del (Node (c, left, k, v, right)) =
              case K.compare (key, k) of
                  LESS =>
                    (case del left of
                         BTree l' => BTree (Node (c, l', k, v, right))
                       | DoubleBlack l' => fixLeft (c, l', k, v, right))
                | GREATER =>
                    (case del right of
                         BTree r' => BTree (Node (c, left, k, v, r'))
                       | DoubleBlack r' => fixRight (c, left, k, v, r'))
                | EQUAL =>
                    (foundVal := SOME v;
                     case (left, right) of
                         (Empty, Empty) =>
                           if c = Red then BTree Empty else DoubleBlack Empty
                       | (Empty, Node (Red, rl, rk, rv, rr)) =>
                           BTree (Node (Black, rl, rk, rv, rr))
                       | (Node (Red, ll, lk, lv, lr), Empty) =>
                           BTree (Node (Black, ll, lk, lv, lr))
                       | (_, _) =>
                           let
                             val (succK, succV, bRight) = delMin right
                           in
                             case bRight of
                                 BTree r' => BTree (Node (c, left, succK, succV, r'))
                               | DoubleBlack r' => fixRight (c, left, succK, succV, r')
                           end)

        and fixRight (Black, Node (Red, ll, lk, lv, lr), k, v, r) =
              (case fixRight (Red, lr, k, v, r) of
                   BTree t => BTree (Node (Black, ll, lk, lv, t))
                 | DoubleBlack t => BTree (balance (Black, ll, lk, lv, t)))
          | fixRight (c, Node (Black, ll, lk, lv, lr), k, v, r) =
              (case (ll, lr) of
                   (Node (Red, lll, llk, llv, llr), _) =>
                     BTree (balance (c, Node (Black, lll, llk, llv, llr), lk, lv, Node (Black, lr, k, v, r)))
                 | (_, Node (Red, lrl, lrk, lrv, lrr)) =>
                     BTree (balance (c, Node (Black, ll, lk, lv, lrl), lrk, lrv, Node (Black, lrr, k, v, r)))
                 | _ =>
                     (case c of
                          Red => BTree (Node (Black, Node (Red, ll, lk, lv, lr), k, v, r))
                        | Black => DoubleBlack (Node (Black, Node (Red, ll, lk, lv, lr), k, v, r))))
          | fixRight _ = raise Fail "fixRight pattern"

        val treeResult =
            case del root of
                BTree t => t
              | DoubleBlack t => t
      in
        case !foundVal of
            SOME v => ((treeResult, sz - 1), v)
          | NONE => raise Fail "RedBlackMap.remove: key not found"
      end

  fun delete (m, k) = #1 (remove (m, k)) handle Fail _ => m
end
