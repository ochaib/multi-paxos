# Ossama Chaib (oc3317) and Daniel Loney (dl4317)


defmodule Replica do

  # Slot_in: the index of the next slot in which the replica has not yet proposed
  # any command, initially 1.

  # Slout_out: the index of the next slot for which it needs to learn a decision
  # before it can update its copy of the application state, initially 1.

  # Requests: an initially empty set of requests that the replica has received
  # and are not yet proposed or decided.

  # Proposals: an initially empty set of proposals that are currently outstanding.

  # Decisions: another initially empty set of proposals that are thought to have
  # been decided.

  # Leaders: the set of leaders in the current configuration, passed as an argument.

  def start config, database do
    Debug.starting(config)

    receive do
      { :bind, leaders } ->
        # IO.puts "Replica: #{inspect self()} has received a bind."
        next config, 1, 1, [], Map.new, Map.new, leaders, database
    end
  end

  defp next config, slot_in, slot_out, requests, proposals, decisions, leaders, database do

    receive do
      { :client_request, cmd } ->
        # IO.puts "Replica #{inspect replica} the real replica received a request."
        # IO.puts "Replica #{inspect self()} received a client request."
        send config[:monitor], { :client_request, config[:server_num] }
        # add command to requests
        requests = [cmd | requests]
        # call propose using the new requests list
        propose slot_in, slot_out, requests, proposals, decisions, leaders
        # recurse using the new requests list
        next config, slot_in, slot_out, requests, proposals, decisions, leaders, database

      { :decision, slot, cmd } ->
        # IO.puts "Replica #{inspect self()} received a decision to assign #{inspect cmd}"
        #         <> " to slot #{slot}."
        # add slot, cmd pair to decisions
        decisions = Map.put(decisions, slot, cmd)
        # Call helper function that loops while some {slot_out, cmd} pair exists.
        decision_case_helper slot_in, slot_out, decisions, proposals, requests, leaders, database
        # propose with new decisions values
        propose slot_in, slot_out, requests, proposals, decisions, leaders
        # recurse with new decisions values
        next config, slot_in, slot_out, requests, proposals, decisions, leaders, database
    end
  end

  defp decision_case_helper slot_in, slot_out, decisions, proposals, requests, leaders, database do
    # if there is some command associated with slot_out in decisions,
    if Map.has_key?(decisions, slot_out) do
      # cmd2 corresponds to c' in the pseudocode
      cmd2 = Map.get(decisions, slot_out)
      { proposals, requests } =
        # if there is some command assosciated with slot_out in proposals
        if Map.has_key?(proposals, slot_out) do
          # cmd3 corresponds to c'' in pseudocode
          cmd3 = Map.get(proposals, slot_out)
          # remove cmd3 from proposals
          proposals = Map.delete(proposals, slot_out)
          # if cmd3 and cmd2 are different, add cmd3 to requests
          requests = if cmd3 != cmd2, do: [cmd3 | requests], else: requests
          { proposals, requests }
        else
          { proposals, requests }
        end
      # perform with new proposals and requests values
      slot_out = perform slot_out, decisions, cmd2, database
      # recurse with new proposals and requests values
      decision_case_helper slot_in, slot_out, decisions, proposals, requests, leaders, database
    end
  end

  # transfer requests from set of requests to proposals.
  # uses slot_in to look for unused slots within the window of known configs
  defp propose slot_in, slot_out, requests, proposals, decisions, leaders do
    # if slot in < slot out + window and there are still requests,
    if length(requests) != 0 and slot_in < (slot_out + 1) do
      # no need to check if command is reconfig since reconfig commands aren't used

      # if no key, value pair exists for slot_in,
      if !Map.has_key?(decisions, slot_in) do
        # remove command from requests and adds {slot_in, command} pair to proposals
        { cmd, requests } = List.pop_at(requests, 0)
        proposals = Map.put(proposals, slot_in, cmd)
        # sends propose, slot_in, cmd message to all leaders in the config slot of slot_in
        for leader <- leaders do
          # IO.puts "Replica #{inspect self()} sends the proposal {#{slot_in}, #{inspect cmd}}"
          #         <> " to Leader #{inspect leader}."
          send leader, { :propose, slot_in, cmd }
        end
        # recurse with the new requests value and incremented slot_in
        propose (slot_in + 1), slot_out, requests, proposals, decisions, leaders
      else
        # recurse with all values unchanged except with incremented slot_in
        propose (slot_in + 1), slot_out, requests, proposals, decisions, leaders
      end
    end
  end

  # Performs the command if it has not yet been performed and updates slot_out
  defp perform slot_out, decisions, cmd, database do
    # client is the client id, cid is the command id and op is the operation.
    { client, cid, op } = cmd

    # Check to see if the command has already been performed.
    # If there is any decision thats been made with the same command that you're trying to
    # perform but a lower slot number than slot out so skip it.
    already_performed = Enum.any? decisions, fn {slot, com} -> slot_out > slot && cmd == com end

    # Only evaluate the operation if the command is new, has not been already performed.
    if !already_performed do
      # Apply the requested operation to the application state (database).
      send database, { :execute, op }
      send client, { :client_reply, cid, nil }
    end
    # In either case, the function increments slot_out.
    slot_out + 1
  end

end
