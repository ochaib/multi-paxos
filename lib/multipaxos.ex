# Ossama Chaib (oc3317)

# distributed algorithms, n.dulay 29 jan 2021
# coursework, paxos made moderately complex

defmodule Multipaxos do

def start do
  config = Util.node_init()
  start(config.start_function, config)
end # start/0

defp start(:cluster_wait, _), do: :skip
defp start(:cluster_start, config) do
  config = Configuration.node_id(config, "Multipaxos")
  Debug.starting(config)

  # spawn monitoring process and add its process-id to config
  monitor = spawn Monitor, :start, [config]
  config  = Map.put(config, :monitor, monitor)

  Debug.map(config, config)

  # Spawn each server passing the config, server number and multipaxos module id?
  for server_num <- 1 .. config.n_servers do
    Node.spawn :'server#{server_num}_#{config.node_suffix}', Server, :start,
               [config, server_num, self()]
  end # for

  # Compile a list of r, a, l tuples received from the server modules.
  server_modules =
    for _ <- 1 .. config.n_servers do
      receive do { :modules, r, a, l } -> { r, a, l } end
    end # for

  # Unzip the list of r, a, l tuples into a tuple of r, a, l lists.
  { replicas, acceptors, leaders } = Util.unzip3(server_modules)

  for replica <- replicas do
    # IO.puts "Replica #{inspect replica} was sent a bind."
    send replica, { :bind, leaders }
  end
  for leader  <- leaders,  do: send leader,  { :bind, acceptors, replicas }

  for client_num <- 1 .. config.n_clients do
    Node.spawn :'client#{client_num}_#{config.node_suffix}', Client, :start,
               [config, client_num, replicas]
  end # for

end # start

end # Multipaxos
