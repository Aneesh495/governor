(* order_gateway.sig
 * Network Order Entry Gateway processing client request buffers and generating replies.
 *)

signature ORDER_GATEWAY =
sig
  type gateway

  val create : ExchangeSim.sim -> gateway

  (* Ingest raw binary packet from network socket *)
  val handleBinaryPacket : gateway -> GatewaySession.session -> ByteBuffer.buffer -> Types.timestamp_ns ->
      (gateway * GatewaySession.session * ByteBuffer.buffer list, string) Result.result

  (* Ingest raw FIX string message from network socket *)
  val handleFixMessage : gateway -> GatewaySession.session -> string -> Types.timestamp_ns ->
      (gateway * GatewaySession.session * string list, string) Result.result

  val getSim : gateway -> ExchangeSim.sim
end
