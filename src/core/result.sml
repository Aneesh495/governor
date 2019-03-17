(* result.sml
 * Implementation of monadic result operations for Governor.
 *)

structure Result :> RESULT =
struct
  datatype ('a, 'e) result =
      Ok of 'a
    | Err of 'e

  fun ok v = Ok v
  fun err e = Err e

  fun isOk (Ok _) = true
    | isOk (Err _) = false

  fun isErr (Ok _) = false
    | isErr (Err _) = true

  fun map f (Ok v) = Ok (f v)
    | map _ (Err e) = Err e

  fun mapErr _ (Ok v) = Ok v
    | mapErr f (Err e) = Err (f e)

  fun bind (Ok v) f = f v
    | bind (Err e) _ = Err e

  fun getOrElse _ (Ok v) = v
    | getOrElse fallback (Err _) = fallback

  fun unwrap (Ok v) = v
    | unwrap (Err msg) = raise Fail ("Result.unwrap called on Err: " ^ msg)

  fun fold onOk _ (Ok v) = onOk v
    | fold _ onErr (Err e) = onErr e

  fun sequence [] = Ok []
    | sequence (r :: rs) =
        case r of
            Err e => Err e
          | Ok x =>
              case sequence rs of
                  Err e => Err e
                | Ok xs => Ok (x :: xs)
end
