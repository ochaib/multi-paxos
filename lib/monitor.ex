# Ossama Chaib (oc3317)

# distributed algorithms, n.dulay 29 jan 2021
# coursework, paxos made moderately complex

defmodule Monitor do

# setters for Monitor state variables
def clock(state, v), do:
  Map.put(state, :clock, v)

def requests(state, i, v), do:
  Map.put(state, :requests, Map.put(state.requests, i, v))

def updates(state, i, v), do:
  Map.put(state, :updates,  Map.put(state.updates, i, v))

def transactions(state, v), do:
  Map.put(state, :transactions, v)

def commanders_spawned(state, i, v), do:
  Map.put(state, :commanders_spawned,  Map.put(state.commanders_spawned, i, v))

def commanders_finished(state, i, v), do:
  Map.put(state, :commanders_finished,  Map.put(state.commanders_finished, i, v))

def scouts_spawned(state, i, v), do:
  Map.put(state, :scouts_spawned, Map.put(state.scouts_spawned, i, v))

def scouts_finished(state, i, v), do:
  Map.put(state, :scouts_finished, Map.put(state.scouts_finished, i, v))

def start_print_timeout(duration), do:
  Process.send_after(self(), { :print }, duration)

def start(config) do
  state = %{
    clock:               0,
    requests:            Map.new,
    updates:             Map.new,
    transactions:        Map.new,
    scouts_spawned:      Map.new,
    scouts_finished:     Map.new,
    commanders_spawned:  Map.new,
    commanders_finished: Map.new,
  }
  Monitor.start_print_timeout(config.print_after)
  Monitor.next(config, state)
end # start

def next(config, state) do
  receive do
  # Database update is received
  { :db_update, db, seqnum, transaction } ->
    # Pattern match on the received transaction
    { :move, amount, from, to } = transaction
    done = Map.get(state.updates, db, 0)

    if seqnum != done + 1, do:
      Util.halt "  ** error db #{db}: seq #{seqnum} expecting #{done+1}"

    transactions =
      # Get the transaction values at this sequence number
      case Map.get(state.transactions, seqnum) do
      # If they do not exist in the map, put them there using values from the
      # transaction retrieved from the database update.
      nil -> # IO.puts "db #{db} seq #{seqnum} = #{done+1}"
        Map.put(state.transactions, seqnum, %{amount: amount, from: from, to: to})

      t -> # already logged - check transaction
        if amount != t.amount or from != t.from or to != t.to do
  	      Util.halt " ** error db #{db}.#{done} [#{amount},#{from},#{to}] "
            <>
          "= log #{done}/#{map_size(state.transactions)} [#{t.amount},#{t.from},#{t.to}]"
        end
        state.transactions
      end # case

    # Set the transactions and update the state map for this state.
    state = Monitor.transactions(state, transactions)
    state = Monitor.updates(state, db, seqnum)
    # Proceed with the next state
    Monitor.next(config, state)

  { :client_request, server_num } ->  # client requests seen by replicas
    # Get the value from the requests corresponding to the server_num received.
    value = Map.get(state.requests, server_num, 0)
    # Update the request values at this state.
    state = Monitor.requests(state, server_num, value + 1)
    Monitor.next(config, state)

  # If a new scout has been spawned we must get query the map for the value that
  # tracks the number of spawned scouts to update it in the state map.
  # This is the same for the messages received below.
  { :scout_spawned, server_num } ->
    value = Map.get(state.scouts_spawned, server_num, 0)
    state = Monitor.scouts_spawned(state, server_num, value + 1)
    Monitor.next(config, state)

  { :scout_finished, server_num } ->
    value = Map.get(state.scouts_finished, server_num, 0)
    state = Monitor.scouts_finished(state, server_num, value + 1)
    Monitor.next(config, state)

  { :commander_spawned, server_num } ->
    value = Map.get(state.commanders_spawned, server_num, 0)
    state = Monitor.commanders_spawned(state, server_num, value + 1)
    Monitor.next(config, state)

  { :commander_finished, server_num } ->
    value = Map.get(state.commanders_finished, server_num, 0)
    state = Monitor.commanders_finished(state, server_num, value + 1)
    Monitor.next(config, state)

  # If a print message is received:
  { :print } ->
    # Update this state's clock then put it in the state map.
    clock  = state.clock + config.print_after
    state  = Monitor.clock(state, clock)

    sorted = state.updates  |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock}      db updates done = #{inspect sorted}"
    sorted = state.requests |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock} client requests seen = #{inspect sorted}"

    if config.debug_level == 0 do
      min_done   = state.updates  |> Map.values |> Enum.min(fn -> 0 end)
      n_requests = state.requests |> Map.values |> Enum.sum
      IO.puts "time = #{clock}           total seen = #{n_requests} max lag = #{n_requests-min_done}"

      sorted = state.scouts_spawned |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}            scouts up = #{inspect sorted}"
      sorted = state.scouts_finished |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}          scouts down = #{inspect sorted}"

      sorted = state.commanders_spawned |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}        commanders up = #{inspect sorted}"
      sorted = state.commanders_finished |> Map.to_list |> List.keysort(0)
      IO.puts "time = #{clock}      commanders down = #{inspect sorted}"
    end

    IO.puts ""
    Monitor.start_print_timeout(config.print_after)
    Monitor.next(config, state)

  # ** ADD ADDITIONAL MONITORING MESSAGES OF YOUR OWN HERE

  unexpected ->
    Util.halt "monitor: unexpected message #{inspect unexpected}"
  end # receive
end # next

end # Monitor
