(* ansi.sig
 * ANSI terminal formatting, escape sequences, colors, and box-drawing primitives.
 *)

signature ANSI =
sig
  val reset : string
  val bold : string
  val dim : string
  val italic : string
  val underline : string

  (* Foreground colors *)
  val black : string
  val red : string
  val green : string
  val yellow : string
  val blue : string
  val magenta : string
  val cyan : string
  val white : string

  (* Bright foreground colors *)
  val brightRed : string
  val brightGreen : string
  val brightYellow : string
  val brightBlue : string
  val brightCyan : string
  val brightWhite : string

  (* Cursor controls *)
  val clearScreen : string
  val clearLine : string
  val cursorHome : string
  val cursorMoveTo : int -> int -> string  (* row, col *)

  (* Box drawing characters *)
  val boxHorizontal : string
  val boxVertical : string
  val boxTopLeft : string
  val boxTopRight : string
  val boxBottomLeft : string
  val boxBottomRight : string
  val boxCross : string
  val boxTeeLeft : string
  val boxTeeRight : string
  val boxTeeTop : string
  val boxTeeBottom : string

  (* Colored string helpers *)
  val colorize : string -> string -> string
end
