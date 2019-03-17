(* ring_buffer.sml
 * Imperative circular ring buffer implementation backed by Array.
 *)

structure RingBuffer :> RING_BUFFER =
struct
  datatype 'a buffer = Ring of {
    capacity : int,
    data : 'a option Array.array,
    head : int ref,
    count : int ref
  }

  fun create cap =
      if cap <= 0 then raise Fail "RingBuffer.create: capacity must be positive"
      else
        Ring {
          capacity = cap,
          data = Array.array (cap, NONE),
          head = ref 0,
          count = ref 0
        }

  fun capacity (Ring { capacity = c, ... }) = c
  fun size (Ring { count, ... }) = !count
  fun isFull (Ring { capacity = c, count, ... }) = (!count = c)
  fun isEmpty (Ring { count, ... }) = (!count = 0)

  fun push (Ring { capacity = cap, data, head, count }) item =
      let
        val h = !head
      in
        Array.update (data, h, SOME item);
        head := (h + 1) mod cap;
        if !count < cap then
          count := !count + 1
        else ()
      end

  fun latest (Ring { capacity = cap, data, head, count }) =
      if !count = 0 then NONE
      else
        let
          val lastIdx = (!head - 1 + cap) mod cap
        in
          Array.sub (data, lastIdx)
        end

  fun toList (Ring { capacity = cap, data, head, count }) =
      let
        val cnt = !count
        val startIdx = if cnt < cap then 0 else !head
        fun collect (i, acc) =
            if i >= cnt then List.rev acc
            else
              let
                val idx = (startIdx + i) mod cap
                val v = valOf (Array.sub (data, idx))
              in
                collect (i + 1, v :: acc)
              end
      in
        collect (0, [])
      end

  fun clear (Ring { capacity = cap, data, head, count }) =
      (Array.modify (fn _ => NONE) data;
       head := 0;
       count := 0)
end
