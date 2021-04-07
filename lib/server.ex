# Ossama Chaib (oc3317)

# distributed algorithms, n.dulay 29 jan 2021
# coursework, paxos made moderately complex

defmodule Server do

def start config, server_num, multipaxos do
  config = Configuration.node_id(config, "Server", server_num)
  Debug.starting(config)

  # Add server num to config to avoid passing it around:
  config = Map.put(config, :server_num, server_num)

  # Spawn the following processes
  database = spawn Database, :start, [config]
  replica  = spawn Replica,  :start, [config, database]
  # IO.puts "Replica: #{inspect replica} spawned by Server: #{server_num}, #{inspect self()}"
  leader   = spawn Leader,   :start, [config]
  acceptor = spawn Acceptor, :start, [config]

  # Send the following processes to the multipaxos module
  send multipaxos, { :modules, replica, acceptor, leader }

  # If the server crashes exit all the spawned process and print the time at
  # which the server crashed.
  if crash_after = config.crash_server[server_num] do
    Process.sleep crash_after
    Process.exit database, :faulty
    Process.exit replica,  :faulty
    Process.exit leader,   :faulty
    Process.exit acceptor, :faulty
    IO.puts "  Server #{server_num} crashed at time #{crash_after}"
  end

end # start

end # Server
