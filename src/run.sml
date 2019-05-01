(* run.sml
 * Driver invocation for MLton native compiled binary.
 *)

val _ = OS.Process.exit (Main.main ());
