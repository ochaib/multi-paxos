# Ossama Chaib (oc3317) and Daniel Loney (dl4317)


# distributed algorithms, n.dulay 29 jan 2021
# coursework, paxos made moderately complex

defmodule Client do

def start config, client_num, replicas do
  config = Configuration.node_id(config, "Client", client_num)
  Debug.starting(config)
  Process.send_after self(), :client_stop, config.client_stop

  # Initialise the minimum number of nodes required by the client_num
  # to perform an operation.
  quorum =
    case config.client_send do
      :round_robin -> 1
      :broadcast   -> config.n_servers
      :quorum      -> div config.n_servers + 1, 2
    end
  # Begin the client process with 0 transactions sent.
  next config, client_num, replicas, 0, quorum
end # start

defp next config, client_num, replicas, sent, quorum do
  # Setting client_sleep to 0 may overload the system
  # with lots of requests and lots of spawned rocesses.

  receive do
    :client_stop ->
      IO.puts "  Client #{client_num} going to sleep, sent = #{sent}"
      Process.sleep :infinity

  # After waiting for a client_sleep period of time, initialise a transaction
  # using two random accounts and a random amount.
  after config.client_sleep ->
    account1 = Enum.random 1 .. config.n_accounts
    account2 = Enum.random 1 .. config.n_accounts
    amount   = Enum.random 1 .. config.max_amount
    transaction  = { :move, amount, account1, account2 }

    # Incremenet the number of transactions sent.
    sent = sent + 1
    # Initialise a tuple cmd to contain the PID of the client, the sent
    # transaction count and the transaction itself.
    cmd = { self(), sent, transaction }

    for r <- 1..quorum do
        # Retrieve a replica from the list of replicas at some point
        replica = Enum.at replicas, rem(sent+r, config.n_servers)
        # Send a client request to this replica with the command.
        # IO.puts "Replica: #{inspect replica} was sent a client request."
        send replica, { :client_request, cmd }
        # send config[:monitor], { :client_request, config[:server_num] }
    end

    if sent == config.max_requests, do: send self(), :client_stop

    receive_replies()
    next config, client_num, replicas, sent, quorum
  end
end # next

defp receive_replies do
  receive do
  { :client_reply, _cid, _result } -> receive_replies()   # discard
  after 0 -> :return
  end # receive
end # receive_replies

end # Client
