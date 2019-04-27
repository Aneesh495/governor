(* gateway_session.sml
 * Implementation of GatewaySession state machine.
 *)

structure GatewaySession :> GATEWAY_SESSION =
struct
  datatype state =
      Disconnected
    | Connected of { remote_addr : string, connect_time : Types.timestamp_ns }
    | LoggedIn of { client_id : Types.client_id, session_start : Types.timestamp_ns }

  type session = {
    session_id : int,
    state : state,
    in_seq : Types.sequence_num ref,
    out_seq : Types.sequence_num ref,
    last_heartbeat : Types.timestamp_ns ref
  }

  fun create (id : int) : session =
      {
        session_id = id,
        state = Disconnected,
        in_seq = ref 0,
        out_seq = ref 0,
        last_heartbeat = ref 0
      }

  fun logon (s : session) (clientId : Types.client_id) (ts : Types.timestamp_ns) : session =
      let
        val () = #last_heartbeat s := ts
      in
        {
          session_id = #session_id s,
          state = LoggedIn { client_id = clientId, session_start = ts },
          in_seq = #in_seq s,
          out_seq = #out_seq s,
          last_heartbeat = #last_heartbeat s
        }
      end

  fun nextOutSeq (s : session) : Types.sequence_num =
      let
        val seq = !(#out_seq s) + 1
      in
        #out_seq s := seq;
        seq
      end

  fun verifyInSeq (s : session) (seq : Types.sequence_num) : (unit, string) Result.result =
      let
        val expected = !(#in_seq s) + 1
      in
        if seq = expected then
          (#in_seq s := seq; Result.ok ())
        else if seq < expected then
          Result.err ("Duplicate message sequence: expected " ^ LargeInt.toString expected ^ " but got " ^ LargeInt.toString seq)
        else
          Result.err ("Sequence gap detected: expected " ^ LargeInt.toString expected ^ " but got " ^ LargeInt.toString seq)
      end

  fun updateHeartbeat (s : session) (ts : Types.timestamp_ns) : unit =
      #last_heartbeat s := ts

  fun isHeartbeatExpired (s : session) (now : Types.timestamp_ns) (timeoutNs : Types.timestamp_ns) : bool =
      (now - !(#last_heartbeat s)) > timeoutNs
end
