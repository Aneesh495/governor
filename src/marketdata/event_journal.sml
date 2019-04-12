(* event_journal.sml
 * Implementation of EventJournal backed by RingBuffer.
 *)

structure EventJournal :> EVENT_JOURNAL =
struct
  type journal = {
    buffer : MarketDataEvent.event RingBuffer.buffer
  }

  fun create cap =
      { buffer = RingBuffer.create cap }

  fun record (j : journal) (ev : MarketDataEvent.event) =
      RingBuffer.push (#buffer j) ev

  fun size (j : journal) =
      RingBuffer.size (#buffer j)

  fun latest (j : journal) =
      RingBuffer.latest (#buffer j)

  fun replayEvents (j : journal) =
      RingBuffer.toList (#buffer j)

  fun writeToFile (j : journal) (filepath : string) =
      let
        val out = TextIO.openOut filepath
        val events = replayEvents j
      in
        List.app (fn ev => TextIO.output (out, MarketDataEvent.toString ev ^ "\n")) events;
        TextIO.closeOut out
      end
end
