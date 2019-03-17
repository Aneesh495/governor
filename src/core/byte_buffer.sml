(* byte_buffer.sml
 * Implementation of byte buffer operations backed by Word8Vector.
 *)

structure ByteBuffer :> BYTE_BUFFER =
struct
  type buffer = Word8Vector.vector

  val empty = Word8Vector.fromList []

  fun fromBytes bs = Word8Vector.fromList bs
  fun fromString s = Byte.stringToBytes s
  fun fromVector v = v

  fun toBytes v = Word8Vector.foldr (fn (b, acc) => b :: acc) [] v
  fun toString v = Byte.bytesToString v
  fun toVector v = v

  fun length v = Word8Vector.length v
  fun isEmpty v = (length v = 0)

  fun append v1 v2 = Word8Vector.concat [v1, v2]
  fun appendByte v b = Word8Vector.concat [v, Word8Vector.fromList [b]]
  fun appendBytes v bs = Word8Vector.concat [v, Word8Vector.fromList bs]

  fun slice v offset len =
      let
        val total = length v
      in
        if offset < 0 orelse len < 0 orelse offset + len > total then
          raise Subscript
        else
          Word8VectorSlice.vector (Word8VectorSlice.slice (v, offset, SOME len))
      end

  fun take v n =
      if n <= 0 then empty
      else if n >= length v then v
      else slice v 0 n

  fun drop v n =
      if n <= 0 then v
      else if n >= length v then empty
      else slice v n (length v - n)

  fun sub v i = Word8Vector.sub (v, i)

  fun toHex v =
      let
        fun byteToHex b =
            let
              val hexChars = "0123456789abcdef"
              val i = Word8.toInt b
              val hi = (i div 16) mod 16
              val lo = i mod 16
            in
              String.implode [String.sub (hexChars, hi), String.sub (hexChars, lo)]
            end
      in
        Word8Vector.foldr (fn (b, acc) => byteToHex b ^ acc) "" v
      end

  fun fromHex s =
      let
        fun hexVal c =
            if c >= #"0" andalso c <= #"9" then SOME (Char.ord c - Char.ord #"0")
            else if c >= #"a" andalso c <= #"f" then SOME (Char.ord c - Char.ord #"a" + 10)
            else if c >= #"A" andalso c <= #"F" then SOME (Char.ord c - Char.ord #"A" + 10)
            else NONE

        val sz = String.size s
        fun parsePair i acc =
            if i >= sz then SOME (fromBytes (List.rev acc))
            else if i + 1 >= sz then NONE
            else
              case (hexVal (String.sub (s, i)), hexVal (String.sub (s, i + 1))) of
                  (SOME hi, SOME lo) =>
                    let
                      val byteVal = Word8.fromInt (hi * 16 + lo)
                    in
                      parsePair (i + 2) (byteVal :: acc)
                    end
                | _ => NONE
      in
        parsePair 0 []
      end
end
