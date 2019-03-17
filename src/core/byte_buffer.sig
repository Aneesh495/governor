(* byte_buffer.sig
 * Byte buffer manipulation, zero-copy slicing, and hex encoding utilities.
 *)

signature BYTE_BUFFER =
sig
  type buffer

  val empty : buffer
  val fromBytes : Word8.word list -> buffer
  val fromString : string -> buffer
  val fromVector : Word8Vector.vector -> buffer

  val toBytes : buffer -> Word8.word list
  val toString : buffer -> string
  val toVector : buffer -> Word8Vector.vector

  val length : buffer -> int
  val isEmpty : buffer -> bool

  val append : buffer -> buffer -> buffer
  val appendByte : buffer -> Word8.word -> buffer
  val appendBytes : buffer -> Word8.word list -> buffer

  (* Slicing: offset, length *)
  val slice : buffer -> int -> int -> buffer
  val take : buffer -> int -> buffer
  val drop : buffer -> int -> buffer

  val sub : buffer -> int -> Word8.word

  (* Hexadecimal formatting *)
  val toHex : buffer -> string
  val fromHex : string -> buffer option
end
