(* event_journal.sig
 * Append-only deterministic event journal for market event logging and state replay.
 *)

signature EVENT_JOURNAL =
sig
  type journal

  val create : int -> journal
  val record : journal -> MarketDataEvent.event -> unit
  val size : journal -> int
  val latest : journal -> MarketDataEvent.event option
  val replayEvents : journal -> MarketDataEvent.event list
  val writeToFile : journal -> string -> unit
end
