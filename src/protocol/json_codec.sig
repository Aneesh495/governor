(* json_codec.sig
 * JSON AST, string serializer, and token parser for client gateways.
 *)

signature JSON_CODEC =
sig
  datatype json_value =
      JNull
    | JBool of bool
    | JInt of LargeInt.int
    | JReal of real
    | JString of string
    | JArray of json_value list
    | JObject of (string * json_value) list

  val stringify : json_value -> string
  val parse : string -> (json_value, string) Result.result

  (* Object field accessors *)
  val getField : json_value -> string -> json_value option
  val getStringField : json_value -> string -> string option
  val getIntField : json_value -> string -> LargeInt.int option
  val getBoolField : json_value -> string -> bool option
end
