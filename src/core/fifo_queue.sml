(* fifo_queue.sml
 * Pure functional double-list FIFO queue implementation.
 *)

structure FifoQueue :> FIFO_QUEUE =
struct
  datatype 'a queue = Q of { front : 'a list, back : 'a list, size : int }

  val empty = Q { front = [], back = [], size = 0 }

  fun isEmpty (Q { size = 0, ... }) = true
    | isEmpty _ = false

  fun length (Q { size, ... }) = size

  fun pushBack (Q { front, back, size }) x =
      Q { front = front, back = x :: back, size = size + 1 }

  fun popFront (Q { front = [], back = [], ... }) = NONE
    | popFront (Q { front = x :: xs, back, size }) =
        SOME (x, Q { front = xs, back = back, size = size - 1 })
    | popFront (Q { front = [], back, size }) =
        case List.rev back of
            [] => NONE
          | x :: xs => SOME (x, Q { front = xs, back = [], size = size - 1 })

  fun peekFront (Q { front = [], back = [], ... }) = NONE
    | peekFront (Q { front = x :: _, ... }) = SOME x
    | peekFront (Q { back, ... }) =
        case List.rev back of
            [] => NONE
          | x :: _ => SOME x

  fun filter p (Q { front, back, ... }) =
      let
        val items = List.filter p (front @ List.rev back)
      in
        Q { front = items, back = [], size = List.length items }
      end

  fun find p (Q { front, back, ... }) =
      case List.find p front of
          SOME x => SOME x
        | NONE => List.find p (List.rev back)

  fun map f (Q { front, back, size }) =
      Q { front = List.map f front, back = List.map f back, size = size }

  fun foldl f init (Q { front, back, ... }) =
      let
        val afterFront = List.foldl f init front
      in
        List.foldl f afterFront (List.rev back)
      end

  fun toList (Q { front, back, ... }) =
      front @ List.rev back

  fun fromList xs =
      Q { front = xs, back = [], size = List.length xs }
end
