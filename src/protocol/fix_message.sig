(* fix_message.sig
 * Financial Information eXchange (FIX 4.2 / 5.0) tag-value protocol message codec.
 *)

signature FIX_MESSAGE =
sig
  type tag = int
  type value = string

  type message = {
    msg_type : string,
    sender_comp_id : string,
    target_comp_id : string,
    msg_seq_num : LargeInt.int,
    sending_time : string,
    fields : (tag * value) list
  }

  val create : string -> string -> string -> LargeInt.int -> string -> (tag * value) list -> message

  val getField : message -> tag -> value option
  val getRequiredField : message -> tag -> (value, string) Result.result
  val getIntField : message -> tag -> (int, string) Result.result
  val getLargeIntField : message -> tag -> (LargeInt.int, string) Result.result

  (* Serialization and Deserialization *)
  val serialize : message -> char -> string  (* char delimiter, e.g. SOH or '|' *)
  val parse : string -> char -> (message, string) Result.result
  val computeChecksum : string -> string
end
