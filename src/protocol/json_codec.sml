(* json_codec.sml
 * Implementation of JSON serializer and recursive-descent parser.
 *)

structure JsonCodec :> JSON_CODEC =
struct
  datatype json_value =
      JNull
    | JBool of bool
    | JInt of LargeInt.int
    | JReal of real
    | JString of string
    | JArray of json_value list
    | JObject of (string * json_value) list

  fun escapeString (s : string) : string =
      let
        fun escapeChar c =
            case c of
                #"\"" => "\\\""
              | #"\\" => "\\\\"
              | #"\n" => "\\n"
              | #"\r" => "\\r"
              | #"\t" => "\\t"
              | _ => String.str c
      in
        "\"" ^ CharVector.foldr (fn (c, acc) => escapeChar c ^ acc) "" s ^ "\""
      end

  fun stringify JNull = "null"
    | stringify (JBool true) = "true"
    | stringify (JBool false) = "false"
    | stringify (JInt n) = LargeInt.toString n
    | stringify (JReal r) = Real.toString r
    | stringify (JString s) = escapeString s
    | stringify (JArray items) =
        "[" ^ String.concatWith "," (List.map stringify items) ^ "]"
    | stringify (JObject kvs) =
        let
          val entryStrs = List.map (fn (k, v) => escapeString k ^ ":" ^ stringify v) kvs
        in
          "{" ^ String.concatWith "," entryStrs ^ "}"
        end

  fun getField (JObject kvs) key =
      (case List.find (fn (k, _) => k = key) kvs of
           SOME (_, v) => SOME v
         | NONE => NONE)
    | getField _ _ = NONE

  fun getStringField obj key =
      case getField obj key of
          SOME (JString s) => SOME s
        | _ => NONE

  fun getIntField obj key =
      case getField obj key of
          SOME (JInt n) => SOME n
        | _ => NONE

  fun getBoolField obj key =
      case getField obj key of
          SOME (JBool b) => SOME b
        | _ => NONE

  (* Recursive-descent parser *)
  datatype token =
      TokLBrace
    | TokRBrace
    | TokLBracket
    | TokRBracket
    | TokColon
    | TokComma
    | TokString of string
    | TokNumber of LargeInt.int
    | TokTrue
    | TokFalse
    | TokNull

  fun tokenize (s : string) : token list =
      let
        val chars = String.explode s
        val sz = List.length chars

        fun skipWhitespace [] = []
          | skipWhitespace (c :: cs) =
              if Char.isSpace c then skipWhitespace cs
              else c :: cs

        fun readString ([], _) = raise Fail "Unterminated string in JSON"
          | readString (#"\"" :: cs, acc) = (String.implode (List.rev acc), cs)
          | readString (#"\\" :: c :: cs, acc) =
              let val esc = case c of #"n" => #"\n" | #"t" => #"\t" | #"\"" => #"\"" | #"\\" => #"\\" | _ => c in
                readString (cs, esc :: acc)
              end
          | readString (c :: cs, acc) = readString (cs, c :: acc)

        fun readDigits ([], acc) = (String.implode (List.rev acc), [])
          | readDigits (c :: cs, acc) =
              if Char.isDigit c orelse c = #"-" then readDigits (cs, c :: acc)
              else (String.implode (List.rev acc), c :: cs)

        fun nextToken [] = []
          | nextToken (c :: cs) =
              if Char.isSpace c then nextToken cs
              else case c of
                  #"{" => TokLBrace :: nextToken cs
                | #"}" => TokRBrace :: nextToken cs
                | #"[" => TokLBracket :: nextToken cs
                | #"]" => TokRBracket :: nextToken cs
                | #":" => TokColon :: nextToken cs
                | #"," => TokComma :: nextToken cs
                | #"\"" =>
                    let val (str, rest) = readString (cs, []) in
                      TokString str :: nextToken rest
                    end
                | _ =>
                    if Char.isDigit c orelse c = #"-" then
                      let val (numStr, rest) = readDigits (c :: cs, []) in
                        case LargeInt.fromString numStr of
                            SOME n => TokNumber n :: nextToken rest
                          | NONE => raise Fail ("Invalid number: " ^ numStr)
                      end
                    else
                      let
                        val remStr = String.implode (c :: cs)
                      in
                        if String.isPrefix "true" remStr then TokTrue :: nextToken (List.drop (c :: cs, 4))
                        else if String.isPrefix "false" remStr then TokFalse :: nextToken (List.drop (c :: cs, 5))
                        else if String.isPrefix "null" remStr then TokNull :: nextToken (List.drop (c :: cs, 4))
                        else raise Fail ("Unexpected character in JSON: " ^ String.str c)
                      end
      in
        nextToken chars
      end

  fun parseValue [] = raise Fail "Unexpected EOF in JSON"
    | parseValue (TokNull :: rest) = (JNull, rest)
    | parseValue (TokTrue :: rest) = (JBool true, rest)
    | parseValue (TokFalse :: rest) = (JBool false, rest)
    | parseValue (TokNumber n :: rest) = (JInt n, rest)
    | parseValue (TokString s :: rest) = (JString s, rest)
    | parseValue (TokLBracket :: rest) = parseArray (rest, [])
    | parseValue (TokLBrace :: rest) = parseObject (rest, [])
    | parseValue (t :: _) = raise Fail "Unexpected token in JSON value"

  and parseArray (TokRBracket :: rest, acc) = (JArray (List.rev acc), rest)
    | parseArray (tokens, acc) =
        let
          val (v, rest1) = parseValue tokens
        in
          case rest1 of
              TokComma :: rest2 => parseArray (rest2, v :: acc)
            | TokRBracket :: rest2 => (JArray (List.rev (v :: acc)), rest2)
            | _ => raise Fail "Expected ',' or ']' in JSON array"
        end

  and parseObject (TokRBrace :: rest, acc) = (JObject (List.rev acc), rest)
    | parseObject (TokString key :: TokColon :: rest, acc) =
        let
          val (v, rest1) = parseValue rest
        in
          case rest1 of
              TokComma :: rest2 => parseObject (rest2, (key, v) :: acc)
            | TokRBrace :: rest2 => (JObject (List.rev ((key, v) :: acc)), rest2)
            | _ => raise Fail "Expected ',' or '}' in JSON object"
        end
    | parseObject _ = raise Fail "Expected string key in JSON object"

  fun parse (raw : string) : (json_value, string) Result.result =
      let
        val tokens = tokenize raw
        val (v, rest) = parseValue tokens
      in
        if List.null rest then Result.ok v
        else Result.err "Trailing tokens after JSON root value"
      end
      handle Fail msg => Result.err ("JSON parse error: " ^ msg)
end
