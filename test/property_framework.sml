(* property_framework.sml
 * Implementation of property-based testing framework.
 *)

structure PropertyFramework :> PROPERTY_FRAMEWORK =
struct
  type rng = Word32.word ref

  fun initRng (seed : Word32.word) : rng =
      ref (if seed = 0w0 then 0w123456789 else seed)

  (* Xorshift32 PRNG *)
  fun nextWord32 (r : rng) : Word32.word =
      let
        val x = !r
        val x1 = Word32.xorb (x, Word32.<< (x, 0w13))
        val x2 = Word32.xorb (x1, Word32.>> (x1, 0w17))
        val x3 = Word32.xorb (x2, Word32.<< (x2, 0w5))
      in
        r := x3;
        x3
      end

  fun nextIntRange (r : rng) (minVal : int, maxVal : int) : int =
      if minVal >= maxVal then minVal
      else
        let
          val span = Word32.fromInt (maxVal - minVal + 1)
          val w = nextWord32 r
          val offset = Word32.toInt (Word32.mod (w, span))
        in
          minVal + offset
        end

  fun nextLargeIntRange (r : rng) (minVal : LargeInt.int, maxVal : LargeInt.int) : LargeInt.int =
      if minVal >= maxVal then minVal
      else
        let
          val span = maxVal - minVal + 1
          val w1 = Word64.fromLargeInt (Word32.toLargeInt (nextWord32 r))
          val w2 = Word64.fromLargeInt (Word32.toLargeInt (nextWord32 r))
          val combined = Word64.orb (Word64.<< (w1, 0w32), w2)
          val offset = Word64.toLargeInt (Word64.mod (combined, Word64.fromLargeInt span))
        in
          minVal + offset
        end

  fun nextBool (r : rng) : bool =
      (Word32.andb (nextWord32 r, 0w1)) = 0w1

  type 'a gen = rng -> 'a

  fun genInt (minVal, maxVal) (r : rng) : int =
      nextIntRange r (minVal, maxVal)

  fun genLargeInt (minVal, maxVal) (r : rng) : LargeInt.int =
      nextLargeIntRange r (minVal, maxVal)

  fun genBool (r : rng) : bool =
      nextBool r

  fun genList (g : 'a gen) (len : int) (r : rng) : 'a list =
      let
        fun loop (0, acc) = List.rev acc
          | loop (n, acc) = loop (n - 1, g r :: acc)
      in
        loop (len, [])
      end

  fun genChoose (xs : 'a list) (r : rng) : 'a =
      case xs of
          [] => raise Fail "genChoose on empty list"
        | _ =>
            let
              val idx = nextIntRange r (0, List.length xs - 1)
            in
              List.nth (xs, idx)
            end

  fun checkProperty { name, trials, generator, property, showCounterExample } : bool =
      let
        val r = initRng 0w42424242
        fun loop (0, _) =
              (print ("  [PASS] Property: " ^ name ^ " (" ^ Int.toString trials ^ " trials)\n");
               true)
          | loop (remaining, step) =
              let
                val sample = generator r
              in
                if property sample then
                  loop (remaining - 1, step + 1)
                else
                  (print ("  [FAIL] Property Falsified: " ^ name ^ " at trial " ^ Int.toString step ^ "\n");
                   print ("    Counterexample: " ^ showCounterExample sample ^ "\n");
                   false)
              end
      in
        loop (trials, 1)
      end

  fun runProperties (suiteName : string) tests : int * int =
      let
        val _ = print ("\n=== Property Test Suite: " ^ suiteName ^ " ===\n")
        fun exec ([], p, f) = (p, f)
          | exec (t :: ts, p, f) =
              if checkProperty t then
                exec (ts, p + 1, f)
              else
                exec (ts, p, f + 1)
      in
        exec (tests, 0, 0)
      end
end
