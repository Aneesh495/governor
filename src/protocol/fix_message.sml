(* fix_message.sml
 * Implementation of FIX tag-value parser and serializer.
 *)

structure FixMessage :> FIX_MESSAGE =
struct
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

  fun create msgType sender target seq time fields : message =
      {
        msg_type = msgType,
        sender_comp_id = sender,
        target_comp_id = target,
        msg_seq_num = seq,
        sending_time = time,
        fields = fields
      }

  fun getField (m : message) (t : tag) : value option =
      case t of
          35 => SOME (#msg_type m)
        | 49 => SOME (#sender_comp_id m)
        | 56 => SOME (#target_comp_id m)
        | 34 => SOME (LargeInt.toString (#msg_seq_num m))
        | 52 => SOME (#sending_time m)
        | _ =>
            case List.find (fn (k, _) => k = t) (#fields m) of
                SOME (_, v) => SOME v
              | NONE => NONE

  fun getRequiredField (m : message) (t : tag) : (value, string) Result.result =
      case getField m t of
          SOME v => Result.ok v
        | NONE => Result.err ("Required FIX tag " ^ Int.toString t ^ " missing")

  fun getIntField (m : message) (t : tag) : (int, string) Result.result =
      case getField m t of
          NONE => Result.err ("Tag " ^ Int.toString t ^ " missing")
        | SOME s =>
            case Int.fromString s of
                SOME i => Result.ok i
              | NONE => Result.err ("Tag " ^ Int.toString t ^ " invalid integer value: " ^ s)

  fun getLargeIntField (m : message) (t : tag) : (LargeInt.int, string) Result.result =
      case getField m t of
          NONE => Result.err ("Tag " ^ Int.toString t ^ " missing")
        | SOME s =>
            case LargeInt.fromString s of
                SOME i => Result.ok i
              | NONE => Result.err ("Tag " ^ Int.toString t ^ " invalid LargeInt value: " ^ s)

  fun computeChecksum (s : string) : string =
      let
        val sum = CharVector.foldl (fn (c, acc) => (acc + Char.ord c) mod 256) 0 s
      in
        StringCvt.padLeft #"0" 3 (Int.toString sum)
      end

  fun serialize (m : message) (delim : char) : string =
      let
        val dStr = String.str delim
        val standardHeader =
            "35=" ^ #msg_type m ^ dStr ^
            "49=" ^ #sender_comp_id m ^ dStr ^
            "56=" ^ #target_comp_id m ^ dStr ^
            "34=" ^ LargeInt.toString (#msg_seq_num m) ^ dStr ^
            "52=" ^ #sending_time m ^ dStr

        val fieldStrs = String.concat (List.map (fn (k, v) => Int.toString k ^ "=" ^ v ^ dStr) (#fields m))
        val body = standardHeader ^ fieldStrs
        val bodyLen = String.size body
        val prefix = "8=FIX.4.2" ^ dStr ^ "9=" ^ Int.toString bodyLen ^ dStr
        val fullWithoutCksum = prefix ^ body
        val cksum = computeChecksum fullWithoutCksum
      in
        fullWithoutCksum ^ "10=" ^ cksum ^ dStr
      end

  fun parse (raw : string) (delim : char) : (message, string) Result.result =
      let
        val tokens = String.fields (fn c => c = delim) raw
        val nonEmpty = List.filter (fn s => String.size s > 0) tokens

        fun parsePair s =
            case String.fields (fn c => c = #"=") s of
                [tagStr, valStr] =>
                  (case Int.fromString tagStr of
                       SOME t => SOME (t, valStr)
                     | NONE => NONE)
              | _ => NONE

        val pairs = List.mapPartial parsePair nonEmpty
      in
        if List.length pairs < 3 then
          Result.err "FIX message malformed: too few fields"
        else
          let
            fun findTag t =
                case List.find (fn (k, _) => k = t) pairs of
                    SOME (_, v) => SOME v
                  | NONE => NONE

            val msgTypeOpt = findTag 35
            val senderOpt = findTag 49
            val targetOpt = findTag 56
            val seqOpt = findTag 34
            val timeOpt = findTag 52
          in
            case (msgTypeOpt, senderOpt, targetOpt, seqOpt, timeOpt) of
                (SOME msgType, SOME sender, SOME target, SOME seqStr, SOME sendingTime) =>
                  (case LargeInt.fromString seqStr of
                       SOME seq =>
                         let
                           val standardTags = [8, 9, 35, 49, 56, 34, 52, 10]
                           val extraFields = List.filter (fn (k, _) => not (List.exists (fn st => st = k) standardTags)) pairs
                         in
                           Result.ok {
                             msg_type = msgType,
                             sender_comp_id = sender,
                             target_comp_id = target,
                             msg_seq_num = seq,
                             sending_time = sendingTime,
                             fields = extraFields
                           }
                         end
                     | NONE => Result.err "Tag 34 (MsgSeqNum) invalid number")
              | _ => Result.err "Missing standard FIX header tags (35, 49, 56, 34, or 52)"
          end
      end
end
