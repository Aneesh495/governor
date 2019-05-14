(* microprice.sig
 * High-frequency microprice estimation and Order Flow Imbalance (OFI) calculation.
 *)

signature MICROPRICE =
sig
  type estimator

  val create : unit -> estimator

  (* Calculates microprice from current book BBO: (Q_bid * P_ask + Q_ask * P_bid) / (Q_bid + Q_ask) *)
  val calculateMicroprice : OrderBook.book -> Types.price option

  (* Calculates Order Flow Imbalance: (Q_bid - Q_ask) / (Q_bid + Q_ask) in range [-1.0, 1.0] *)
  val calculateImbalanceRatio : OrderBook.book -> real option

  (* Multi-level weighted microprice incorporating top N levels *)
  val calculateMultiLevelMicroprice : OrderBook.book -> int -> Types.price option
end
