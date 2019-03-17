(* word_util.sml
 * Implementation of bitwise operations, byte packing, and hashing.
 *)

structure WordUtil :> WORD_UTIL =
struct
  fun swap16 (w : Word32.word) : Word32.word =
      let
        open Word32
        val b0 = andb (w, 0wx00FF)
        val b1 = andb (>> (w, 0w8), 0wx00FF)
      in
        orb (<< (b0, 0w8), b1)
      end

  fun swap32 (w : Word32.word) : Word32.word =
      let
        open Word32
        val b0 = andb (w, 0wx000000FF)
        val b1 = andb (>> (w, 0w8), 0wx000000FF)
        val b2 = andb (>> (w, 0w16), 0wx000000FF)
        val b3 = andb (>> (w, 0w24), 0wx000000FF)
      in
        orb (<< (b0, 0w24), orb (<< (b1, 0w16), orb (<< (b2, 0w8), b3)))
      end

  fun swap64 (w : Word64.word) : Word64.word =
      let
        open Word64
        val mask = 0wx00000000000000FF
        val b0 = andb (w, mask)
        val b1 = andb (>> (w, 0w8), mask)
        val b2 = andb (>> (w, 0w16), mask)
        val b3 = andb (>> (w, 0w24), mask)
        val b4 = andb (>> (w, 0w32), mask)
        val b5 = andb (>> (w, 0w40), mask)
        val b6 = andb (>> (w, 0w48), mask)
        val b7 = andb (>> (w, 0w56), mask)
      in
        orb (<< (b0, 0w56),
        orb (<< (b1, 0w48),
        orb (<< (b2, 0w40),
        orb (<< (b3, 0w32),
        orb (<< (b4, 0w24),
        orb (<< (b5, 0w16),
        orb (<< (b6, 0w8), b7)))))))
      end

  fun packU16BE (w : Word32.word) : Word8.word list =
      let
        open Word32
        val b1 = Word8.fromLargeWord (toLargeWord (andb (w, 0wxFF)))
        val b0 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w8), 0wxFF)))
      in
        [b0, b1]
      end

  fun packU32BE (w : Word32.word) : Word8.word list =
      let
        open Word32
        val b3 = Word8.fromLargeWord (toLargeWord (andb (w, 0wxFF)))
        val b2 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w8), 0wxFF)))
        val b1 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w16), 0wxFF)))
        val b0 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w24), 0wxFF)))
      in
        [b0, b1, b2, b3]
      end

  fun packU64BE (w : Word64.word) : Word8.word list =
      let
        open Word64
        val mask = 0wxFF
        val b7 = Word8.fromLargeWord (toLargeWord (andb (w, mask)))
        val b6 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w8), mask)))
        val b5 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w16), mask)))
        val b4 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w24), mask)))
        val b3 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w32), mask)))
        val b2 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w40), mask)))
        val b1 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w48), mask)))
        val b0 = Word8.fromLargeWord (toLargeWord (andb (>> (w, 0w56), mask)))
      in
        [b0, b1, b2, b3, b4, b5, b6, b7]
      end

  fun unpackU16BE (b0 :: b1 :: rest) =
      let
        val w0 = Word32.fromLargeWord (Word8.toLargeWord b0)
        val w1 = Word32.fromLargeWord (Word8.toLargeWord b1)
        val res = Word32.orb (Word32.<< (w0, 0w8), w1)
      in
        (res, rest)
      end
    | unpackU16BE _ = raise Fail "WordUtil.unpackU16BE: buffer underflow"

  fun unpackU32BE (b0 :: b1 :: b2 :: b3 :: rest) =
      let
        val w0 = Word32.fromLargeWord (Word8.toLargeWord b0)
        val w1 = Word32.fromLargeWord (Word8.toLargeWord b1)
        val w2 = Word32.fromLargeWord (Word8.toLargeWord b2)
        val w3 = Word32.fromLargeWord (Word8.toLargeWord b3)
        val res = Word32.orb (Word32.<< (w0, 0w24),
                  Word32.orb (Word32.<< (w1, 0w16),
                  Word32.orb (Word32.<< (w2, 0w8), w3)))
      in
        (res, rest)
      end
    | unpackU32BE _ = raise Fail "WordUtil.unpackU32BE: buffer underflow"

  fun unpackU64BE (b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest) =
      let
        val w0 = Word64.fromLargeWord (Word8.toLargeWord b0)
        val w1 = Word64.fromLargeWord (Word8.toLargeWord b1)
        val w2 = Word64.fromLargeWord (Word8.toLargeWord b2)
        val w3 = Word64.fromLargeWord (Word8.toLargeWord b3)
        val w4 = Word64.fromLargeWord (Word8.toLargeWord b4)
        val w5 = Word64.fromLargeWord (Word8.toLargeWord b5)
        val w6 = Word64.fromLargeWord (Word8.toLargeWord b6)
        val w7 = Word64.fromLargeWord (Word8.toLargeWord b7)
        val res = Word64.orb (Word64.<< (w0, 0w56),
                  Word64.orb (Word64.<< (w1, 0w48),
                  Word64.orb (Word64.<< (w2, 0w40),
                  Word64.orb (Word64.<< (w3, 0w32),
                  Word64.orb (Word64.<< (w4, 0w24),
                  Word64.orb (Word64.<< (w5, 0w16),
                  Word64.orb (Word64.<< (w6, 0w8), w7)))))))
      in
        (res, rest)
      end
    | unpackU64BE _ = raise Fail "WordUtil.unpackU64BE: buffer underflow"

  fun getBits (w : Word32.word) (offset : int) (length : int) : Word32.word =
      let
        open Word32
        val shiftAmount = Word.fromInt offset
        val mask = notb (<< (0wxFFFFFFFF, Word.fromInt length))
      in
        andb (>> (w, shiftAmount), mask)
      end

  fun setBits (target : Word32.word) (offset : int) (length : int) (value : Word32.word) : Word32.word =
      let
        open Word32
        val shiftAmount = Word.fromInt offset
        val mask = << (notb (<< (0wxFFFFFFFF, Word.fromInt length)), shiftAmount)
        val cleared = andb (target, notb mask)
        val positioned = andb (<< (value, shiftAmount), mask)
      in
        orb (cleared, positioned)
      end

  fun hashString (s : string) : Word32.word =
      let
        val fnvPrime : Word32.word = 0wx01000193
        val fnvOffset : Word32.word = 0wx811C9DC5
        fun loop (i, acc) =
            if i >= String.size s then acc
            else
              let
                val byteVal = Word32.fromInt (Char.ord (String.sub (s, i)))
                val xored = Word32.xorb (acc, byteVal)
                val multiplied = Word32.* (xored, fnvPrime)
              in
                loop (i + 1, multiplied)
              end
      in
        loop (0, fnvOffset)
      end

  fun hashLargeInt (n : LargeInt.int) : Word32.word =
      let
        val absN = LargeInt.abs n
        val low32 = Word32.fromLargeInt (absN mod 0x100000000)
        val high32 = Word32.fromLargeInt ((absN div 0x100000000) mod 0x100000000)
      in
        Word32.xorb (low32, Word32.* (high32, 0wx01000193))
      end

  fun combineHash (h1 : Word32.word) (h2 : Word32.word) : Word32.word =
      Word32.xorb (h1, Word32.+ (Word32.<< (h2, 0w6), Word32.+ (Word32.>> (h2, 0w2), 0wx9E3779B9)))
end
