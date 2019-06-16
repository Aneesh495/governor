(* order.sml
 * Implementation of Order structure and state transitions.
 *)

structure Order :> ORDER =
struct
  type order = {
    id : Types.order_id,
    client_id : Types.client_id,
    symbol : Types.symbol_id,
    side : Types.side,
    order_type : Types.order_type,
    time_in_force : Types.time_in_force,
    price : Types.price,
    initial_qty : Types.qty,
    leaves_qty : Types.qty,
    cum_qty : Types.qty,
    peak_qty : Types.qty,
    hidden_qty : Types.qty,
    status : Types.order_status,
    created_at : Types.timestamp_ns,
    updated_at : Types.timestamp_ns
  }

  fun create { id, client_id, symbol, side, order_type, time_in_force, price, qty, timestamp } : order =
      let
        val zeroQty : Types.qty = 0
        val (peak, hidden, leaves) =
            case order_type of
                Types.Iceberg { peak_qty, ... } =>
                  if qty > peak_qty then
                    (peak_qty, qty - peak_qty, peak_qty)
                  else
                    (qty, zeroQty, qty)
              | _ => (qty, zeroQty, qty)
      in
        {
          id = id,
          client_id = client_id,
          symbol = symbol,
          side = side,
          order_type = order_type,
          time_in_force = time_in_force,
          price = price,
          initial_qty = qty,
          leaves_qty = leaves,
          cum_qty = zeroQty,
          peak_qty = peak,
          hidden_qty = hidden,
          status = Types.Accepted,
          created_at = timestamp,
          updated_at = timestamp
        }
      end

  fun isFilled ({ status = Types.Filled, ... } : order) = true
    | isFilled _ = false

  fun isCancelled ({ status = Types.Cancelled, ... } : order) = true
    | isCancelled _ = false

  fun isActive ({ status, ... } : order) =
      case status of
          Types.Accepted => true
        | Types.PartiallyFilled => true
        | _ => false

  fun isResting (ord : order) =
      isActive ord andalso (#leaves_qty ord > 0)

  fun executeFill (ord : order) (fillQty : Types.qty) (ts : Types.timestamp_ns) : order =
      let
        val newLeaves = #leaves_qty ord - fillQty
        val newCum = #cum_qty ord + fillQty
        val totalRemaining = newLeaves + #hidden_qty ord
        val newStatus =
            if totalRemaining <= 0 then Types.Filled
            else Types.PartiallyFilled
      in
        {
          id = #id ord,
          client_id = #client_id ord,
          symbol = #symbol ord,
          side = #side ord,
          order_type = #order_type ord,
          time_in_force = #time_in_force ord,
          price = #price ord,
          initial_qty = #initial_qty ord,
          leaves_qty = if newLeaves < 0 then 0 else newLeaves,
          cum_qty = newCum,
          peak_qty = #peak_qty ord,
          hidden_qty = #hidden_qty ord,
          status = newStatus,
          created_at = #created_at ord,
          updated_at = ts
        }
      end

  fun replenishIceberg (ord : order) (ts : Types.timestamp_ns) : order =
      if #hidden_qty ord <= 0 then ord
      else
        let
          val peak = #peak_qty ord
          val availHidden = #hidden_qty ord
          val replenishAmount = if availHidden >= peak then peak else availHidden
          val newHidden = availHidden - replenishAmount
        in
          {
            id = #id ord,
            client_id = #client_id ord,
            symbol = #symbol ord,
            side = #side ord,
            order_type = #order_type ord,
            time_in_force = #time_in_force ord,
            price = #price ord,
            initial_qty = #initial_qty ord,
            leaves_qty = replenishAmount,
            cum_qty = #cum_qty ord,
            peak_qty = #peak_qty ord,
            hidden_qty = newHidden,
            status = Types.PartiallyFilled,
            created_at = #created_at ord,
            updated_at = ts
          }
        end

  fun cancel (ord : order) (ts : Types.timestamp_ns) : order =
      {
        id = #id ord,
        client_id = #client_id ord,
        symbol = #symbol ord,
        side = #side ord,
        order_type = #order_type ord,
        time_in_force = #time_in_force ord,
        price = #price ord,
        initial_qty = #initial_qty ord,
        leaves_qty = 0,
        cum_qty = #cum_qty ord,
        peak_qty = #peak_qty ord,
        hidden_qty = 0,
        status = Types.Cancelled,
        created_at = #created_at ord,
        updated_at = ts
      }

  fun reject (ord : order) (reason : string) (ts : Types.timestamp_ns) : order =
      {
        id = #id ord,
        client_id = #client_id ord,
        symbol = #symbol ord,
        side = #side ord,
        order_type = #order_type ord,
        time_in_force = #time_in_force ord,
        price = #price ord,
        initial_qty = #initial_qty ord,
        leaves_qty = 0,
        cum_qty = #cum_qty ord,
        peak_qty = #peak_qty ord,
        hidden_qty = 0,
        status = Types.Rejected reason,
        created_at = #created_at ord,
        updated_at = ts
      }

  fun expire (ord : order) (ts : Types.timestamp_ns) : order =
      {
        id = #id ord,
        client_id = #client_id ord,
        symbol = #symbol ord,
        side = #side ord,
        order_type = #order_type ord,
        time_in_force = #time_in_force ord,
        price = #price ord,
        initial_qty = #initial_qty ord,
        leaves_qty = 0,
        cum_qty = #cum_qty ord,
        peak_qty = #peak_qty ord,
        hidden_qty = 0,
        status = Types.Expired,
        created_at = #created_at ord,
        updated_at = ts
      }

  fun toString (ord : order) : string =
      "Order(id=" ^ LargeInt.toString (#id ord) ^
      ",client=" ^ #client_id ord ^
      ",sym=" ^ #symbol ord ^
      ",side=" ^ Types.sideToString (#side ord) ^
      ",price=" ^ Types.priceToString (#price ord) ^
      ",leaves=" ^ LargeInt.toString (#leaves_qty ord) ^
      ",hidden=" ^ LargeInt.toString (#hidden_qty ord) ^
      ",status=" ^ Types.statusToString (#status ord) ^ ")"
end
