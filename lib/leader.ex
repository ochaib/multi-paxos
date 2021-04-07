# Ossama Chaib (oc3317)


defmodule Leader do

  def start config do
    Debug.starting(config)

    # Bind acceptors, replicas and set initial values.
    receive do
      { :bind, acceptors, replicas } ->
        ballot_number = { 0, self() }

        spawn Scout, :start, [config, self(), acceptors, ballot_number]
        send config[:monitor], { :scout_spawned, config[:server_num] }

        next config, acceptors, replicas, ballot_number, false, Map.new()
    end
  end

  defp next config, acceptors, replicas, ballot_number, active, proposals do

    receive do
      # The leader receives a proposal from the replica with a command cmd for
      # the slot number.
      { :propose, slot_number, cmd } ->
        # IO.puts "Leader #{inspect self()} received proposal "
        #         <> " #{inspect {slot_number, cmd}} from Replica."

        if !Map.has_key?(proposals, slot_number) do
          # adds {slot_number, cmd} to set of proposals
          proposals = Map.put(proposals, slot_number, cmd)

          # If active spawns a commander for the new slot with its proposed command.
          if active do
            spawn Commander, :start, [config, self(), acceptors, replicas,
                  { ballot_number, slot_number, cmd }]
            send config[:monitor], { :commander_spawned, config[:server_num] }
          end
          # Next with the updated proposals.
          next config, acceptors, replicas, ballot_number, active, proposals
        else
          # If the proposal and slot number already exists in the set, ignore it
          # and continue to next loop.
          next config, acceptors, replicas, ballot_number, active, proposals
        end

      # Last scout spawned notifies that ballot number "b" has been adopted by a majority of acceptors.
        # with the set of all pvalues accepted before ballot num "b"
      { :adopted, b, pvalues } ->
        # IO.puts "Leader #{inspect self()}'s current ballot number #{inspect b}"
        #         <> " has been adopted by a majority of acceptors."

        # Elements of pmax pvalues union elements of proposals not in pmax pvalues,
        # updates proposals replacing for each slot number the command corresponding
        # to the maximum pvalue in "pvalues".
        if b == ballot_number do
          proposals = update(proposals, pmax pvalues)
          # If active, spawns a commander for each slot.
          for { slot_number, cmd } <- proposals do
            spawn Commander, :start, [config, self(), acceptors, replicas, { ballot_number, slot_number, cmd }]
            # IO.puts "Commander #{inspect commander} has been spawned for proposal "
            #         <> " with slot number: #{slot_number}, command: #{cmd}."
            send config[:monitor], { :commander_spawned, config[:server_num] }
          end
          next config, acceptors, replicas, ballot_number, true, proposals
        else
          next config, acceptors, replicas, ballot_number, active, proposals
        end

      # Scout or commander notifies that some acceptor has adopted r, _leader
      { :preempted, { r, _leader } = preempting_ballot } ->
        # IO.puts "Leader #{inspect self()} has been preempted by #{inspect preempting_ballot}."

        # If preempting ballot has higher ballot number than the current leader's ballot_number,
        # increment ballot_number of the leader and go into passive mode.
        if preempting_ballot > ballot_number do
          # random time from 0 to 1 second
          Process.sleep (trunc(:random.uniform() * 1000))
          ballot_number = { r + 1, self() }
          # Sleep here to avoid a livelock.
          # Process.sleep (trunc(:random.uniform() * 1000))
          spawn Scout, :start, [config, self(), acceptors, ballot_number]
          send config[:monitor], { :scout_spawned, config[:server_num] }

          next config, acceptors, replicas, ballot_number, false, proposals
        else
          next config, acceptors, replicas, ballot_number, active, proposals
        end
    end

  end

  def update x, y do
    # Both enums here
    slots = Enum.map(y, fn ({ s, _ }) -> s end) |> MapSet.new
    # candidates = Enum.map(x, fn ({ s, c }) when not (MapSet.member?(slots, s)) -> { s, c } end) |> MapSet.new
    candidates = for {s, c} <- x, not(MapSet.member?(slots, s)), into: MapSet.new, do: {s, c}
    # IO.puts "HERE #{inspect MapSet.union(y, x_prime)}"
    MapSet.union(y, candidates)
  end

  # Determines for each slot, the command corresponding to the maximum ballot
  # number in pvals.
  defp pmax pvals do
    # Convert pvals to an enumerable
    pvals = MapSet.to_list pvals
    # Retrieve the maximum ballot number in pvalues.
    max_ballot_number =
      # From pvals collect a list of ballot_numbers then reduce to return the max ballot number.
      Enum.map(pvals, fn ({ ballot_number, _s, _c }) -> ballot_number end)
      |> Enum.max(fn -> -1 end)

    # Now filter the pvals to return only those with the max ballot number.
    # Then drop the ballot numbers to produce a map of slot numbers to commands.
    Enum.filter(pvals, fn ({ ballot_number, _s, _c }) -> ballot_number == max_ballot_number end)
    |> Enum.map(fn ({ _b, slot_number, cmd }) -> { slot_number, cmd } end)
    |> MapSet.new
  end

end
