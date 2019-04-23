(* ansi.sml
 * Implementation of ANSI terminal formatting and box-drawing primitives.
 *)

structure Ansi :> ANSI =
struct
  val esc = "\027["

  val reset = esc ^ "0m"
  val bold = esc ^ "1m"
  val dim = esc ^ "2m"
  val italic = esc ^ "3m"
  val underline = esc ^ "4m"

  val black = esc ^ "30m"
  val red = esc ^ "31m"
  val green = esc ^ "32m"
  val yellow = esc ^ "33m"
  val blue = esc ^ "34m"
  val magenta = esc ^ "35m"
  val cyan = esc ^ "36m"
  val white = esc ^ "37m"

  val brightRed = esc ^ "91m"
  val brightGreen = esc ^ "92m"
  val brightYellow = esc ^ "93m"
  val brightBlue = esc ^ "94m"
  val brightCyan = esc ^ "96m"
  val brightWhite = esc ^ "97m"

  val clearScreen = esc ^ "2J"
  val clearLine = esc ^ "2K"
  val cursorHome = esc ^ "H"
  fun cursorMoveTo row col = esc ^ Int.toString row ^ ";" ^ Int.toString col ^ "H"

  val boxHorizontal = "-"
  val boxVertical = "|"
  val boxTopLeft = "+"
  val boxTopRight = "+"
  val boxBottomLeft = "+"
  val boxBottomRight = "+"
  val boxCross = "+"
  val boxTeeLeft = "+"
  val boxTeeRight = "+"
  val boxTeeTop = "+"
  val boxTeeBottom = "+"

  fun colorize color text = color ^ text ^ reset
end
