(* gateway_session.sig
 * Client network connection session state, heartbeat monitoring, and message sequence tracking.
 *)

signature GATEWAY_SESSION =
sig
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

  val create : int -> session
  val logon : session -> Types.client_id -> Types.timestamp_ns -> session
  val nextOutSeq : session -> Types.sequence_num
  val verifyInSeq : session -> Types.sequence_num -> (unit, string) Result.result
  val updateHeartbeat : session -> Types.timestamp_ns -> unit
  val isHeartbeatExpired : session -> Types.timestamp_ns -> Types.timestamp_ns -> bool
end
