(* fifo_queue.sig
 * Pure functional double-list FIFO queue with amortized O(1) enqueue/dequeue.
 *)

signature FIFO_QUEUE =
sig
  type 'a queue

  val empty : 'a queue
  val isEmpty : 'a queue -> bool
  val length : 'a queue -> int

  (* Enqueue at back: O(1) *)
  val pushBack : 'a queue -> 'a -> 'a queue

  (* Dequeue from front: O(1) amortized *)
  val popFront : 'a queue -> ('a * 'a queue) option

  (* Peek at front: O(1) amortized *)
  val peekFront : 'a queue -> 'a option

  (* Remove elements satisfying predicate *)
  val filter : ('a -> bool) -> 'a queue -> 'a queue

  (* Update or remove an order by ID or predicate *)
  val find : ('a -> bool) -> 'a queue -> 'a option

  (* Transformations and folds *)
  val map : ('a -> 'b) -> 'a queue -> 'b queue
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a queue -> 'b
  val toList : 'a queue -> 'a list
  val fromList : 'a list -> 'a queue
end
