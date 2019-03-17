(* word_util.sig
 * Bitwise manipulation, word conversions, binary packing, and hashing utilities.
 *)

signature WORD_UTIL =
sig
  (* Endianness conversions *)
  val swap16 : Word32.word -> Word32.word
  val swap32 : Word32.word -> Word32.word
  val swap64 : Word64.word -> Word64.word

  (* Packing unsigned integers into big-endian byte sequences *)
  val packU16BE : Word32.word -> Word8.word list
  val packU32BE : Word32.word -> Word8.word list
  val packU64BE : Word64.word -> Word8.word list

  (* Unpacking big-endian byte sequences *)
  val unpackU16BE : Word8.word list -> Word32.word * Word8.word list
  val unpackU32BE : Word8.word list -> Word32.word * Word8.word list
  val unpackU64BE : Word8.word list -> Word64.word * Word8.word list

  (* Bitfield extraction *)
  val getBits : Word32.word -> int -> int -> Word32.word
  val setBits : Word32.word -> int -> int -> Word32.word -> Word32.word

  (* Hash functions for identifiers *)
  val hashString : string -> Word32.word
  val hashLargeInt : LargeInt.int -> Word32.word
  val combineHash : Word32.word -> Word32.word -> Word32.word
end
